import { backoffDelayMs, isRetryableStatus, sleep } from '@/lib/cloud/cloudHttp';
import { extractContentSources, coerceSiteConfig, toPagesRecord } from '@/lib/cloud/contentCoercion';
import type { CloudLoadFailure, ContentResponse } from '@/lib/cloud/types';
import type { PageConfig, SiteConfig } from '@/types';

export async function fetchLegacyCloudContentPayload(
  apiCandidates: string[],
  apiKey: string,
  signal: AbortSignal,
  maxRetryAttempts: number
): Promise<ContentResponse> {
  let payload: ContentResponse | null = null;
  let lastFailure: CloudLoadFailure | null = null;

  for (const apiBase of apiCandidates) {
    for (let attempt = 0; attempt <= maxRetryAttempts; attempt += 1) {
      try {
        const res = await fetch(`${apiBase}/content`, {
          method: 'GET',
          cache: 'no-store',
          headers: { Authorization: `Bearer ${apiKey}` },
          signal,
        });

        const contentType = (res.headers.get('content-type') || '').toLowerCase();
        if (!contentType.includes('application/json')) {
          lastFailure = {
            reasonCode: 'NON_JSON_RESPONSE',
            message: `Non-JSON response from ${apiBase}/content`,
          };
          break;
        }

        const parsed = (await res.json().catch(() => ({}))) as ContentResponse;
        if (!res.ok) {
          lastFailure = {
            reasonCode: parsed.code || `HTTP_${res.status}`,
            message: parsed.error || `Cloud content read failed: ${res.status} (${apiBase}/content)`,
            correlationId: parsed.correlationId,
          };
          if (isRetryableStatus(res.status) && attempt < maxRetryAttempts) {
            await sleep(backoffDelayMs(attempt));
            continue;
          }
          break;
        }

        payload = parsed;
        break;
      } catch (error: unknown) {
        if (signal.aborted) throw error;
        const message = error instanceof Error ? error.message : 'Network error';
        lastFailure = {
          reasonCode: 'NETWORK_TRANSIENT',
          message: `${message} (${apiBase}/content)`,
        };
        if (attempt < maxRetryAttempts) {
          await sleep(backoffDelayMs(attempt));
          continue;
        }
      }
    }
    if (payload) break;
  }

  if (!payload) {
    throw (
      lastFailure || {
        reasonCode: 'CLOUD_ENDPOINT_UNREACHABLE',
        message: 'Cloud content endpoint not reachable as JSON.',
      }
    );
  }

  return payload;
}

export function applyLegacyCloudPayload(
  payload: ContentResponse,
  setters: {
    setPages: (pages: Record<string, PageConfig>) => void;
    setSiteConfig: (site: SiteConfig) => void;
  }
): { remotePages: Record<string, PageConfig> | null; remoteSite: SiteConfig | null } {
  const { pagesSource, siteSource } = extractContentSources(payload);
  const remotePages = toPagesRecord(pagesSource);
  const remoteSite = coerceSiteConfig(siteSource);
  const remotePageCount = remotePages ? Object.keys(remotePages).length : 0;
  if (remotePageCount === 0 && !remoteSite) {
    throw {
      reasonCode: payload.contentStatus === 'empty_namespace' ? 'EMPTY_NAMESPACE' : 'EMPTY_PAYLOAD',
      message: 'Cloud payload is empty for this tenant namespace.',
      correlationId: payload.correlationId,
    } satisfies CloudLoadFailure;
  }
  if (remotePages && remotePageCount > 0) {
    setters.setPages(remotePages);
  }
  if (remoteSite) {
    setters.setSiteConfig(remoteSite);
  }
  return { remotePages, remoteSite };
}

