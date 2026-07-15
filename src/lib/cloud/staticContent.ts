import { withBasePath } from '@olonjs/core';
import { coerceSiteConfig, normalizePageRegistry } from '@/lib/cloud/contentCoercion';
import { normalizeSlugForCache } from '@/lib/cloud/cloudCache';
import type { PageConfig, SiteConfig } from '@/types';

function buildPublishedPageHref(slug: string, basePath: string): string {
  return withBasePath(`/pages/${normalizeSlugForCache(slug)}.json`, basePath);
}

export async function loadPublishedStaticContent(
  knownSlugs: string[],
  basePath: string
): Promise<{ pages: Record<string, PageConfig>; siteConfig: SiteConfig }> {
  const siteResponse = await fetch(withBasePath('/config/site.json', basePath), { cache: 'no-store' });
  if (!siteResponse.ok) {
    throw new Error(`Static site config unavailable: ${siteResponse.status}`);
  }

  const sitePayload = (await siteResponse.json().catch(() => null)) as unknown;
  const nextSite = coerceSiteConfig(sitePayload);
  if (!nextSite) {
    throw new Error('Static site config is invalid.');
  }

  const pageEntries = await Promise.all(
    knownSlugs.map(async (slug) => {
      const response = await fetch(buildPublishedPageHref(slug, basePath), { cache: 'no-store' });
      if (!response.ok) {
        throw new Error(`Static page unavailable for slug "${slug}": ${response.status}`);
      }
      return [slug, (await response.json().catch(() => null)) as unknown] as const;
    })
  );

  const nextPages = normalizePageRegistry(Object.fromEntries(pageEntries));
  if (Object.keys(nextPages).length === 0) {
    throw new Error('Static published pages are empty.');
  }

  return { pages: nextPages, siteConfig: nextSite };
}

