import { backoffDelayMs, isRetryableStatus, sleep } from '@/lib/cloud/cloudHttp';
import { extractContentSources, coerceSiteConfig, normalizeRouteSlug, toPagesRecord } from '@/lib/cloud/contentCoercion';
import type { CloudLoadFailure, ContentResponse } from '@/lib/cloud/types';
import { fetchRenderProjection, normalizeRenderPath } from '@/lib/spp/renderClient';
import { APP_BASE_PATH } from '@/lib/tenantEnv';
import type { PageConfig, SiteConfig } from '@/types';

function cleanAdminPath(path: string): string {
  const trimmed = path.trim();
  if (!trimmed) return '/';

  let cleaned = trimmed;
  if (cleaned.startsWith('/admin/preview/')) {
    cleaned = cleaned.replace(/^\/admin\/preview/, '');
  } else if (cleaned.startsWith('/preview/')) {
    cleaned = cleaned.replace(/^\/preview/, '');
  } else if (cleaned.startsWith('/admin/')) {
    cleaned = cleaned.replace(/^\/admin/, '');
  } else if (cleaned === '/admin') {
    cleaned = '/';
  }

  if (!cleaned.startsWith('/')) cleaned = `/${cleaned}`;
  return cleaned === '' ? '/' : cleaned;
}

function resolveAdminRenderPath(pathname: string, search: string, basePath: string): string {
  const normalizedPath = normalizeRenderPath(pathname, basePath);
  const params = new URLSearchParams(search);
  const candidatePaths = [
    params.get('path'),
    params.get('page'),
    params.get('slug') ? `/${params.get('slug')}` : null,
    normalizedPath,
  ];

  for (const candidate of candidatePaths) {
    if (!candidate) continue;
    const cleaned = cleanAdminPath(candidate);
    if (cleaned && cleaned !== '/admin') return cleaned;
  }

  return '/';
}

export async function fetchAdminCloudRenderPayload(
  apiCandidates: string[],
  apiKey: string,
  pathname: string,
  signal: AbortSignal,
  maxRetryAttempts: number
): Promise<ContentResponse> {
  const renderPath = resolveAdminRenderPath(pathname, window.location.search, APP_BASE_PATH);
  const projection = await fetchRenderProjection(apiCandidates, apiKey, renderPath, {
    signal,
    maxRetryAttempts,
  });

  if (!projection.ok || !projection.page) {
    throw {
      reasonCode: projection.code || 'RENDER_PROJECTION_FAILED',
      message: projection.error || 'Render projection failed',
      correlationId: projection.correlationId,
    } satisfies CloudLoadFailure;
  }

  const pageSlug = typeof projection.page.slug === 'string' && projection.page.slug.trim()
    ? normalizeRouteSlug(projection.page.slug)
    : normalizeRouteSlug(renderPath);

  return {
    ok: true,
    siteConfig: projection.context?.siteConfig,
    menuConfig: projection.context?.menuConfig,
    pages: { [pageSlug]: projection.page },
    pagesIndex: projection.pagesIndex,
    contentStatus: 'ok',
    correlationId: projection.correlationId,
  };
}

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
    setPages: (pages: Record<string, PageConfig> | ((prev: Record<string, PageConfig>) => Record<string, PageConfig>)) => void;
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
    const pagesIndex = payload.pagesIndex || [];
    setters.setPages((prev) => {
      const next = { ...prev };
      for (const slug of pagesIndex) {
        if (!next[slug]) {
          next[slug] = { id: `${slug}-page`, slug, meta: { title: slug, description: '' }, sections: [] };
        }
      }
      Object.assign(next, remotePages);
      return next;
    });
  }
  if (remoteSite) {
    setters.setSiteConfig(remoteSite);
  }
  return { remotePages, remoteSite };
}
