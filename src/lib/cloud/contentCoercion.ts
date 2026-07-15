import type { PageConfig, SiteConfig } from '@/types';
import type { ContentResponse } from '@/lib/cloud/types';

function isObjectRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

function asString(value: unknown, fallback: string): string {
  return typeof value === 'string' && value.trim() ? value : fallback;
}

export function normalizeRouteSlug(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9/_[\]-]/g, '-')
    .replace(/^\/+|\/+$/g, '') || 'home';
}

export function coercePageConfig(slug: string, value: unknown): PageConfig | null {
  let input = value;
  if (typeof input === 'string') {
    try {
      input = JSON.parse(input) as unknown;
    } catch {
      return null;
    }
  }
  if (!isObjectRecord(input) || !Array.isArray(input.sections)) return null;

  const inputMeta = isObjectRecord(input.meta) ? input.meta : {};
  const normalizedSlug = asString(input.slug, slug);
  const normalizedId = asString(input.id, `${normalizedSlug}-page`);
  const title = asString(inputMeta.title, normalizedSlug);
  const description = asString(inputMeta.description, '');

  return {
    id: normalizedId,
    slug: normalizedSlug,
    meta: { title, description },
    sections: input.sections as PageConfig['sections'],
    ...(isObjectRecord(input.collection) ? { collection: input.collection as unknown as PageConfig['collection'] } : {}),
    ...(typeof input['global-header'] === 'boolean' ? { 'global-header': input['global-header'] } : {}),
  };
}

export function coerceSiteConfig(value: unknown): SiteConfig | null {
  let input = value;
  if (typeof input === 'string') {
    try {
      input = JSON.parse(input) as unknown;
    } catch {
      return null;
    }
  }
  if (!isObjectRecord(input)) return null;
  if (!isObjectRecord(input.identity)) return null;

  return input as unknown as SiteConfig;
}

export function toPagesRecord(value: unknown): Record<string, PageConfig> | null {
  const directPage = coercePageConfig('home', value);
  if (directPage) {
    const directSlug = normalizeRouteSlug(asString(directPage.slug, 'home'));
    return { [directSlug]: { ...directPage, slug: directSlug } };
  }

  if (!isObjectRecord(value)) return null;
  const next: Record<string, PageConfig> = {};
  for (const [rawKey, payload] of Object.entries(value)) {
    const rawKeyTrimmed = rawKey.trim();
    const slugFromNamespacedKey = rawKeyTrimmed.match(/^t_[a-z0-9-]+_page_(.+)$/i)?.[1];
    const slug = normalizeRouteSlug(slugFromNamespacedKey ?? rawKeyTrimmed);
    const page = coercePageConfig(slug, payload);
    if (!page) continue;
    next[slug] = { ...page, slug };
  }
  return next;
}

export function normalizePageRegistry(value: unknown): Record<string, PageConfig> {
  if (!isObjectRecord(value)) return {};
  const normalized: Record<string, PageConfig> = {};

  for (const [registrySlug, rawPageValue] of Object.entries(value)) {
    const canonicalSlug = normalizeRouteSlug(registrySlug);
    const direct = coercePageConfig(canonicalSlug, rawPageValue);
    if (direct) {
      normalized[canonicalSlug] = { ...direct, slug: canonicalSlug };
      continue;
    }

    const nested = toPagesRecord(rawPageValue);
    if (nested && Object.keys(nested).length > 0) {
      Object.assign(normalized, nested);
    }
  }

  return normalized;
}

export function extractContentSources(payload: ContentResponse | Record<string, unknown>): {
  pagesSource: unknown;
  siteSource: unknown;
} {
  if (isObjectRecord(payload) && isObjectRecord(payload.pages)) {
    return { pagesSource: payload.pages, siteSource: payload.siteConfig };
  }

  if (isObjectRecord(payload) && isObjectRecord(payload.items)) {
    const items = payload.items;
    let siteSource: unknown = null;
    const pageEntries: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(items)) {
      if (/(_config_site|config_site|config:site)$/i.test(key)) {
        siteSource = value;
        continue;
      }
      if (/(_page_|^page_|page:)/i.test(key)) {
        pageEntries[key] = value;
      }
    }
    return { pagesSource: pageEntries, siteSource };
  }

  return { pagesSource: payload, siteSource: null };
}

