import type { JsonPagesConfig, ProjectState } from '@olonjs/core';
import type { MenuConfig, PageConfig, SiteConfig, ThemeConfig } from '@/types';

type HydrateLocalProjectStateArgs = {
  state: ProjectState;
  slug: string;
  setPages: (updater: (prev: Record<string, PageConfig>) => Record<string, PageConfig>) => void;
  setSiteConfig: (site: SiteConfig) => void;
  setMenuConfig: (menu: MenuConfig) => void;
  setThemeConfig: (theme: ThemeConfig) => void;
  setCollections: (collections: NonNullable<JsonPagesConfig['collections']>) => void;
};

/**
 * Write-through hydrate after local `/api/save-to-file`.
 * Pushes only the slices present in the saved ProjectState into bootstrap state —
 * no disk re-read, no full remount.
 */
export function hydrateLocalProjectState({
  state,
  slug,
  setPages,
  setSiteConfig,
  setMenuConfig,
  setThemeConfig,
  setCollections,
}: HydrateLocalProjectStateArgs): void {
  if (state.menu != null) setMenuConfig(state.menu);
  if (state.site != null) setSiteConfig(state.site);
  if (state.theme != null) setThemeConfig(state.theme);
  if (state.page != null) {
    setPages((prev) => ({ ...prev, [slug]: state.page }));
  }
  if (state.collections != null) {
    setCollections(state.collections as NonNullable<JsonPagesConfig['collections']>);
  }
}
