import { buildApiCandidates } from '@/lib/spp';
import type { CachedCloudContent } from '@/lib/cloud/types';
import { coerceSiteConfig, normalizeRouteSlug, toPagesRecord } from '@/lib/cloud/contentCoercion';

const CLOUD_CACHE_KEY = 'jp_cloud_content_cache_v1';
const CLOUD_CACHE_TTL_MS = 5 * 60 * 1000;

export function cloudFingerprint(apiBase: string, apiKey: string): string {
  const normalized = apiBase.trim().replace(/\/+$/, '');
  return `${normalized}::${apiKey.slice(-8)}`;
}

export function cloudFingerprintFromUrl(cloudApiUrl: string, apiKey: string): string {
  const primaryApiBase = buildApiCandidates(cloudApiUrl)[0] ?? cloudApiUrl.trim().replace(/\/+$/, '');
  return cloudFingerprint(primaryApiBase, apiKey);
}

export function normalizeSlugForCache(slug: string): string {
  return normalizeRouteSlug(slug);
}

export function readCachedCloudContent(fingerprint: string): CachedCloudContent | null {
  try {
    const raw = localStorage.getItem(CLOUD_CACHE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as CachedCloudContent;
    if (!parsed || parsed.keyFingerprint !== fingerprint) return null;
    if (!parsed.savedAt || Date.now() - parsed.savedAt > CLOUD_CACHE_TTL_MS) return null;
    return parsed;
  } catch {
    return null;
  }
}

export function writeCachedCloudContent(entry: CachedCloudContent): void {
  try {
    localStorage.setItem(CLOUD_CACHE_KEY, JSON.stringify(entry));
  } catch {
    // non-blocking cache path
  }
}

export function readCachedPages(fingerprint: string) {
  const cached = readCachedCloudContent(fingerprint);
  return {
    cached,
    cachedPages: cached ? toPagesRecord(cached.pages) : null,
    cachedSite: cached ? coerceSiteConfig(cached.siteConfig) : null,
  };
}

