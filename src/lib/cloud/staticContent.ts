import { withBasePath } from '@olonjs/core';
import { coerceSiteConfig, normalizePageRegistry } from '@/lib/cloud/contentCoercion';
import { normalizeSlugForCache } from '@/lib/cloud/cloudCache';
import type { PageConfig, SiteConfig } from '@/types';

function buildPublishedPageHref(slug: string, basePath: string): string {
  return withBasePath(`/pages/${normalizeSlugForCache(slug)}.json`, basePath);
}

function isParametricSlug(slug: string): boolean {
  return /\[[^\]]+\]/.test(slug);
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

  // Parametric registry keys (blog/[slug]) are templates, not published URLs.
  // Bake emits concrete paths (blog/foo.json); skip brackets so Save2Repo can boot.
  const staticSlugs = knownSlugs.filter((slug) => !isParametricSlug(slug));

  const pageEntries = (
    await Promise.all(
      staticSlugs.map(async (slug) => {
        const response = await fetch(buildPublishedPageHref(slug, basePath), { cache: 'no-store' });
        if (!response.ok) {
          if (import.meta.env.DEV) {
            console.warn(`[static-content] skip slug "${slug}": HTTP ${response.status}`);
          }
          return null;
        }
        return [slug, (await response.json().catch(() => null)) as unknown] as const;
      }),
    )
  ).filter((entry): entry is readonly [string, unknown] => entry != null);

  const nextPages = normalizePageRegistry(Object.fromEntries(pageEntries));
  if (Object.keys(nextPages).length === 0) {
    throw new Error('Static published pages are empty.');
  }

  return { pages: nextPages, siteConfig: nextSite };
}
