import type { JsonPagesConfig, MenuConfig, PageConfig, SiteConfig, ThemeConfig } from '@/types';
import { CollectionRegistry } from '@/lib/CollectionRegistry';
import { SECTION_SCHEMAS } from '@/lib/schemas';
import { getFileCollections } from '@/lib/getFileCollections';
import { getFilePages } from '@/lib/getFilePages';
import siteData from '@/data/config/site.json';
import menuData from '@/data/config/menu.json';
import themeData from '@/data/config/theme.json';

export const siteConfig = siteData as unknown as SiteConfig;
export const themeConfig = themeData as unknown as ThemeConfig;
export const menuConfig = menuData as unknown as MenuConfig;
export const pages = getFilePages();
export const collections = getFileCollections();
export const collectionSchemas = CollectionRegistry as unknown as JsonPagesConfig['collectionSchemas'];
export const refDocuments = {
  'menu.json': menuConfig,
  'config/menu.json': menuConfig,
  'src/data/config/menu.json': menuConfig,
} satisfies NonNullable<JsonPagesConfig['refDocuments']>;

export function getWebMcpBuildState(): {
  pages: Record<string, PageConfig>;
  schemas: JsonPagesConfig['schemas'];
  collectionSchemas: JsonPagesConfig['collectionSchemas'];
  collections: JsonPagesConfig['collections'];
  siteConfig: SiteConfig;
  themeConfig: ThemeConfig;
  menuConfig: MenuConfig;
  refDocuments: JsonPagesConfig['refDocuments'];
} {
  return {
    pages,
    schemas: SECTION_SCHEMAS as unknown as JsonPagesConfig['schemas'],
    collectionSchemas,
    collections,
    siteConfig,
    themeConfig,
    menuConfig,
    refDocuments,
  };
}

