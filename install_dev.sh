#!/bin/bash
set -e # Termina se c'è un errore

echo "Inizio ricostruzione progetto..."

mkdir -p "src"
echo "Creating src/App.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/App.tsx"
/**
 * Thin Entry Point (Tenant).
 * Bootstrap, persistence, and engine wiring — logic lives in lib/hooks.
 */
import { useEffect, useMemo } from 'react';
import { JsonPagesEngine } from '@olonjs/core';
import type { JsonPagesConfig, ProjectState } from '@olonjs/core';
import { withBasePath } from '@olonjs/core';
import { OlonFormsContext } from '@olonjs/core';
import { ComponentRegistry } from '@/lib/ComponentRegistry';
import { CollectionRegistry } from '@/lib/CollectionRegistry';
import { SECTION_SCHEMAS } from '@/lib/schemas';
import { addSectionConfig } from '@/lib/addSectionConfig';
import type { MenuConfig, SiteConfig, ThemeConfig } from '@/types';
import siteData from '@/data/config/site.json';
import themeData from '@/data/config/theme.json';
import menuData from '@/data/config/menu.json';
import { getFileCollections } from '@/lib/getFileCollections';
import { getFilePages } from '@/lib/getFilePages';
import { DopaDrawer } from '@/components/save-drawer/DopaDrawer';
import { EmptyTenantView } from '@/components/empty-tenant';
import { TenantBootstrapChrome } from '@/components/TenantBootstrapChrome';
import { ThemeProvider } from '@/components/ThemeProvider';
import { useOlonForms } from '@/lib/useOlonForms';
import { iconMap } from '@/lib/IconResolver';
import { uploadTenantAsset } from '@/lib/assetUpload';
import {
  cloudFingerprintFromUrl,
  normalizeSlugForCache,
  readCachedCloudContent,
  writeCachedCloudContent,
} from '@/lib/cloud/cloudCache';
import {
  buildThemeFontVarsCss,
  extractLeadingRemoteCssImports,
  setTenantPreviewReady,
  useInjectedTenantCss,
  useTenantFontsReady,
} from '@/lib/tenantCss';
import { APP_BASE_PATH, CLOUD_API_KEY, CLOUD_API_URL, TENANT_ID } from '@/lib/tenantEnv';
import { useAssetsManifest } from '@/lib/useAssetsManifest';
import { useCloudSave } from '@/lib/useCloudSave';
import { useTenantBootstrap } from '@/lib/useTenantBootstrap';
import { useAdminStudioContent } from '@/lib/cloud/useAdminStudioContent';

import tenantCss from './index.css?inline';

const themeConfigSeed = themeData as unknown as ThemeConfig;
const menuConfigSeed = menuData as unknown as MenuConfig;
const fileSiteConfig = siteData as unknown as SiteConfig;
const filePages = getFilePages();
const fileCollections = getFileCollections();

function App() {
  const { states: formStates } = useOlonForms();
  const bootstrap = useTenantBootstrap({
    tenantId: TENANT_ID,
    filePages,
    fileSiteConfig,
    menuConfigSeed,
    themeConfigSeed,
  });
  useAdminStudioContent({
    enabled: bootstrap.isHotSaveMode,
    apiCandidates: bootstrap.cloudApiCandidates,
    apiKey: CLOUD_API_KEY,
    setPages: bootstrap.setPages,
    setSiteConfig: bootstrap.setSiteConfig,
    setCollections: bootstrap.setCollections,
  });
  const { assetsManifest, loadAssetsManifest, cloudApiCandidates } = useAssetsManifest(bootstrap.isCloudMode);
  const { cloudSaveUi, runCloudSave, closeCloudDrawer, retryCloudSave } = useCloudSave();

  const tenantCssParts = useMemo(() => extractLeadingRemoteCssImports(tenantCss), []);
  const resolvedTenantCss = useMemo(
    () => [buildThemeFontVarsCss(bootstrap.themeConfig), tenantCssParts.rest].filter(Boolean).join('\n'),
    [bootstrap.themeConfig, tenantCssParts],
  );
  useInjectedTenantCss(resolvedTenantCss);
  const fontsReady = useTenantFontsReady(tenantCssParts.hrefs);
  const canPaintVisitor = bootstrap.shouldRenderEngine && fontsReady;

  useEffect(() => {
    setTenantPreviewReady(false);
    return () => {
      setTenantPreviewReady(false);
    };
  }, []);

  useEffect(() => {
    if (!canPaintVisitor) {
      setTenantPreviewReady(false);
      return;
    }
    let cancelled = false;
    let raf1 = 0;
    let raf2 = 0;
    raf1 = window.requestAnimationFrame(() => {
      raf2 = window.requestAnimationFrame(() => {
        if (!cancelled) setTenantPreviewReady(true);
      });
    });
    return () => {
      cancelled = true;
      window.cancelAnimationFrame(raf1);
      window.cancelAnimationFrame(raf2);
      setTenantPreviewReady(false);
    };
  }, [canPaintVisitor, bootstrap.enginePages, bootstrap.siteConfig]);

  const engineCollections = bootstrap.isHotSaveMode ? bootstrap.collections : fileCollections;
  const engineRefDocuments = useMemo(
    () => ({
      'menu.json': bootstrap.menuConfig,
      'config/menu.json': bootstrap.menuConfig,
      'src/data/config/menu.json': bootstrap.menuConfig,
    }),
    [bootstrap.menuConfig],
  );

  const config: JsonPagesConfig = {
    tenantId: TENANT_ID,
    basePath: APP_BASE_PATH,
    registry: ComponentRegistry as JsonPagesConfig['registry'],
    schemas: SECTION_SCHEMAS as unknown as JsonPagesConfig['schemas'],
    collectionSchemas: CollectionRegistry as unknown as JsonPagesConfig['collectionSchemas'],
    pages: bootstrap.enginePages,
    siteConfig: bootstrap.siteConfig,
    themeConfig: bootstrap.themeConfig,
    menuConfig: bootstrap.menuConfig,
    collections: engineCollections,
    refDocuments: engineRefDocuments,
    themeCss: { tenant: resolvedTenantCss },
    iconRegistry: iconMap,
    addSection: addSectionConfig,
    webmcp: {
      enabled: true,
      namespace: typeof window !== 'undefined' ? window.location.href : '',
    },
    persistence: {
      async saveToFile(state: ProjectState, slug: string): Promise<void> {
        const res = await fetch('/api/save-to-file', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ projectState: state, slug }),
        });
        const body = (await res.json().catch(() => ({}))) as { error?: string };
        if (!res.ok) throw new Error(body.error ?? `Save to file failed: ${res.status}`);
      },
      async hotSave(state: ProjectState, slug: string): Promise<void> {
        if (!bootstrap.isCloudMode || !CLOUD_API_URL || !CLOUD_API_KEY) {
          throw new Error('Cloud mode is not configured for hot save.');
        }
        const apiBase = CLOUD_API_URL.replace(/\/$/, '');
        const res = await fetch(`${apiBase}/hotSave`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${CLOUD_API_KEY}`,
          },
          body: JSON.stringify({
            slug,
            page: state.page,
            siteConfig: state.site,
            collections: state.collections,
          }),
        });
        const body = (await res.json().catch(() => ({}))) as { error?: string; code?: string };
        if (!res.ok) {
          throw new Error(body.error || body.code || `Hot save failed: ${res.status}`);
        }
        const keyFingerprint = cloudFingerprintFromUrl(CLOUD_API_URL, CLOUD_API_KEY);
        const normalizedSlug = normalizeSlugForCache(slug);
        const existing = readCachedCloudContent(keyFingerprint);
        writeCachedCloudContent({
          keyFingerprint,
          savedAt: Date.now(),
          siteConfig: state.site ?? null,
          collections: state.collections,
          pages: {
            ...(existing?.pages ?? {}),
            [normalizedSlug]: state.page,
          },
        });
      },
      async coldSave(state: ProjectState, slug: string): Promise<void> {
        await runCloudSave({ state, slug }, true);
      },
      showLocalSave: !bootstrap.isCloudMode,
      showHotSave: bootstrap.isHotSaveMode,
      showColdSave: bootstrap.isSave2RepoMode,
    },
    assets: {
      assetsBaseUrl: withBasePath('/assets', APP_BASE_PATH),
      assetsManifest,
      onAssetUpload: (file) =>
        uploadTenantAsset(file, {
          basePath: APP_BASE_PATH,
          isCloudMode: bootstrap.isCloudMode,
          cloudApiUrl: CLOUD_API_URL,
          cloudApiKey: CLOUD_API_KEY,
          apiBases: cloudApiCandidates,
          onUploaded: loadAssetsManifest,
        }),
    },
  };

  return (
    <ThemeProvider>
      <OlonFormsContext.Provider value={formStates}>
        <TenantBootstrapChrome
          isCloudMode={bootstrap.isCloudMode}
          showTopProgress={bootstrap.showTopProgress || (bootstrap.shouldRenderEngine && !fontsReady)}
          contentMode={bootstrap.contentMode}
          contentFallback={bootstrap.contentFallback}
          onRetry={bootstrap.retryBootstrap}
        />
        {canPaintVisitor ? (
          bootstrap.isTenantEmpty ? (
            <EmptyTenantView />
          ) : (
            <JsonPagesEngine config={config} />
          )
        ) : null}
        <DopaDrawer
          isOpen={cloudSaveUi.isOpen}
          phase={cloudSaveUi.phase}
          currentStepId={cloudSaveUi.currentStepId}
          doneSteps={cloudSaveUi.doneSteps}
          progress={cloudSaveUi.progress}
          errorMessage={cloudSaveUi.errorMessage}
          deployUrl={cloudSaveUi.deployUrl}
          onClose={closeCloudDrawer}
          onRetry={retryCloudSave}
        />
      </OlonFormsContext.Provider>
    </ThemeProvider>
  );
}

export default App;

END_OF_FILE_CONTENT
mkdir -p "src/collections"
mkdir -p "src/collections/autori"
echo "Creating src/collections/autori/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/collections/autori/index.ts"
export { AutoreSchema, AutoriCollectionSchema } from './schema';
export type { Autore, AutoriCollection } from './types';

END_OF_FILE_CONTENT
echo "Creating src/collections/autori/schema.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/collections/autori/schema.ts"
import { z } from 'zod';
import { BaseCollectionItem } from '@olonjs/core';

export const AutoreSchema = BaseCollectionItem.extend({
  name: z.string().describe('ui:text'),
});

export const AutoriCollectionSchema = z.record(z.string(), AutoreSchema);

END_OF_FILE_CONTENT
echo "Creating src/collections/autori/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/collections/autori/types.ts"
import { z } from 'zod';
import { AutoreSchema, AutoriCollectionSchema } from './schema';

export type Autore = z.infer<typeof AutoreSchema>;
export type AutoriCollection = z.infer<typeof AutoriCollectionSchema>;

END_OF_FILE_CONTENT
mkdir -p "src/collections/libri"
echo "Creating src/collections/libri/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/collections/libri/index.ts"
export { LibroSchema, LibriCollectionSchema } from './schema';
export type { Libro, LibriCollection } from './types';

END_OF_FILE_CONTENT
echo "Creating src/collections/libri/schema.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/collections/libri/schema.ts"
import { z } from 'zod';
import { BaseCollectionItem } from '@olonjs/core';
import { AutoreSchema } from '@/collections/autori';

const CollectionRefSchema = z.object({
  $ref: z.string(),
});

export const LibroSchema = BaseCollectionItem.extend({
  title: z.string().describe('ui:text'),
  author: z.union([AutoreSchema, CollectionRefSchema]).describe('ui:collection-ref:autori'),
  year: z.number().describe('ui:number'),
  genre: z.string().describe('ui:text'),
  summary: z.string().describe('ui:textarea'),
});

export const LibriCollectionSchema = z.record(z.string(), LibroSchema);

END_OF_FILE_CONTENT
echo "Creating src/collections/libri/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/collections/libri/types.ts"
import { z } from 'zod';
import { LibroSchema, LibriCollectionSchema } from './schema';

export type Libro = z.infer<typeof LibroSchema>;
export type LibriCollection = z.infer<typeof LibriCollectionSchema>;

END_OF_FILE_CONTENT
mkdir -p "src/collections/posts"
echo "Creating src/collections/posts/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/collections/posts/index.ts"
export { PostSchema, PostsCollectionSchema } from './schema';
export type { Post, PostsCollection } from './types';

END_OF_FILE_CONTENT
echo "Creating src/collections/posts/schema.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/collections/posts/schema.ts"
import { z } from 'zod';
import { BaseCollectionItem } from '@olonjs/core';

export const PostSchema = BaseCollectionItem.extend({
  slug: z.string().describe('ui:text'),
  title: z.string().describe('ui:text'),
  dek: z.string().describe('ui:textarea'),
  date: z.string().describe('ui:text'),
  readingTime: z.string().describe('ui:text'),
  tags: z.array(z.string()).describe('ui:list'),
  related: z.array(z.string()).describe('ui:list'),
  content: z.array(z.string()).describe('ui:list')
});

export const PostsCollectionSchema = z.record(z.string(), PostSchema);

END_OF_FILE_CONTENT
echo "Creating src/collections/posts/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/collections/posts/types.ts"
import { z } from 'zod';
import { PostSchema, PostsCollectionSchema } from './schema';

export type Post = z.infer<typeof PostSchema>;
export type PostsCollection = z.infer<typeof PostsCollectionSchema>;

END_OF_FILE_CONTENT
mkdir -p "src/collections/projects"
echo "Creating src/collections/projects/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/collections/projects/index.ts"
export { ProjectSchema, ProjectsCollectionSchema } from './schema';
export type { Project, ProjectsCollection } from './types';

END_OF_FILE_CONTENT
echo "Creating src/collections/projects/schema.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/collections/projects/schema.ts"
import { z } from 'zod';
import { BaseCollectionItem } from '@olonjs/core';

export const ProjectSchema = BaseCollectionItem.extend({
  slug: z.string().describe('ui:text'),
  title: z.string().describe('ui:text'),
  category: z.string().describe('ui:text'),
  year: z.string().describe('ui:text'),
  summary: z.string().describe('ui:textarea'),
  context: z.string().describe('ui:textarea'),
  problem: z.string().describe('ui:textarea'),
  architecture: z.string().describe('ui:textarea'),
  result: z.string().describe('ui:textarea'),
  outcomeLong: z.string().describe('ui:textarea'),
  stack: z.array(z.string()).describe('ui:list')
});

export const ProjectsCollectionSchema = z.record(z.string(), ProjectSchema);

END_OF_FILE_CONTENT
echo "Creating src/collections/projects/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/collections/projects/types.ts"
import { z } from 'zod';
import { ProjectSchema, ProjectsCollectionSchema } from './schema';

export type Project = z.infer<typeof ProjectSchema>;
export type ProjectsCollection = z.infer<typeof ProjectsCollectionSchema>;

END_OF_FILE_CONTENT
mkdir -p "src/components"
echo "Creating src/components/TenantBootstrapChrome.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/TenantBootstrapChrome.tsx"
import type { CloudLoadFailure, ContentMode } from '@/lib/cloud/types';



type TenantBootstrapChromeProps = {

  isCloudMode: boolean;

  showTopProgress: boolean;

  contentMode: ContentMode;

  contentFallback: CloudLoadFailure | null;

  onRetry: () => void;

};



export function TenantBootstrapChrome({

  isCloudMode,

  showTopProgress,

  contentMode,

  contentFallback,

  onRetry,

}: TenantBootstrapChromeProps) {

  return (

    <>

      {isCloudMode && showTopProgress ? (

        <>

          <style>

            {`@keyframes jp-top-progress-slide { 0% { transform: translateX(-120%); } 100% { transform: translateX(320%); } }`}

          </style>

          <div

            role="status"

            aria-live="polite"

            aria-label="Cloud loading progress"

            style={{

              position: 'fixed',

              top: 0,

              left: 0,

              right: 0,

              height: 2,

              zIndex: 1300,

              background: 'rgba(255,255,255,0.08)',

              overflow: 'hidden',

            }}

          >

            <div

              style={{

                width: '32%',

                height: '100%',

                background:

                  'linear-gradient(90deg, rgba(88,166,255,0.15) 0%, rgba(88,166,255,0.85) 50%, rgba(88,166,255,0.15) 100%)',

                animation: 'jp-top-progress-slide 1.15s ease-in-out infinite',

                willChange: 'transform',

              }}

            />

          </div>

        </>

      ) : null}

      {isCloudMode && (contentMode === 'error' || contentFallback?.reasonCode === 'CLOUD_REFRESH_FAILED') ? (

        <div

          role="status"

          aria-live="polite"

          style={{

            position: 'fixed',

            top: 12,

            right: 12,

            zIndex: 1200,

            background: 'rgba(179, 65, 24, 0.92)',

            border: '1px solid rgba(255,255,255,0.18)',

            color: '#fff',

            padding: '8px 12px',

            borderRadius: 10,

            fontSize: 12,

            maxWidth: 360,

            boxShadow: '0 8px 24px rgba(0,0,0,0.25)',

          }}

        >

          {contentMode === 'error' ? 'Cloud content unavailable.' : 'Cloud refresh failed, showing cached content.'}

          {contentFallback ? (

            <div style={{ opacity: 0.85, marginTop: 4 }}>

              <div>{contentFallback.message}</div>

              <div style={{ marginTop: 2 }}>

                Reason: {contentFallback.reasonCode}

                {contentFallback.correlationId ? ` | Correlation: ${contentFallback.correlationId}` : ''}

              </div>

              <div style={{ marginTop: 8 }}>

                <button

                  type="button"

                  onClick={onRetry}

                  style={{

                    border: '1px solid rgba(255,255,255,0.3)',

                    borderRadius: 8,

                    padding: '4px 10px',

                    background: 'transparent',

                    color: '#fff',

                    cursor: 'pointer',

                    fontSize: 12,

                  }}

                >

                  Retry

                </button>

              </div>

            </div>

          ) : null}

        </div>

      ) : null}

    </>

  );

}



END_OF_FILE_CONTENT
echo "Creating src/components/ThemeProvider.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ThemeProvider.tsx"
import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'

type Theme = 'dark' | 'light'

interface ThemeContextValue {
  theme: Theme
  toggleTheme: () => void
  setTheme: (t: Theme) => void
}

const ThemeContext = createContext<ThemeContextValue>({
  theme: 'dark',
  toggleTheme: () => {},
  setTheme: () => {},
})

const STORAGE_KEY = 'olon:theme'

function isTheme(value: unknown): value is Theme {
  return value === 'dark' || value === 'light'
}

function resolveInitialTheme(): Theme {
  if (typeof window === 'undefined') return 'dark'

  const fromDom = document.documentElement.getAttribute('data-theme')
  if (isTheme(fromDom)) return fromDom

  const fromStorage = window.localStorage.getItem(STORAGE_KEY)
  if (isTheme(fromStorage)) return fromStorage

  const prefersLight = window.matchMedia?.('(prefers-color-scheme: light)').matches
  return prefersLight ? 'light' : 'dark'
}

export function ThemeProvider({ children }: { children: ReactNode }) {
  const [theme, setThemeState] = useState<Theme>(resolveInitialTheme)

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme)
    window.localStorage.setItem(STORAGE_KEY, theme)
  }, [theme])

  function setTheme(t: Theme) {
    setThemeState(t)
  }

  function toggleTheme() {
    setThemeState((prev) => (prev === 'dark' ? 'light' : 'dark'))
  }

  const value = useMemo(() => ({ theme, toggleTheme, setTheme }), [theme])

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>
}

export function useTheme() {
  return useContext(ThemeContext)
}

END_OF_FILE_CONTENT
mkdir -p "src/components/authors-list"
echo "Creating src/components/authors-list/View.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/authors-list/View.tsx"
import { useMemo } from 'react';
import type { Autore } from '@/collections/autori';
import type { AuthorsListData } from './types';

type AuthorsListViewProps = {
  data: AuthorsListData;
};

function toAuthors(items: AuthorsListData['items']): Autore[] {
  return Object.values(items ?? {}).sort((a, b) => a.name.localeCompare(b.name));
}

export function AuthorsListView({ data }: AuthorsListViewProps) {
  const authors = useMemo(() => toAuthors(data.items), [data.items]);

  return (
    <main className="min-h-screen bg-background px-6 py-16 text-foreground">
      <section className="mx-auto flex w-full max-w-5xl flex-col gap-10">
        <div className="max-w-2xl">
          {data.eyebrow && (
            <p
              data-jp-field="eyebrow"
              className="text-sm font-medium uppercase tracking-[0.18em] text-muted-foreground"
            >
              {data.eyebrow}
            </p>
          )}
          <h1
            data-jp-field="title"
            className="mt-3 text-4xl font-semibold tracking-tight sm:text-5xl"
          >
            {data.title}
          </h1>
          {data.description && (
            <p
              data-jp-field="description"
              className="mt-4 text-base leading-7 text-muted-foreground"
            >
              {data.description}
            </p>
          )}
        </div>

        <div data-jp-field="items" className="grid gap-4 sm:grid-cols-2">
          {authors.map((author) => (
            <a
              key={author.id}
              href={`/authors/${encodeURIComponent(author.id)}/libri`}
              data-jp-item-id={author.id}
              data-jp-item-field="items"
              className="block rounded-xl border border-border bg-card p-5 shadow-sm transition-colors hover:bg-muted/40"
            >
              <h2 className="text-xl font-semibold">{author.name}</h2>
              <p className="mt-2 text-sm text-muted-foreground">
                Vedi libri di {author.name}
              </p>
            </a>
          ))}
        </div>
      </section>
    </main>
  );
}

END_OF_FILE_CONTENT
echo "Creating src/components/authors-list/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/authors-list/index.ts"
export { AuthorsListView } from './View';
export { AuthorsListSchema, AuthorsListSettingsSchema } from './schema';
export type { AuthorsListData, AuthorsListSettings } from './types';

END_OF_FILE_CONTENT
echo "Creating src/components/authors-list/schema.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/authors-list/schema.ts"
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
import { AutoreSchema } from '@/collections/autori';

export const AuthorsListSchema = BaseSectionData.extend({
  eyebrow: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  items: z.record(z.string(), AutoreSchema).describe('ui:collection-ref:autori'),
});

export const AuthorsListSettingsSchema = z.object({});

END_OF_FILE_CONTENT
echo "Creating src/components/authors-list/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/authors-list/types.ts"
import { z } from 'zod';
import { AuthorsListSchema, AuthorsListSettingsSchema } from './schema';

export type AuthorsListData = z.infer<typeof AuthorsListSchema>;
export type AuthorsListSettings = z.infer<typeof AuthorsListSettingsSchema>;

END_OF_FILE_CONTENT
mkdir -p "src/components/bio-panel"
echo "Creating src/components/bio-panel/View.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/bio-panel/View.tsx"
// Layout: Hero=A (SPLIT 60/40), Features=A (BENTO)
import React from 'react';
import { AspectRatio } from '@/components/ui/aspect-ratio';
import type { BioPanelData, BioPanelSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40'
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40'
};

export const BioPanel: React.FC<{ data: BioPanelData; settings: BioPanelSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      bg: 'var(--theme-colors-background)',
      text: 'var(--theme-colors-foreground)',
      muted: 'var(--theme-colors-muted-foreground)',
      surface: 'var(--theme-colors-card)',
      border: 'var(--theme-colors-border)'
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)'
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)'
    }
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-accent': 'var(--accent)',
        '--local-border': t.border,
        '--local-surface': t.surface,
        '--local-radius-sm': 'var(--theme-radius-sm)',
        '--local-radius-md': 'var(--theme-radius-md)',
        '--local-radius-lg': 'var(--theme-radius-lg)'
      } as React.CSSProperties}
      className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}
    >
      <div className={containerClass}>
        <div className="grid gap-8 lg:grid-cols-[0.85fr_1.15fr] lg:items-center">
          <div className="rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-surface)] p-3">
            <AspectRatio ratio={4 / 5}>
              {data.image?.url ? (
                <img
                  src={data.image?.url}
                  alt={data.image?.alt}
                  className="h-full w-full rounded-[var(--local-radius-md)] object-cover"
                />
              ) : null}
            </AspectRatio>
          </div>
          <div className="space-y-5">
            {data.label && (
              <div className="jp-section-label inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-accent)] mb-4" data-jp-field="label">
                <span className="w-5 h-px bg-[var(--local-primary)]" />
                {data.label}
              </div>
            )}
            <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">
              {data.title}
            </h2>
            <p className="text-[1rem] text-[var(--local-text-muted)]" data-jp-field="description">
              {data.description}
            </p>
            {data.note && (
              <p className="jp-meta max-w-xl text-[var(--local-primary)]" data-jp-field="note">
                {data.note}
              </p>
            )}
          </div>
        </div>
      </div>
    </section>
  );
};

END_OF_FILE_CONTENT
echo "Creating src/components/bio-panel/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/bio-panel/index.ts"
export { BioPanel } from './View';
export { BioPanelSchema } from './schema';
export type { BioPanelData, BioPanelSettings } from './types';

END_OF_FILE_CONTENT
echo "Creating src/components/bio-panel/schema.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/bio-panel/schema.ts"
import { z } from 'zod';
import { BaseSectionData, ImageSelectionSchema } from '@olonjs/core';

export const BioPanelSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().describe('ui:textarea'),
  image: ImageSelectionSchema.optional(),
  note: z.string().optional().describe('ui:textarea')
});

END_OF_FILE_CONTENT
echo "Creating src/components/bio-panel/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/bio-panel/types.ts"
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { BioPanelSchema } from './schema';

export type BioPanelData = z.infer<typeof BioPanelSchema>;
export type BioPanelSettings = z.infer<typeof BaseSectionSettingsSchema>;

END_OF_FILE_CONTENT
mkdir -p "src/components/blog-rollup"
echo "Creating src/components/blog-rollup/View.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/blog-rollup/View.tsx"
// Layout: Hero=E (MAGAZINE), Features=B (HORIZONTAL SCROLL)
import React from 'react';
import { Card, CardContent } from '@/components/ui/card';
import type { BlogRollupData, BlogRollupSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40'
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40'
};

export const BlogRollup: React.FC<{ data: BlogRollupData; settings: BlogRollupSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      bg: 'var(--theme-colors-background)',
      text: 'var(--theme-colors-foreground)',
      muted: 'var(--theme-colors-muted-foreground)',
      surface: 'var(--theme-colors-card)',
      border: 'var(--theme-colors-border)'
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)'
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)'
    }
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;
  const posts = Object.values(data.items || {});

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-accent': 'var(--accent)',
        '--local-border': t.border,
        '--local-surface': t.surface,
        '--local-radius-sm': 'var(--theme-radius-sm)',
        '--local-radius-md': 'var(--theme-radius-md)',
        '--local-radius-lg': 'var(--theme-radius-lg)'
      } as React.CSSProperties}
      className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}
    >
      <div className={containerClass}>
        <div className="mb-10 flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
          <div className="max-w-2xl">
            {data.label && (
              <div className="jp-section-label inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-accent)] mb-4" data-jp-field="label">
                <span className="w-5 h-px bg-[var(--local-primary)]" />
                {data.label}
              </div>
            )}
            <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">
              {data.title}
            </h2>
          </div>
          {data.description && (
            <p className="max-w-xl text-sm text-[var(--local-text-muted)]" data-jp-field="description">
              {data.description}
            </p>
          )}
        </div>

        <div className="grid gap-6 lg:grid-cols-3">
          {posts.map((item, idx) => (
            <Card
              key={item.id || 'legacy-' + idx}
              className="rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-surface)] text-[var(--local-text)]"
              data-jp-item-id={item.id || 'legacy-' + idx}
              data-jp-item-field="items"
            >
              <CardContent className="space-y-4 p-6">
                <div className="flex flex-wrap gap-2">
                  <span className="jp-meta">{item.date}</span>
                  <span className="jp-meta">{item.readingTime}</span>
                </div>
                <h3 className="font-display font-bold text-[1.2rem] leading-tight tracking-tight text-[var(--local-text)]">
                  {item.title}
                </h3>
                <p className="text-sm text-[var(--local-text-muted)]">{item.dek}</p>
                <div className="flex flex-wrap gap-2">
                  {item.tags.map((tag, tagIdx) => (
                    <span key={tag + '-' + tagIdx} className="jp-chip">{tag}</span>
                  ))}
                </div>
                <a href={'/blog/' + item.slug} className="inline-flex text-sm font-medium text-[var(--local-primary)]">
                  Read article
                </a>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    </section>
  );
};

END_OF_FILE_CONTENT
echo "Creating src/components/blog-rollup/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/blog-rollup/index.ts"
export { BlogRollup } from './View';
export { BlogRollupSchema } from './schema';
export type { BlogRollupData, BlogRollupSettings } from './types';

END_OF_FILE_CONTENT
echo "Creating src/components/blog-rollup/schema.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/blog-rollup/schema.ts"
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
import { PostSchema } from '@/collections/posts';

export const BlogRollupSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  items: z.record(z.string(), PostSchema).describe('ui:collection-ref')
});

END_OF_FILE_CONTENT
echo "Creating src/components/blog-rollup/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/blog-rollup/types.ts"
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { BlogRollupSchema } from './schema';

export type BlogRollupData = z.infer<typeof BlogRollupSchema>;
export type BlogRollupSettings = z.infer<typeof BaseSectionSettingsSchema>;

END_OF_FILE_CONTENT
mkdir -p "src/components/book-detail"
echo "Creating src/components/book-detail/View.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/book-detail/View.tsx"
import type { BookDetailData } from './types';

type BookDetailViewProps = {
  data: BookDetailData;
};

function getAuthorName(author: BookDetailData['item']['author']): string {
  if (typeof author === 'object' && author !== null && 'name' in author) {
    return String(author.name);
  }
  return 'Autore';
}

export function BookDetailView({ data }: BookDetailViewProps) {
  const book = data.item;

  return (
    <main className="min-h-screen bg-background text-foreground px-6 py-16">
      <article
        data-jp-field="item"
        data-jp-item-id={book.id}
        data-jp-item-field="item"
        className="mx-auto w-full max-w-3xl rounded-2xl border border-border bg-card p-8 shadow-sm"
      >
        <a
          href="/"
          className="text-sm font-medium text-muted-foreground hover:text-foreground"
        >
          {data.backLabel}
        </a>
        <p className="mt-10 text-sm font-medium uppercase tracking-[0.18em] text-muted-foreground">
          {book.genre} · {book.year}
        </p>
        <h1 className="mt-3 text-4xl font-semibold tracking-tight sm:text-5xl">
          {book.title}
        </h1>
        <p className="mt-4 text-lg text-muted-foreground">
          {getAuthorName(book.author)}
        </p>
        <p className="mt-8 text-base leading-8 text-muted-foreground">
          {book.summary}
        </p>
      </article>
    </main>
  );
}

END_OF_FILE_CONTENT
echo "Creating src/components/book-detail/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/book-detail/index.ts"
export * from './View';
export * from './schema';
export * from './types';

END_OF_FILE_CONTENT
echo "Creating src/components/book-detail/schema.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/book-detail/schema.ts"
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
import { LibroSchema } from '@/collections/libri';

export const BookDetailSchema = BaseSectionData.extend({
  item: LibroSchema.describe('ui:collection-ref'),
  backLabel: z.string().default('Torna ai libri').describe('ui:text'),
});

export const BookDetailSettingsSchema = z.object({});

END_OF_FILE_CONTENT
echo "Creating src/components/book-detail/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/book-detail/types.ts"
import { z } from 'zod';
import { BookDetailSchema, BookDetailSettingsSchema } from './schema';

export type BookDetailData = z.infer<typeof BookDetailSchema>;
export type BookDetailSettings = z.infer<typeof BookDetailSettingsSchema>;

END_OF_FILE_CONTENT
mkdir -p "src/components/books-list"
echo "Creating src/components/books-list/View.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/books-list/View.tsx"
import { useEffect, useMemo, useState } from 'react';
import { useLocation } from 'react-router-dom';
import type { Libro } from '@/collections/libri';
import type { BooksListData } from './types';

type BooksListViewProps = {
  data: BooksListData;
};

function toBooks(items: BooksListData['items']): Libro[] {
  return Object.values(items ?? {}).sort((a, b) => a.title.localeCompare(b.title));
}

function getAuthorName(author: Libro['author']): string {
  if (typeof author === 'object' && author !== null && 'name' in author) {
    return String(author.name);
  }
  return 'Autore';
}

function getAuthorId(author: Libro['author']): string | null {
  if (typeof author === 'object' && author !== null && 'id' in author && typeof author.id === 'string') {
    return author.id;
  }
  if (typeof author === 'object' && author !== null && '$ref' in author && typeof author.$ref === 'string') {
    const pointer = author.$ref.split('#')[1]?.replace(/^\//, '') ?? '';
    return pointer.split('/')[0] || null;
  }
  return null;
}

function getAuthorFilterFromPath(pathname: string): string | null {
  const match = pathname.match(/^\/authors\/([^/]+)\/libri\/?$/);
  return match?.[1] ? decodeURIComponent(match[1]) : null;
}

export function BooksListView({ data }: BooksListViewProps) {
  const location = useLocation();
  const authorFilter = useMemo(() => {
    const queryAuthor = new URLSearchParams(location.search).get('author');
    return queryAuthor || getAuthorFilterFromPath(location.pathname);
  }, [location.pathname, location.search]);
  const books = useMemo(() => toBooks(data.items), [data.items]);
  const filteredBooks = useMemo(
    () => authorFilter ? books.filter((book) => getAuthorId(book.author) === authorFilter) : books,
    [authorFilter, books]
  );
  const pageSize = Math.max(1, Math.floor(data.pageSize || 10));
  const totalPages = Math.max(1, Math.ceil(filteredBooks.length / pageSize));
  const [page, setPage] = useState(1);
  const currentPage = Math.min(page, totalPages);
  const startIndex = (currentPage - 1) * pageSize;
  const visibleBooks = filteredBooks.slice(startIndex, startIndex + pageSize);

  useEffect(() => {
    setPage(1);
  }, [authorFilter]);

  return (
    <main className="min-h-screen bg-background text-foreground px-6 py-16">
      <section className="mx-auto flex w-full max-w-5xl flex-col gap-10">
        <div className="max-w-2xl">
          {data.eyebrow && (
            <p
              data-jp-field="eyebrow"
              className="text-sm font-medium uppercase tracking-[0.18em] text-muted-foreground"
            >
              {data.eyebrow}
            </p>
          )}
          <h1
            data-jp-field="title"
            className="mt-3 text-4xl font-semibold tracking-tight sm:text-5xl"
          >
            {data.title}
          </h1>
          {data.description && (
            <p
              data-jp-field="description"
              className="mt-4 text-base leading-7 text-muted-foreground"
            >
              {data.description}
            </p>
          )}
        </div>

        <div data-jp-field="items" className="grid gap-4">
          {authorFilter && (
            <p className="text-sm text-muted-foreground">
              Filtro autore: {authorFilter} · {filteredBooks.length} libri
            </p>
          )}
          {visibleBooks.map((book) => (
            <article
              key={book.id}
              data-jp-item-id={book.id}
              data-jp-item-field="items"
              className="rounded-xl border border-border bg-card p-5 shadow-sm"
            >
              <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
                <div>
                  <h2 className="text-xl font-semibold">{book.title}</h2>
                  <p className="mt-1 text-sm text-muted-foreground">
                    {getAuthorName(book.author)} · {book.year} · {book.genre}
                  </p>
                  <p className="mt-3 max-w-3xl text-sm leading-6 text-muted-foreground">
                    {book.summary}
                  </p>
                </div>
                <a
                  href={`/libri/${book.id}`}
                  className="inline-flex shrink-0 items-center justify-center rounded-md border border-border px-3 py-2 text-sm font-medium hover:bg-muted"
                >
                  Apri scheda
                </a>
              </div>
            </article>
          ))}
        </div>

        <nav className="flex items-center justify-between border-t border-border pt-6 text-sm">
          <button
            type="button"
            onClick={() => setPage((value) => Math.max(1, value - 1))}
            disabled={currentPage === 1}
            className="rounded-md border border-border px-3 py-2 font-medium disabled:cursor-not-allowed disabled:opacity-40 hover:bg-muted"
          >
            Precedente
          </button>
          <span className="text-muted-foreground">
            Pagina {currentPage} di {totalPages} · {filteredBooks.length} libri
          </span>
          <button
            type="button"
            onClick={() => setPage((value) => Math.min(totalPages, value + 1))}
            disabled={currentPage === totalPages}
            className="rounded-md border border-border px-3 py-2 font-medium disabled:cursor-not-allowed disabled:opacity-40 hover:bg-muted"
          >
            Successiva
          </button>
        </nav>
      </section>
    </main>
  );
}

END_OF_FILE_CONTENT
echo "Creating src/components/books-list/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/books-list/index.ts"
export * from './View';
export * from './schema';
export * from './types';

END_OF_FILE_CONTENT
echo "Creating src/components/books-list/schema.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/books-list/schema.ts"
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
import { LibroSchema } from '@/collections/libri';



export const BooksListSchema = BaseSectionData.extend({
  eyebrow: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  items: z.record(z.string(), LibroSchema).describe('ui:collection-ref:libri'),
  pageSize: z.number().default(10).describe('ui:number'),
});

export const BooksListSettingsSchema = z.object({});
END_OF_FILE_CONTENT
echo "Creating src/components/books-list/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/books-list/types.ts"
import { z } from 'zod';
import { BooksListSchema, BooksListSettingsSchema } from './schema';

export type BooksListData = z.infer<typeof BooksListSchema>;
export type BooksListSettings = z.infer<typeof BooksListSettingsSchema>;

END_OF_FILE_CONTENT
mkdir -p "src/components/contact-cta"
echo "Creating src/components/contact-cta/View.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/contact-cta/View.tsx"
// Layout: Hero=F (MINIMAL HERO), Features=A (BENTO)
import React from 'react';
import { Button } from '@/components/ui/button';
import type { ContactCtaData, ContactCtaSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40'
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40'
};

export const ContactCta: React.FC<{ data: ContactCtaData; settings: ContactCtaSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'lg'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'lg'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  const sectionTheme = settings?.theme ?? 'accent';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      bg: 'var(--theme-colors-background)',
      text: 'var(--theme-colors-foreground)',
      muted: 'var(--theme-colors-muted-foreground)',
      surface: 'var(--theme-colors-card)',
      border: 'var(--theme-colors-border)'
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)'
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)'
    }
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.accent;

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-primary-foreground': 'var(--primary-foreground)',
        '--local-accent': 'var(--accent)',
        '--local-border': t.border,
        '--local-surface': t.surface,
        '--local-radius-sm': 'var(--theme-radius-sm)',
        '--local-radius-md': 'var(--theme-radius-md)',
        '--local-radius-lg': 'var(--theme-radius-lg)'
      } as React.CSSProperties}
      className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}
    >
      <div className={containerClass}>
        <div className="rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-bg)] px-8 py-10">
          {data.label && (
            <div className="jp-section-label inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-text)] mb-4" data-jp-field="label">
              <span className="w-5 h-px bg-[var(--local-text)]" />
              {data.label}
            </div>
          )}
          <div className="grid gap-6 lg:grid-cols-[1fr_auto] lg:items-end">
            <div className="space-y-4">
              <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">
                {data.title}
              </h2>
              <p className="max-w-2xl text-[var(--local-text-muted)]" data-jp-field="description">
                {data.description}
              </p>
            </div>
            <div className="flex flex-wrap gap-4">
              {data.primaryCta && (
                <Button asChild variant="default" className="rounded-[var(--local-radius-md)] bg-[var(--local-text)] text-[var(--local-bg)]">
                  <a href={data.primaryCta.href}>{data.primaryCta.label}</a>
                </Button>
              )}
              {data.secondaryCta && (
                <Button asChild variant="outline" className="rounded-[var(--local-radius-md)] border-[var(--local-text)] text-[var(--local-text)] bg-transparent">
                  <a href={data.secondaryCta.href}>{data.secondaryCta.label}</a>
                </Button>
              )}
            </div>
          </div>
        </div>
      </div>
    </section>
  );
};

END_OF_FILE_CONTENT
echo "Creating src/components/contact-cta/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/contact-cta/index.ts"
export { ContactCta } from './View';
export { ContactCtaSchema } from './schema';
export type { ContactCtaData, ContactCtaSettings } from './types';

END_OF_FILE_CONTENT
echo "Creating src/components/contact-cta/schema.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/contact-cta/schema.ts"
import { z } from 'zod';
import { BaseSectionData, CtaSchema } from '@olonjs/core';

export const ContactCtaSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().describe('ui:textarea'),
  primaryCta: CtaSchema.optional(),
  secondaryCta: CtaSchema.optional()
});

END_OF_FILE_CONTENT
echo "Creating src/components/contact-cta/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/contact-cta/types.ts"
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { ContactCtaSchema } from './schema';

export type ContactCtaData = z.infer<typeof ContactCtaSchema>;
export type ContactCtaSettings = z.infer<typeof BaseSectionSettingsSchema>;

END_OF_FILE_CONTENT
mkdir -p "src/components/contact-form"
echo "Creating src/components/contact-form/View.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/contact-form/View.tsx"
// Layout: Hero=A (SPLIT 60/40), Features=A (BENTO)
import React from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { IconResolver } from '@/lib/IconResolver';
import type { ContactFormData, ContactFormSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40'
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40'
};

export const ContactForm: React.FC<{ data: ContactFormData; settings: ContactFormSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      bg: 'var(--theme-colors-background)',
      text: 'var(--theme-colors-foreground)',
      muted: 'var(--theme-colors-muted-foreground)',
      surface: 'var(--theme-colors-card)',
      border: 'var(--theme-colors-border)'
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)'
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)'
    }
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-primary-foreground': 'var(--primary-foreground)',
        '--local-accent': 'var(--accent)',
        '--local-border': t.border,
        '--local-surface': t.surface,
        '--local-radius-sm': 'var(--theme-radius-sm)',
        '--local-radius-md': 'var(--theme-radius-md)',
        '--local-radius-lg': 'var(--theme-radius-lg)'
      } as React.CSSProperties}
      className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}
    >
      <div className={containerClass}>
        <div className="grid gap-8 lg:grid-cols-[0.85fr_1.15fr]">
          <div className="space-y-5">
            {data.label && (
              <div className="jp-section-label inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-accent)] mb-4" data-jp-field="label">
                <span className="w-5 h-px bg-[var(--local-primary)]" />
                {data.label}
              </div>
            )}
            <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">
              {data.title}
            </h2>
            <p className="text-[var(--local-text-muted)]" data-jp-field="description">
              {data.description}
            </p>
            <a href={'mailto:' + data.email} className="jp-meta text-[var(--local-primary)]" data-jp-field="email">
              {data.email}
            </a>
            {data.formNote && (
              <p className="text-sm text-[var(--local-text-muted)]" data-jp-field="formNote">
                {data.formNote}
              </p>
            )}
            <div className="flex flex-col gap-3">
              {data.links.map((item, idx) => {
                const Icon = IconResolver[item.icon];
                return (
                  <a
                    key={item.id || 'legacy-' + idx}
                    href={item.href}
                    className="flex items-center gap-3 text-sm text-[var(--local-text)]"
                    data-jp-item-id={item.id || 'legacy-' + idx}
                    data-jp-item-field="links"
                  >
                    {Icon ? <Icon className="h-4 w-4 text-[var(--local-primary)]" /> : null}
                    <span>{item.label}</span>
                  </a>
                );
              })}
            </div>
          </div>
          <form className="rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-surface)] p-6">
            <div className="grid gap-5">
              <div className="grid gap-2">
                <Label htmlFor="name">Name</Label>
                <Input id="name" placeholder="Your name" className="border-[var(--local-border)] bg-background text-foreground" />
              </div>
              <div className="grid gap-2">
                <Label htmlFor="email">Email</Label>
                <Input id="email" type="email" placeholder="you@company.com" className="border-[var(--local-border)] bg-background text-foreground" />
              </div>
              <div className="grid gap-2">
                <Label htmlFor="message">Message</Label>
                <Textarea id="message" rows={7} placeholder="Project scope, editorial brief, or architecture review request." className="border-[var(--local-border)] bg-background text-foreground" />
              </div>
              <Button type="submit" variant="default" className="rounded-[var(--local-radius-md)] bg-[var(--local-primary)] text-[var(--local-primary-foreground)]">
                Send inquiry
              </Button>
            </div>
          </form>
        </div>
      </div>
    </section>
  );
};

END_OF_FILE_CONTENT
echo "Creating src/components/contact-form/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/contact-form/index.ts"
export { ContactForm } from './View';
export { ContactFormSchema } from './schema';
export type { ContactFormData, ContactFormSettings } from './types';

END_OF_FILE_CONTENT
echo "Creating src/components/contact-form/schema.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/contact-form/schema.ts"
import { z } from 'zod';
import { BaseSectionData, BaseArrayItem } from '@olonjs/core';

const ContactLinkSchema = BaseArrayItem.extend({
  label: z.string().describe('ui:text'),
  href: z.string().describe('ui:text'),
  icon: z.string().describe('ui:icon-picker')
});

export const ContactFormSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().describe('ui:textarea'),
  email: z.string().describe('ui:text'),
  formNote: z.string().optional().describe('ui:textarea'),
  links: z.array(ContactLinkSchema).describe('ui:list')
});

END_OF_FILE_CONTENT
echo "Creating src/components/contact-form/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/contact-form/types.ts"
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { ContactFormSchema } from './schema';

export type ContactFormData = z.infer<typeof ContactFormSchema>;
export type ContactFormSettings = z.infer<typeof BaseSectionSettingsSchema>;

END_OF_FILE_CONTENT
mkdir -p "src/components/editorial-hero"
echo "Creating src/components/editorial-hero/View.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/editorial-hero/View.tsx"
// Layout: Hero=F (MINIMAL HERO), Features=A (BENTO)
import React from 'react';
import { Button } from '@/components/ui/button';
import type { EditorialHeroData, EditorialHeroSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40'
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40'
};

export const EditorialHero: React.FC<{ data: EditorialHeroData; settings: EditorialHeroSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'xl'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'xl'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      bg: 'var(--theme-colors-background)',
      text: 'var(--theme-colors-foreground)',
      muted: 'var(--theme-colors-muted-foreground)',
      surface: 'var(--theme-colors-card)',
      border: 'var(--theme-colors-border)'
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)'
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)'
    }
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-primary-foreground': 'var(--primary-foreground)',
        '--local-accent': 'var(--accent)',
        '--local-border': t.border,
        '--local-surface': t.surface,
        '--local-radius-sm': 'var(--theme-radius-sm)',
        '--local-radius-md': 'var(--theme-radius-md)',
        '--local-radius-lg': 'var(--theme-radius-lg)'
      } as React.CSSProperties}
      className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}
    >
      <div className={containerClass}>
        <div className="max-w-4xl space-y-8">
          {data.label && (
            <div className="jp-section-label inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-accent)] mb-4" data-jp-field="label">
              <span className="w-5 h-px bg-[var(--local-primary)]" />
              {data.label}
            </div>
          )}
          {data.status && (
            <div className="jp-chip" data-jp-field="status">
              <span className="w-1.5 h-1.5 rounded-full bg-[var(--local-primary)] jp-pulse-dot" />
              {data.status}
            </div>
          )}
          <h1 className="font-display font-black text-[clamp(3rem,6vw,5.5rem)] leading-[1.0] tracking-tight text-[var(--local-text)]" data-jp-field="title">
            {data.title}{' '}
            {data.titleHighlight && (
              <em className="not-italic text-[var(--local-primary)]" data-jp-field="titleHighlight">
                {data.titleHighlight}
              </em>
            )}
          </h1>
          <p className="max-w-2xl text-[1.05rem] text-[var(--local-text-muted)]" data-jp-field="description">
            {data.description}
          </p>
          <div className="flex flex-wrap gap-4">
            {data.primaryCta && (
              <Button
                asChild
                variant="default"
                className="rounded-[var(--local-radius-md)] bg-[var(--local-primary)] text-[var(--local-primary-foreground)]"
              >
                <a href={data.primaryCta.href}>{data.primaryCta.label}</a>
              </Button>
            )}
            {data.secondaryCta && (
              <Button
                asChild
                variant="outline"
                className="rounded-[var(--local-radius-md)] border-[var(--local-border)] bg-transparent text-[var(--local-text)]"
              >
                <a href={data.secondaryCta.href}>{data.secondaryCta.label}</a>
              </Button>
            )}
          </div>
        </div>
      </div>
    </section>
  );
};

END_OF_FILE_CONTENT
echo "Creating src/components/editorial-hero/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/editorial-hero/index.ts"
export { EditorialHero } from './View';
export { EditorialHeroSchema } from './schema';
export type { EditorialHeroData, EditorialHeroSettings } from './types';

END_OF_FILE_CONTENT
echo "Creating src/components/editorial-hero/schema.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/editorial-hero/schema.ts"
import { z } from 'zod';
import { BaseSectionData, CtaSchema } from '@olonjs/core';

export const EditorialHeroSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  titleHighlight: z.string().optional().describe('ui:text'),
  description: z.string().describe('ui:textarea'),
  primaryCta: CtaSchema.optional(),
  secondaryCta: CtaSchema.optional(),
  status: z.string().optional().describe('ui:text')
});

END_OF_FILE_CONTENT
echo "Creating src/components/editorial-hero/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/editorial-hero/types.ts"
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { EditorialHeroSchema } from './schema';

export type EditorialHeroData = z.infer<typeof EditorialHeroSchema>;
export type EditorialHeroSettings = z.infer<typeof BaseSectionSettingsSchema>;

END_OF_FILE_CONTENT
mkdir -p "src/components/empty-tenant"
echo "Creating src/components/empty-tenant/View.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/empty-tenant/View.tsx"
import type { EmptyTenantData } from './types';

type EmptyTenantViewProps = {
  data?: EmptyTenantData;
};

export function EmptyTenantView({ data }: EmptyTenantViewProps) {
  const title = data?.title?.trim() || 'Your tenant is empty.';
  const description = data?.description?.trim() || 'Create your first page to start building your site.';

  return (
    <main className="min-h-screen flex items-center justify-center bg-background text-foreground px-6">
      <section className="w-full max-w-xl rounded-xl border border-border bg-card p-8 shadow-sm">
        <h1 className="text-2xl font-semibold tracking-tight">{title}</h1>
        <p className="mt-3 text-sm text-muted-foreground">{description}</p>
      </section>
    </main>
  );
}

END_OF_FILE_CONTENT
echo "Creating src/components/empty-tenant/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/empty-tenant/index.ts"
export * from './View';
export * from './schema';
export * from './types';

END_OF_FILE_CONTENT
echo "Creating src/components/empty-tenant/schema.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/empty-tenant/schema.ts"
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';

export const EmptyTenantSchema = BaseSectionData.extend({
  title: z.string().optional().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
});

export const EmptyTenantSettingsSchema = z.object({});

END_OF_FILE_CONTENT
echo "Creating src/components/empty-tenant/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/empty-tenant/types.ts"
import { z } from 'zod';
import { EmptyTenantSchema, EmptyTenantSettingsSchema } from './schema';

export type EmptyTenantData = z.infer<typeof EmptyTenantSchema>;
export type EmptyTenantSettings = z.infer<typeof EmptyTenantSettingsSchema>;

END_OF_FILE_CONTENT
mkdir -p "src/components/featured-projects"
echo "Creating src/components/featured-projects/View.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/featured-projects/View.tsx"
// Layout: Hero=B (BENTO GRID), Features=A (BENTO)
import React from 'react';
import { Card, CardContent } from '@/components/ui/card';
import type { FeaturedProjectsData, FeaturedProjectsSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40'
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40'
};

export const FeaturedProjects: React.FC<{ data: FeaturedProjectsData; settings: FeaturedProjectsSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      bg: 'var(--theme-colors-background)',
      text: 'var(--theme-colors-foreground)',
      muted: 'var(--theme-colors-muted-foreground)',
      surface: 'var(--theme-colors-card)',
      border: 'var(--theme-colors-border)'
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)'
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)'
    }
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;
  const projects = Object.values(data.items || {}).slice(0, 4);

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-accent': 'var(--accent)',
        '--local-border': t.border,
        '--local-surface': t.surface,
        '--local-radius-sm': 'var(--theme-radius-sm)',
        '--local-radius-md': 'var(--theme-radius-md)',
        '--local-radius-lg': 'var(--theme-radius-lg)'
      } as React.CSSProperties}
      className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}
    >
      <div className={containerClass}>
        <div className="mb-10 flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
          <div className="max-w-2xl">
            {data.label && (
              <div className="jp-section-label inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-accent)] mb-4" data-jp-field="label">
                <span className="w-5 h-px bg-[var(--local-primary)]" />
                {data.label}
              </div>
            )}
            <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">
              {data.title}
            </h2>
          </div>
          {data.description && (
            <p className="max-w-xl text-sm text-[var(--local-text-muted)]" data-jp-field="description">
              {data.description}
            </p>
          )}
        </div>

        <div className="grid gap-6 md:grid-cols-2">
          {projects.map((item, idx) => (
            <Card
              key={item.id || 'legacy-' + idx}
              className={(idx === 0 ? 'md:col-span-2 ' : '') + 'rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-surface)] text-[var(--local-text)]'}
              data-jp-item-id={item.id || 'legacy-' + idx}
              data-jp-item-field="items"
            >
              <CardContent className="space-y-5 p-7">
                <div className="flex flex-wrap gap-2">
                  <span className="jp-chip">{item.year}</span>
                  <span className="jp-chip">{item.category}</span>
                </div>
                <div className="space-y-3">
                  <h3 className="font-display font-bold text-[1.35rem] leading-tight tracking-tight text-[var(--local-text)]">
                    {item.title}
                  </h3>
                  <p className="text-sm text-[var(--local-text-muted)]">{item.summary}</p>
                </div>
                <div className="grid gap-4 sm:grid-cols-3">
                  <div>
                    <div className="jp-meta">Problem</div>
                    <p className="mt-2 text-sm text-[var(--local-text)]">{item.problem}</p>
                  </div>
                  <div>
                    <div className="jp-meta">Architecture</div>
                    <p className="mt-2 text-sm text-[var(--local-text)]">{item.architecture}</p>
                  </div>
                  <div>
                    <div className="jp-meta">Outcome</div>
                    <p className="mt-2 text-sm text-[var(--local-text)]">{item.result}</p>
                  </div>
                </div>
                <a href={'/work/' + item.slug} className="inline-flex text-sm font-medium text-[var(--local-primary)]">
                  Read case study
                </a>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    </section>
  );
};

END_OF_FILE_CONTENT
echo "Creating src/components/featured-projects/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/featured-projects/index.ts"
export { FeaturedProjects } from './View';
export { FeaturedProjectsSchema } from './schema';
export type { FeaturedProjectsData, FeaturedProjectsSettings } from './types';

END_OF_FILE_CONTENT
echo "Creating src/components/featured-projects/schema.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/featured-projects/schema.ts"
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
import { ProjectSchema } from '@/collections/projects';

export const FeaturedProjectsSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  items: z.record(z.string(), ProjectSchema).describe('ui:collection-ref')
});

END_OF_FILE_CONTENT
echo "Creating src/components/featured-projects/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/featured-projects/types.ts"
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { FeaturedProjectsSchema } from './schema';

export type FeaturedProjectsData = z.infer<typeof FeaturedProjectsSchema>;
export type FeaturedProjectsSettings = z.infer<typeof BaseSectionSettingsSchema>;

END_OF_FILE_CONTENT
mkdir -p "src/components/footer"
echo "Creating src/components/footer/View.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/footer/View.tsx"
// Layout: Hero=F (MINIMAL HERO), Features=B (HORIZONTAL SCROLL)
import React from 'react';
import { Separator } from '@/components/ui/separator';
import { IconResolver } from '@/lib/IconResolver';
import type { FooterData, FooterSettings } from './types';

export const Footer: React.FC<{ data: FooterData; settings: FooterSettings }> = ({ data }) => {
  const navItems = Array.isArray(data.menu) ? data.menu : [];

  return (
    <footer
      style={{
        '--local-bg': 'var(--background)',
        '--local-text': 'var(--foreground)',
        '--local-text-muted': 'var(--muted-foreground)',
        '--local-border': 'var(--border)',
        '--local-primary': 'var(--primary)',
        '--local-radius-md': 'var(--theme-radius-md)',
        '--local-radius-lg': 'var(--theme-radius-lg)'
      } as React.CSSProperties}
      className="relative z-0 border-t bg-[var(--local-bg)] py-20"
    >
      <div className="max-w-[1200px] mx-auto px-8">
        <div className="grid gap-10 lg:grid-cols-[1.2fr_0.8fr]">
          <div className="space-y-5">
            <div className="flex items-baseline gap-2">
              <span
                className="text-xl font-semibold tracking-[-0.02em] text-[var(--local-text)]"
                style={{ fontFamily: 'var(--theme-wordmark-font-family, var(--font-primary))', fontWeight: '600' }}
                data-jp-field="brandText"
              >
                {data.brandText}
              </span>
              {data.brandHighlight && (
                <span className="jp-meta text-[var(--local-primary)]" data-jp-field="brandHighlight">
                  {data.brandHighlight}
                </span>
              )}
            </div>
            {data.summary && (
              <p className="max-w-xl text-sm text-[var(--local-text-muted)]" data-jp-field="summary">
                {data.summary}
              </p>
            )}
            {data.email && (
              <a href={'mailto:' + data.email} className="jp-meta text-[var(--local-text)]" data-jp-field="email">
                {data.email}
              </a>
            )}
          </div>

          <div className="grid gap-6 sm:grid-cols-2">
            <div>
              <h3 className="mb-4 font-display text-lg text-[var(--local-text)]">Links</h3>
              <div className="space-y-3">
                {navItems.map((item, idx) => {
                  const Icon = item.icon ? IconResolver[item.icon] : null;
                  return (
                    <a
                      key={item.id || item.href + '-' + idx}
                      href={item.href}
                      className="flex items-center gap-3 text-sm text-[var(--local-text-muted)] transition hover:text-[var(--local-text)]"
                      data-jp-item-id={item.id || 'menu-' + idx}
                      data-jp-item-field="menu"
                    >
                      {Icon ? <Icon className="h-4 w-4 text-[var(--local-primary)]" /> : null}
                      <span>{item.label}</span>
                    </a>
                  );
                })}
              </div>
            </div>
            <div>
              <h3 className="mb-4 font-display text-lg text-[var(--local-text)]">Elsewhere</h3>
              <p className="text-sm text-[var(--local-text-muted)]">
                Available for architecture consulting, writing commissions, and internal developer platform reviews.
              </p>
            </div>
          </div>
        </div>
        <Separator className="my-8 bg-border" />
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <p className="jp-meta" data-jp-field="copyright">{data.copyright}</p>
          <p className="jp-meta">Built for precise systems thinking.</p>
        </div>
      </div>
    </footer>
  );
};

END_OF_FILE_CONTENT
echo "Creating src/components/footer/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/footer/index.ts"
export { Footer } from './View';
export { FooterSchema } from './schema';
export type { FooterData, FooterSettings } from './types';

END_OF_FILE_CONTENT
echo "Creating src/components/footer/schema.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/footer/schema.ts"
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';

const FooterMenuItemSchema = z.object({
  id: z.string().optional(),
  label: z.string().describe('ui:text'),
  href: z.string().describe('ui:text'),
  icon: z.string().optional().describe('ui:icon-picker')
});

export const FooterSchema = BaseSectionData.extend({
  brandText: z.string().describe('ui:text'),
  brandHighlight: z.string().optional().describe('ui:text'),
  summary: z.string().optional().describe('ui:textarea'),
  email: z.string().optional().describe('ui:text'),
  copyright: z.string().describe('ui:text'),
  menu: z.array(FooterMenuItemSchema).optional().describe('ui:list')
});

END_OF_FILE_CONTENT
echo "Creating src/components/footer/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/footer/types.ts"
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { FooterSchema } from './schema';

export type FooterData = z.infer<typeof FooterSchema>;
export type FooterSettings = z.infer<typeof BaseSectionSettingsSchema>;

END_OF_FILE_CONTENT
mkdir -p "src/components/form-demo"
echo "Creating src/components/form-demo/Untitled..."
cat << 'END_OF_FILE_CONTENT' > "src/components/form-demo/Untitled"
useFormSubmit
END_OF_FILE_CONTENT
echo "Creating src/components/form-demo/View.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/form-demo/View.tsx"
import * as Icons from 'lucide-react';
import { useFormState } from '@olonjs/core';
import type { CSSProperties, ComponentType } from 'react';
import type { FormDemoData } from './types';

type FormDemoViewProps = {
  data: FormDemoData;
};

const missingEnv =
  !import.meta.env.VITE_JSONPAGES_CLOUD_URL &&
  !import.meta.env.VITE_OLONJS_CLOUD_URL;

function getIconComponent(iconName?: string): ComponentType<{ className?: string; 'aria-hidden'?: boolean }> | null {
  if (!iconName) return null;

  const candidate = (Icons as Record<string, unknown>)[iconName];
  return typeof candidate === 'function'
    ? (candidate as ComponentType<{ className?: string; 'aria-hidden'?: boolean }>)
    : null;
}

function SetupGuide({ recipientEmail }: { recipientEmail?: string }) {
  const steps = [
    {
      done: !!recipientEmail,
      label: 'recipientEmail nel JSON della sezione',
      code: '"recipientEmail": "tu@esempio.it"',
    },
    {
      done: !missingEnv,
      label: 'VITE_JSONPAGES_CLOUD_URL nel file .env',
      code: 'VITE_JSONPAGES_CLOUD_URL=https://cloud.olonjs.io',
    },
    {
      done:
        !!import.meta.env.VITE_JSONPAGES_API_KEY ||
        !!import.meta.env.VITE_OLONJS_API_KEY,
      label: 'VITE_JSONPAGES_API_KEY nel file .env',
      code: 'VITE_JSONPAGES_API_KEY=sk-...',
    },
  ];

  const allDone = steps.every((s) => s.done);
  if (allDone) return null;

  return (
    <div className="space-y-3 rounded-lg border border-border bg-muted/40 p-4 text-sm">
      <p className="font-medium text-foreground">Quasi pronto — completa questi passaggi</p>
      <ol className="space-y-2">
        {steps.map((step, i) => (
          <li key={step.label} className="flex items-start gap-2">
            <span className={step.done ? 'text-green-500' : 'text-muted-foreground'}>
              {step.done ? '✓' : `${i + 1}.`}
            </span>
            <span className={step.done ? 'text-muted-foreground line-through' : 'text-foreground'}>
              {step.label}
              {!step.done && (
                <code className="mt-0.5 block rounded border border-border bg-background px-1.5 py-0.5 font-mono text-xs text-muted-foreground">
                  {step.code}
                </code>
              )}
            </span>
          </li>
        ))}
      </ol>
    </div>
  );
}

export function FormDemoView({ data }: FormDemoViewProps) {
  const formId = data.anchorId?.trim() || 'form-demo';
  const { status, message } = useFormState(formId);
  const IconComponent = getIconComponent(data.icon);

  const sectionStyle = {
    '--local-bg': 'var(--card)',
    '--local-text': 'var(--card-foreground, var(--foreground))',
    '--local-border': 'var(--border)',
    '--local-input-bg': 'var(--background)',
    '--local-input-text': 'var(--foreground)',
    '--local-accent': 'var(--primary)',
    '--local-accent-foreground': 'var(--primary-foreground)',
    '--local-radius': 'var(--radius)',
  } as CSSProperties;

  return (
    <main
      style={
        {
          '--local-page-bg': 'var(--background)',
          '--local-page-text': 'var(--foreground)',
        } as CSSProperties
      }
      className="flex min-h-screen items-center justify-center bg-[var(--local-page-bg)] px-6 text-[var(--local-page-text)]"
    >
      <section
        style={sectionStyle}
        className="w-full max-w-xl space-y-6 rounded-[var(--local-radius)] border border-[var(--local-border)] bg-[var(--local-bg)] p-8 shadow-sm"
      >
        {IconComponent && (
          <div data-jp-field="icon" className="mb-2 text-[var(--local-text)]">
            <IconComponent className="h-6 w-6" aria-hidden />
          </div>
        )}

        {(data.title || data.description) && (
          <div>
            {data.title && (
              <h1
                data-jp-field="title"
                className="text-2xl font-semibold tracking-tight text-[var(--local-text)]"
              >
                {data.title}
              </h1>
            )}
            {data.description && (
              <p data-jp-field="description" className="mt-3 text-sm text-muted-foreground">
                {data.description}
              </p>
            )}
          </div>
        )}

        <SetupGuide recipientEmail={data.recipientEmail} />

        <form id={formId} data-olon-recipient={data.recipientEmail ?? ''} className="space-y-4">
          <div>
            <label className="mb-1 block text-xs font-medium text-muted-foreground">Nome</label>
            <input
              name="name"
              type="text"
              required
              className="w-full rounded-[var(--local-radius)] border border-[var(--local-border)] bg-[var(--local-input-bg)] px-3 py-2 text-sm text-[var(--local-input-text)] focus:outline-none focus:ring-1 focus:ring-[var(--local-accent)]"
            />
          </div>

          <div>
            <label className="mb-1 block text-xs font-medium text-muted-foreground">Email</label>
            <input
              name="email"
              type="email"
              required
              className="w-full rounded-[var(--local-radius)] border border-[var(--local-border)] bg-[var(--local-input-bg)] px-3 py-2 text-sm text-[var(--local-input-text)] focus:outline-none focus:ring-1 focus:ring-[var(--local-accent)]"
            />
          </div>

          <div>
            <label className="mb-1 block text-xs font-medium text-muted-foreground">
              Messaggio
            </label>
            <textarea
              name="message"
              required
              rows={4}
              className="w-full resize-none rounded-[var(--local-radius)] border border-[var(--local-border)] bg-[var(--local-input-bg)] px-3 py-2 text-sm text-[var(--local-input-text)] focus:outline-none focus:ring-1 focus:ring-[var(--local-accent)]"
            />
          </div>

          {status === 'error' && <p className="text-xs text-destructive">{message}</p>}
          {status === 'success' && (
            <p className="text-xs text-green-600 dark:text-green-400">
              {data.successMessage || message}
            </p>
          )}

          <button
            type="submit"
            disabled={status === 'submitting'}
            className="w-full rounded-[var(--local-radius)] bg-[var(--local-accent)] px-4 py-2 text-sm font-medium text-[var(--local-accent-foreground)] transition-opacity hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
          >
            {status === 'submitting' ? 'Invio...' : data.submitLabel || 'Invia'}
          </button>
        </form>
      </section>
    </main>
  );
}
END_OF_FILE_CONTENT
echo "Creating src/components/form-demo/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/form-demo/index.ts"
export * from './View';
export * from './schema';
export * from './types';

END_OF_FILE_CONTENT
echo "Creating src/components/form-demo/schema.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/form-demo/schema.ts"
import { z } from 'zod';
import { BaseSectionData, WithFormRecipient } from '@olonjs/core';

export const FormDemoSchema = BaseSectionData.merge(WithFormRecipient).extend({
  icon: z.string().optional().describe('ui:icon-picker'),
  title: z.string().optional().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  submitLabel: z.string().default('Invia').describe('ui:text'),
  successMessage: z.string().default('Richiesta inviata con successo.').describe('ui:text'),
});

export const FormDemoSettingsSchema = z.object({});

/**
 * Submission payload schema for the `form-demo` section.
 *
 * Describes the fields actually submitted by the rendered `<form>` in View.tsx
 * (name, email, message). Exposed via `JsonPagesConfig.submissionSchemas` so that
 * MCP agents can discover the submission contract for this section type without
 * scraping the DOM. See ADR-0002 (docs/decisions/ADR-0002-form-submission-schemas.md).
 */
export const FormDemoSubmissionSchema = z.object({
  name: z.string().min(1).describe('Full name of the person submitting the form'),
  email: z.string().email().describe('Contact email address where we will reply'),
  message: z.string().min(1).describe('Free-form message body'),
});

END_OF_FILE_CONTENT
echo "Creating src/components/form-demo/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/form-demo/types.ts"
import { z } from 'zod';
import { FormDemoSchema, FormDemoSettingsSchema } from './schema';

export type FormDemoData = z.infer<typeof FormDemoSchema>;
export type FormDemoSettings = z.infer<typeof FormDemoSettingsSchema>;

END_OF_FILE_CONTENT
mkdir -p "src/components/header"
echo "Creating src/components/header/View.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/header/View.tsx"
// Layout: Hero=F (MINIMAL HERO), Features=B (HORIZONTAL SCROLL)
import React from 'react';
import { Button } from '@/components/ui/button';
import {
  NavigationMenu,
  NavigationMenuItem,
  NavigationMenuLink,
  NavigationMenuList
} from '@/components/ui/navigation-menu';
import { Sheet, SheetClose, SheetContent, SheetHeader, SheetTitle, SheetTrigger } from '@/components/ui/sheet';
import { Menu, Moon, Sun } from 'lucide-react';
import { useTheme } from '@/components/ThemeProvider';
import type { HeaderData, HeaderSettings } from './types';

export const Header: React.FC<{ data: HeaderData; settings: HeaderSettings }> = ({ data }) => {
  const navItems = Array.isArray(data.menu) ? data.menu : [];
  const { theme, toggleTheme } = useTheme();

  return (
    <header
      style={{
        '--local-bg': 'color-mix(in oklch, var(--background) 94%, transparent)',
        '--local-text': 'var(--foreground)',
        '--local-border': 'var(--border)',
        '--local-surface': 'color-mix(in oklch, var(--card) 90%, transparent)',
        '--local-primary': 'var(--primary)',
        '--local-primary-foreground': 'var(--primary-foreground)',
        '--local-radius-md': 'var(--theme-radius-md)',
        '--local-radius-lg': 'var(--theme-radius-lg)'
      } as React.CSSProperties}
      className="sticky top-0 z-10 border-b border-[var(--local-border)] bg-[var(--local-bg)]/95 backdrop-blur-xl"
    >
      <div className="max-w-[1200px] mx-auto px-8">
        {data.announcement && (
          <div className="py-3 text-center jp-meta" data-jp-field="announcement">
            {data.announcement}
          </div>
        )}
        <div className="flex h-20 items-center justify-between gap-6">
          <a href="/" className="flex items-baseline gap-2">
            <span
              className="text-[1.05rem] font-semibold tracking-[-0.02em] text-[var(--local-text)]"
              style={{ fontFamily: 'var(--theme-wordmark-font-family, var(--font-primary))', fontWeight: '600' }}
              data-jp-field="logoText"
            >
              {data.logoText}
            </span>
            {data.logoHighlight && (
              <span className="jp-meta text-[var(--local-primary)]" data-jp-field="logoHighlight">
                {data.logoHighlight}
              </span>
            )}
          </a>

          <div className="hidden items-center gap-4 lg:flex">
            <NavigationMenu>
              <NavigationMenuList className="gap-1">
                {navItems.map((item, idx) => (
                  <NavigationMenuItem
                    key={item.id || item.href + '-' + idx}
                    data-jp-item-id={item.id || 'menu-' + idx}
                    data-jp-item-field="menu"
                  >
                    <NavigationMenuLink
                      href={item.href}
                      className={
                        item.isCta
                          ? 'inline-flex rounded-[var(--local-radius-md)] border border-[var(--local-border)] bg-[var(--local-surface)] px-4 py-2 text-sm font-medium text-[var(--local-text)] transition hover:border-[var(--local-primary)]'
                          : 'inline-flex rounded-[var(--local-radius-md)] px-4 py-2 text-sm font-medium text-[var(--local-text)] transition hover:bg-[var(--local-surface)]'
                      }
                    >
                      {item.label}
                    </NavigationMenuLink>
                  </NavigationMenuItem>
                ))}
              </NavigationMenuList>
            </NavigationMenu>
            <Button
              type="button"
              variant="outline"
              onClick={toggleTheme}
              className="rounded-[var(--local-radius-md)] border-[var(--local-border)] bg-[var(--local-surface)] text-[var(--local-text)]"
            >
              {theme === 'dark' ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}
            </Button>
          </div>

          <div className="flex items-center gap-3 lg:hidden">
            <Button
              type="button"
              variant="outline"
              onClick={toggleTheme}
              className="rounded-[var(--local-radius-md)] border-[var(--local-border)] bg-[var(--local-surface)] text-[var(--local-text)]"
            >
              {theme === 'dark' ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}
            </Button>
            <Sheet>
              <SheetTrigger asChild>
                <Button variant="outline" className="rounded-[var(--local-radius-md)] border-[var(--local-border)] bg-[var(--local-surface)] text-[var(--local-text)]">
                  <Menu className="h-4 w-4" />
                </Button>
              </SheetTrigger>
              <SheetContent className="flex flex-col gap-0 bg-card text-foreground">
                <SheetHeader className="border-b border-border px-6 py-5">
                  <SheetTitle className="font-display text-lg text-foreground">{data.logoText || 'Menu'}</SheetTitle>
                </SheetHeader>
                <nav className="flex flex-1 flex-col divide-y divide-border overflow-y-auto">
                  {navItems.map((item, idx) => (
                    <SheetClose asChild key={item.id || item.href + '-mobile-' + idx}>
                      <a
                        href={item.href}
                        className="flex items-center px-6 py-4 text-base font-medium text-foreground transition hover:bg-muted active:bg-muted"
                      >
                        {item.label}
                      </a>
                    </SheetClose>
                  ))}
                </nav>
              </SheetContent>
            </Sheet>
          </div>
        </div>
      </div>
    </header>
  );
};

END_OF_FILE_CONTENT
echo "Creating src/components/header/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/header/index.ts"
export { Header } from './View';
export { HeaderSchema } from './schema';
export type { HeaderData, HeaderSettings } from './types';

END_OF_FILE_CONTENT
echo "Creating src/components/header/schema.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/header/schema.ts"
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';

const HeaderMenuItemSchema = z.object({
  id: z.string().optional(),
  label: z.string().describe('ui:text'),
  href: z.string().describe('ui:text'),
  isCta: z.boolean().optional().describe('ui:checkbox')
});

export const HeaderSchema = BaseSectionData.extend({
  announcement: z.string().optional().describe('ui:text'),
  logoText: z.string().describe('ui:text'),
  logoHighlight: z.string().optional().describe('ui:text'),
  menu: z.array(HeaderMenuItemSchema).optional().describe('ui:list')
});

END_OF_FILE_CONTENT
echo "Creating src/components/header/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/header/types.ts"
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { HeaderSchema } from './schema';

export type HeaderData = z.infer<typeof HeaderSchema>;
export type HeaderSettings = z.infer<typeof BaseSectionSettingsSchema>;

END_OF_FILE_CONTENT
mkdir -p "src/components/page-hero"
echo "Creating src/components/page-hero/View.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/page-hero/View.tsx"
// Layout: Hero=E (MAGAZINE), Features=A (BENTO)
import React from 'react';
import type { PageHeroData, PageHeroSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40'
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40'
};

export const PageHero: React.FC<{ data: PageHeroData; settings: PageHeroSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'lg'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'lg'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      bg: 'var(--theme-colors-background)',
      text: 'var(--theme-colors-foreground)',
      muted: 'var(--theme-colors-muted-foreground)',
      surface: 'var(--theme-colors-card)',
      border: 'var(--theme-colors-border)'
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)'
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)'
    }
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-accent': 'var(--accent)',
        '--local-border': t.border,
        '--local-surface': t.surface,
        '--local-radius-sm': 'var(--theme-radius-sm)',
        '--local-radius-md': 'var(--theme-radius-md)',
        '--local-radius-lg': 'var(--theme-radius-lg)'
      } as React.CSSProperties}
      className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}
    >
      <div className={containerClass}>
        <div className="grid gap-8 lg:grid-cols-[1.15fr_0.85fr] lg:items-end">
          <div className="space-y-5">
            {data.label && (
              <div className="jp-section-label inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-accent)] mb-4" data-jp-field="label">
                <span className="w-5 h-px bg-[var(--local-primary)]" />
                {data.label}
              </div>
            )}
            <h1 className="font-display font-black text-[clamp(2.7rem,5vw,4.8rem)] leading-[1.02] tracking-tight text-[var(--local-text)]" data-jp-field="title">
              {data.title}
            </h1>
          </div>
          <p className="max-w-xl text-[1rem] text-[var(--local-text-muted)] lg:justify-self-end" data-jp-field="description">
            {data.description}
          </p>
        </div>
      </div>
    </section>
  );
};

END_OF_FILE_CONTENT
echo "Creating src/components/page-hero/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/page-hero/index.ts"
export { PageHero } from './View';
export { PageHeroSchema } from './schema';
export type { PageHeroData, PageHeroSettings } from './types';

END_OF_FILE_CONTENT
echo "Creating src/components/page-hero/schema.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/page-hero/schema.ts"
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';

export const PageHeroSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().describe('ui:textarea')
});

END_OF_FILE_CONTENT
echo "Creating src/components/page-hero/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/page-hero/types.ts"
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { PageHeroSchema } from './schema';

export type PageHeroData = z.infer<typeof PageHeroSchema>;
export type PageHeroSettings = z.infer<typeof BaseSectionSettingsSchema>;

END_OF_FILE_CONTENT
mkdir -p "src/components/philosophy"
echo "Creating src/components/philosophy/View.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/philosophy/View.tsx"
// Layout: Hero=E (MAGAZINE), Features=D (ACCORDION)
import React from 'react';
import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from '@/components/ui/accordion';
import type { PhilosophyData, PhilosophySettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40'
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40'
};

export const Philosophy: React.FC<{ data: PhilosophyData; settings: PhilosophySettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      bg: 'var(--theme-colors-background)',
      text: 'var(--theme-colors-foreground)',
      muted: 'var(--theme-colors-muted-foreground)',
      surface: 'var(--theme-colors-card)',
      border: 'var(--theme-colors-border)'
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)'
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)'
    }
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-accent': 'var(--accent)',
        '--local-border': t.border,
        '--local-surface': t.surface,
        '--local-radius-sm': 'var(--theme-radius-sm)',
        '--local-radius-md': 'var(--theme-radius-md)',
        '--local-radius-lg': 'var(--theme-radius-lg)'
      } as React.CSSProperties}
      className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}
    >
      <div className={containerClass}>
        <div className="mb-10 max-w-2xl">
          {data.label && (
            <div className="jp-section-label inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-accent)] mb-4" data-jp-field="label">
              <span className="w-5 h-px bg-[var(--local-primary)]" />
              {data.label}
            </div>
          )}
          <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">
            {data.title}
          </h2>
          {data.description && (
            <p className="mt-4 text-[var(--local-text-muted)]" data-jp-field="description">
              {data.description}
            </p>
          )}
        </div>
        <Accordion type="single" collapsible className="w-full space-y-4">
          {data.items.map((item, idx) => (
            <AccordionItem
              key={item.id || 'legacy-' + idx}
              value={item.id || 'legacy-' + idx}
              className="rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-surface)] px-6"
              data-jp-item-id={item.id || 'legacy-' + idx}
              data-jp-item-field="items"
            >
              <AccordionTrigger className="text-left font-display text-[1.1rem] text-[var(--local-text)]">
                {item.title}
              </AccordionTrigger>
              <AccordionContent className="pb-5 text-sm text-[var(--local-text-muted)]">
                {item.body}
              </AccordionContent>
            </AccordionItem>
          ))}
        </Accordion>
      </div>
    </section>
  );
};

END_OF_FILE_CONTENT
echo "Creating src/components/philosophy/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/philosophy/index.ts"
export { Philosophy } from './View';
export { PhilosophySchema } from './schema';
export type { PhilosophyData, PhilosophySettings } from './types';

END_OF_FILE_CONTENT
echo "Creating src/components/philosophy/schema.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/philosophy/schema.ts"
import { z } from 'zod';
import { BaseSectionData, BaseArrayItem } from '@olonjs/core';

const PrincipleSchema = BaseArrayItem.extend({
  title: z.string().describe('ui:text'),
  body: z.string().describe('ui:textarea')
});

export const PhilosophySchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  items: z.array(PrincipleSchema).describe('ui:list')
});

END_OF_FILE_CONTENT
echo "Creating src/components/philosophy/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/philosophy/types.ts"
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { PhilosophySchema } from './schema';

export type PhilosophyData = z.infer<typeof PhilosophySchema>;
export type PhilosophySettings = z.infer<typeof BaseSectionSettingsSchema>;

END_OF_FILE_CONTENT
mkdir -p "src/components/post-detail"
echo "Creating src/components/post-detail/View.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/post-detail/View.tsx"
// Layout: Hero=E (MAGAZINE), Features=B (HORIZONTAL SCROLL)
import React from 'react';
import type { PostDetailData, PostDetailSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40'
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40'
};

export const PostDetail: React.FC<{ data: PostDetailData; settings: PostDetailSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'lg'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'lg'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      bg: 'var(--theme-colors-background)',
      text: 'var(--theme-colors-foreground)',
      muted: 'var(--theme-colors-muted-foreground)',
      surface: 'var(--theme-colors-card)',
      border: 'var(--theme-colors-border)'
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)'
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)'
    }
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;
  const item = data.item;

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-accent': 'var(--accent)',
        '--local-border': t.border,
        '--local-surface': t.surface,
        '--local-radius-sm': 'var(--theme-radius-sm)',
        '--local-radius-md': 'var(--theme-radius-md)',
        '--local-radius-lg': 'var(--theme-radius-lg)'
      } as React.CSSProperties}
      className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}
    >
      <div className={containerClass}>
        <article className="max-w-3xl space-y-8">
          <header className="space-y-4">
            <div className="flex flex-wrap gap-3">
              <span className="jp-meta">{item.date}</span>
              <span className="jp-meta">{item.readingTime}</span>
            </div>
            <h1 className="font-display font-black text-[clamp(2.7rem,5vw,4.8rem)] leading-[1.02] tracking-tight text-[var(--local-text)]">
              {item.title}
            </h1>
            <p className="text-[1.05rem] text-[var(--local-text-muted)]">{item.dek}</p>
            <div className="flex flex-wrap gap-2">
              {item.tags.map((tag, idx) => (
                <span key={tag + '-' + idx} className="jp-chip">{tag}</span>
              ))}
            </div>
          </header>
          <div className="prose-terminal space-y-5">
            {item.content.map((paragraph, idx) => (
              <p key={paragraph.slice(0, 24) + '-' + idx}>{paragraph}</p>
            ))}
          </div>
          <div className="rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-surface)] p-6">
            <h2 className="font-display text-2xl text-[var(--local-text)]">Related topics</h2>
            <div className="mt-4 flex flex-wrap gap-2">
              {item.related.map((entry, idx) => (
                <span key={entry + '-' + idx} className="jp-chip">{entry}</span>
              ))}
            </div>
          </div>
        </article>
      </div>
    </section>
  );
};

END_OF_FILE_CONTENT
echo "Creating src/components/post-detail/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/post-detail/index.ts"
export { PostDetail } from './View';
export { PostDetailSchema } from './schema';
export type { PostDetailData, PostDetailSettings } from './types';

END_OF_FILE_CONTENT
echo "Creating src/components/post-detail/schema.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/post-detail/schema.ts"
import { BaseSectionData } from '@olonjs/core';
import { PostSchema } from '@/collections/posts';

export const PostDetailSchema = BaseSectionData.extend({
  item: PostSchema.describe('ui:collection-ref')
});

END_OF_FILE_CONTENT
echo "Creating src/components/post-detail/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/post-detail/types.ts"
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { PostDetailSchema } from './schema';

export type PostDetailData = z.infer<typeof PostDetailSchema>;
export type PostDetailSettings = z.infer<typeof BaseSectionSettingsSchema>;

END_OF_FILE_CONTENT
mkdir -p "src/components/project-detail"
echo "Creating src/components/project-detail/View.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/project-detail/View.tsx"
// Layout: Hero=E (MAGAZINE), Features=C (TIMELINE)
import React from 'react';
import type { ProjectDetailData, ProjectDetailSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40'
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40'
};

export const ProjectDetail: React.FC<{ data: ProjectDetailData; settings: ProjectDetailSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'lg'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'lg'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      bg: 'var(--theme-colors-background)',
      text: 'var(--theme-colors-foreground)',
      muted: 'var(--theme-colors-muted-foreground)',
      surface: 'var(--theme-colors-card)',
      border: 'var(--theme-colors-border)'
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)'
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)'
    }
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;
  const item = data.item;

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-accent': 'var(--accent)',
        '--local-border': t.border,
        '--local-surface': t.surface,
        '--local-radius-sm': 'var(--theme-radius-sm)',
        '--local-radius-md': 'var(--theme-radius-md)',
        '--local-radius-lg': 'var(--theme-radius-lg)'
      } as React.CSSProperties}
      className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}
    >
      <div className={containerClass}>
        <div className="max-w-4xl space-y-10">
          <div className="space-y-4">
            <div className="flex flex-wrap gap-2">
              <span className="jp-chip">{item.year}</span>
              <span className="jp-chip">{item.category}</span>
            </div>
            <h1 className="font-display font-black text-[clamp(2.7rem,5vw,4.8rem)] leading-[1.02] tracking-tight text-[var(--local-text)]">
              {item.title}
            </h1>
            <p className="max-w-3xl text-[1.05rem] text-[var(--local-text-muted)]">{item.summary}</p>
          </div>
          <div className="grid gap-6 md:grid-cols-3">
            <div className="rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-surface)] p-5">
              <div className="jp-meta">Context</div>
              <p className="mt-3 text-sm text-[var(--local-text)]">{item.context}</p>
            </div>
            <div className="rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-surface)] p-5">
              <div className="jp-meta">Problem</div>
              <p className="mt-3 text-sm text-[var(--local-text)]">{item.problem}</p>
            </div>
            <div className="rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-surface)] p-5">
              <div className="jp-meta">Result</div>
              <p className="mt-3 text-sm text-[var(--local-text)]">{item.result}</p>
            </div>
          </div>
          <div className="grid gap-6">
            <div className="rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-surface)] p-7">
              <h2 className="font-display text-2xl text-[var(--local-text)]">Architecture decision</h2>
              <p className="mt-4 text-[var(--local-text-muted)]">{item.architecture}</p>
            </div>
            <div className="rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-surface)] p-7">
              <h2 className="font-display text-2xl text-[var(--local-text)]">Stack used</h2>
              <div className="mt-4 flex flex-wrap gap-2">
                {item.stack.map((tech, idx) => (
                  <span key={tech + '-' + idx} className="jp-chip">{tech}</span>
                ))}
              </div>
            </div>
            <div className="rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-surface)] p-7">
              <h2 className="font-display text-2xl text-[var(--local-text)]">Outcome</h2>
              <p className="mt-4 text-[var(--local-text-muted)]">{item.outcomeLong}</p>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
};

END_OF_FILE_CONTENT
echo "Creating src/components/project-detail/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/project-detail/index.ts"
export { ProjectDetail } from './View';
export { ProjectDetailSchema } from './schema';
export type { ProjectDetailData, ProjectDetailSettings } from './types';

END_OF_FILE_CONTENT
echo "Creating src/components/project-detail/schema.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/project-detail/schema.ts"
import { BaseSectionData } from '@olonjs/core';
import { ProjectSchema } from '@/collections/projects';

export const ProjectDetailSchema = BaseSectionData.extend({
  item: ProjectSchema.describe('ui:collection-ref')
});

END_OF_FILE_CONTENT
echo "Creating src/components/project-detail/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/project-detail/types.ts"
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { ProjectDetailSchema } from './schema';

export type ProjectDetailData = z.infer<typeof ProjectDetailSchema>;
export type ProjectDetailSettings = z.infer<typeof BaseSectionSettingsSchema>;

END_OF_FILE_CONTENT
mkdir -p "src/components/save-drawer"
echo "Creating src/components/save-drawer/DeployConnector.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/save-drawer/DeployConnector.tsx"
import type { StepState } from '@olonjs/core';

interface DeployConnectorProps {
  fromState: StepState;
  toState: StepState;
  color: string;
}

export function DeployConnector({ fromState, toState, color }: DeployConnectorProps) {
  const filled = fromState === 'done' && toState === 'done';
  const filling = fromState === 'done' && toState === 'active';
  const lit = filled || filling;

  return (
    <div className="jp-drawer-connector">
      <div className="jp-drawer-connector-base" />

      <div
        className="jp-drawer-connector-fill"
        style={{
          background: `linear-gradient(90deg, ${color}cc, ${color}66)`,
          width: filled ? '100%' : filling ? '100%' : '0%',
          transition: filling ? 'width 2s cubic-bezier(0.4,0,0.2,1)' : 'none',
          boxShadow: lit ? `0 0 8px ${color}77` : 'none',
        }}
      />

      {filling && (
        <div
          className="jp-drawer-connector-orb"
          style={{
            background: color,
            boxShadow: `0 0 14px ${color}, 0 0 28px ${color}88`,
            animation: 'orb-travel 2s cubic-bezier(0.4,0,0.6,1) forwards',
          }}
        />
      )}
    </div>
  );
}


END_OF_FILE_CONTENT
echo "Creating src/components/save-drawer/DeployNode.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/save-drawer/DeployNode.tsx"
import type { CSSProperties } from 'react';
import type { DeployStep, StepState } from '@olonjs/core';

interface DeployNodeProps {
  step: DeployStep;
  state: StepState;
}

export function DeployNode({ step, state }: DeployNodeProps) {
  const isActive = state === 'active';
  const isDone = state === 'done';
  const isPending = state === 'pending';

  return (
    <div className="jp-drawer-node-wrap">
      <div
        className={`jp-drawer-node ${isPending ? 'jp-drawer-node-pending' : ''}`}
        style={
          {
            background: isDone ? step.color : isActive ? 'rgba(0,0,0,0.5)' : undefined,
            borderWidth: isDone ? 0 : 1,
            borderColor: isActive ? `${step.color}80` : undefined,
            boxShadow: isDone
              ? `0 0 20px ${step.color}55, 0 0 40px ${step.color}22`
              : isActive
                ? `0 0 14px ${step.color}33`
                : undefined,
            animation: isActive ? 'node-glow 2s ease infinite' : undefined,
            ['--glow-color' as string]: step.color,
          } as CSSProperties
        }
      >
        {isDone && (
          <svg className="h-5 w-5" viewBox="0 0 24 24" fill="none" aria-label="Done">
            <path
              className="stroke-dash-30 animate-check-draw"
              d="M5 13l4 4L19 7"
              stroke="#0a0f1a"
              strokeWidth="2.5"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
        )}

        {isActive && (
          <span
            className="jp-drawer-node-glyph jp-drawer-node-glyph-active"
            style={{ color: step.color, animation: 'glyph-rotate 9s linear infinite' }}
            aria-hidden
          >
            {step.glyph}
          </span>
        )}

        {isPending && (
          <span className="jp-drawer-node-glyph jp-drawer-node-glyph-pending" aria-hidden>
            {step.glyph}
          </span>
        )}

        {isActive && (
          <span
            className="jp-drawer-node-ring"
            style={{
              inset: -7,
              borderColor: `${step.color}50`,
              animation: 'ring-expand 2s ease-out infinite',
            }}
          />
        )}
      </div>

      <span
        className="jp-drawer-node-label"
        style={{ color: isDone ? step.color : isActive ? 'rgba(255,255,255,0.85)' : 'rgba(255,255,255,0.18)' }}
      >
        {step.label}
      </span>
    </div>
  );
}


END_OF_FILE_CONTENT
echo "Creating src/components/save-drawer/DopaDrawer.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/save-drawer/DopaDrawer.tsx"
import { useEffect, useMemo, useState } from 'react';
import { createPortal } from 'react-dom';
import type { StepId, StepState } from '@olonjs/core';
import { DEPLOY_STEPS } from '@olonjs/core';
import fontsCss from '@/fonts.css?inline';
import saverStyleCss from './saverStyle.css?inline';
import { DeployNode } from './DeployNode';
import { DeployConnector } from './DeployConnector';
import { BuildBars, ElapsedTimer, Particles, SuccessBurst } from './Visuals';

interface DopaDrawerProps {
  isOpen: boolean;
  phase: 'idle' | 'running' | 'done' | 'error';
  currentStepId: StepId | null;
  doneSteps: StepId[];
  progress: number;
  errorMessage?: string;
  deployUrl?: string;
  onClose: () => void;
  onRetry: () => void;
}

export function DopaDrawer({
  isOpen,
  phase,
  currentStepId,
  doneSteps,
  progress,
  errorMessage,
  deployUrl,
  onClose,
  onRetry,
}: DopaDrawerProps) {
  const [shadowMount, setShadowMount] = useState<HTMLElement | null>(null);
  const [burst, setBurst] = useState(false);
  const [countdown, setCountdown] = useState(3);

  const isRunning = phase === 'running';
  const isDone = phase === 'done';
  const isError = phase === 'error';

  useEffect(() => {
    const host = document.createElement('div');
    host.setAttribute('data-jp-drawer-shadow-host', '');

    const shadowRoot = host.attachShadow({ mode: 'open' });
    const style = document.createElement('style');
    style.textContent = `${fontsCss}\n${saverStyleCss}`;

    const mount = document.createElement('div');
    shadowRoot.append(style, mount);

    document.body.appendChild(host);
    setShadowMount(mount);

    return () => {
      setShadowMount(null);
      host.remove();
    };
  }, []);

  useEffect(() => {
    if (!isOpen) {
      setBurst(false);
      setCountdown(3);
      return;
    }
    if (isDone) setBurst(true);
  }, [isDone, isOpen]);

  useEffect(() => {
    if (!isOpen || !isDone) return;
    setCountdown(3);
    const interval = window.setInterval(() => {
      setCountdown((prev) => {
        if (prev <= 1) {
          window.clearInterval(interval);
          onClose();
          return 0;
        }
        return prev - 1;
      });
    }, 1000);
    return () => window.clearInterval(interval);
  }, [isDone, isOpen, onClose]);

  const currentStep = useMemo(
    () => DEPLOY_STEPS.find((step) => step.id === currentStepId) ?? null,
    [currentStepId]
  );

  const activeColor = isDone ? '#34d399' : isError ? '#f87171' : (currentStep?.color ?? '#60a5fa');
  const particleCount = isDone ? 40 : doneSteps.length === 3 ? 28 : doneSteps.length === 2 ? 16 : doneSteps.length === 1 ? 8 : 4;

  const stepState = (index: number): StepState => {
    const step = DEPLOY_STEPS[index];
    if (doneSteps.includes(step.id)) return 'done';
    if (phase === 'running' && currentStepId === step.id) return 'active';
    return 'pending';
  };

  if (!shadowMount || !isOpen || phase === 'idle') return null;

  return createPortal(
    <div className="jp-drawer-root">
      <div
        className="jp-drawer-overlay animate-fade-in"
        onClick={isDone || isError ? onClose : undefined}
        aria-hidden
      />

      <div
        role="status"
        aria-live="polite"
        aria-label={isDone ? 'Deploy completed' : isError ? 'Deploy failed' : 'Deploying'}
        className="jp-drawer-shell animate-drawer-up"
        style={{ bottom: 'max(2.25rem, env(safe-area-inset-bottom))' }}
      >
        <div
          className="jp-drawer-card"
          style={{
            backgroundColor: 'hsl(222 18% 7%)',
            boxShadow: `0 0 0 1px rgba(255,255,255,0.04), 0 -20px 60px rgba(0,0,0,0.6), 0 0 80px ${activeColor}0d`,
            transition: 'box-shadow 1.2s ease',
          }}
        >
          <div
            className="jp-drawer-ambient"
            style={{
              background: `radial-gradient(ellipse 70% 60% at 50% 110%, ${activeColor}12 0%, transparent 65%)`,
              transition: 'background 1.5s ease',
              animation: 'ambient-pulse 3.5s ease infinite',
            }}
            aria-hidden
          />

          {isDone && (
            <div className="jp-drawer-shimmer" aria-hidden>
              <div
                className="jp-drawer-shimmer-bar"
                style={{
                  background: 'linear-gradient(90deg, transparent, rgba(255,255,255,0.04), transparent)',
                  animation: 'shimmer-sweep 1.4s 0.1s ease forwards',
                }}
              />
            </div>
          )}

          <Particles count={particleCount} color={activeColor} />
          {burst && <SuccessBurst />}

          <div className="jp-drawer-content">
            <div className="jp-drawer-header">
              <div className="jp-drawer-header-left">
                <div className="jp-drawer-status" style={{ color: activeColor }}>
                  <span
                    className="jp-drawer-status-dot"
                    style={{
                      background: activeColor,
                      boxShadow: `0 0 6px ${activeColor}`,
                      animation: isRunning ? 'ambient-pulse 1.5s ease infinite' : 'none',
                    }}
                    aria-hidden
                  />
                  {isDone ? 'Live' : isError ? 'Build failed' : currentStep?.verb ?? 'Saving'}
                </div>

                <div key={currentStep?.id ?? phase} className="jp-drawer-copy animate-text-in">
                  {isDone ? (
                    <div className="animate-success-pop">
                      <p className="jp-drawer-copy-title jp-drawer-copy-title-lg">Your content is live.</p>
                      <p className="jp-drawer-copy-sub">Deployed to production successfully</p>
                    </div>
                  ) : isError ? (
                    <>
                      <p className="jp-drawer-copy-title jp-drawer-copy-title-md">Deploy failed at build.</p>
                      <p className="jp-drawer-copy-sub jp-drawer-copy-sub-error">{errorMessage ?? 'Check your Vercel logs or retry below'}</p>
                    </>
                  ) : currentStep ? (
                    <>
                      <p className="jp-drawer-poem-line jp-drawer-poem-line-1">{currentStep.poem[0]}</p>
                      <p className="jp-drawer-poem-line jp-drawer-poem-line-2">{currentStep.poem[1]}</p>
                    </>
                  ) : null}
                </div>
              </div>

              <div className="jp-drawer-right">
                {isDone ? (
                  <div className="jp-drawer-countdown-wrap animate-fade-up">
                    <span className="jp-drawer-countdown-text" aria-live="polite">
                      Chiusura in {countdown}s
                    </span>
                    <div className="jp-drawer-countdown-track">
                      <div className="jp-drawer-countdown-bar countdown-bar" style={{ boxShadow: '0 0 6px #34d39988' }} />
                    </div>
                  </div>
                ) : (
                  <ElapsedTimer running={isRunning} />
                )}
              </div>
            </div>

            <div className="jp-drawer-track-row">
              {DEPLOY_STEPS.map((step, i) => (
                <div key={step.id} style={{ display: 'flex', alignItems: 'center', flex: i < DEPLOY_STEPS.length - 1 ? 1 : 'none' }}>
                  <DeployNode step={step} state={stepState(i)} />
                  {i < DEPLOY_STEPS.length - 1 && (
                    <DeployConnector fromState={stepState(i)} toState={stepState(i + 1)} color={DEPLOY_STEPS[i + 1].color} />
                  )}
                </div>
              ))}
            </div>

            <div className="jp-drawer-bars-wrap">
              <BuildBars active={stepState(2) === 'active'} />
            </div>

            <div className="jp-drawer-separator" />

            <div className="jp-drawer-footer">
              <div className="jp-drawer-progress">
                <div
                  className="jp-drawer-progress-indicator"
                  style={{
                    width: `${Math.max(0, Math.min(100, progress))}%`,
                    background: `linear-gradient(90deg, ${DEPLOY_STEPS[0].color}, ${activeColor})`,
                  }}
                />
              </div>

              <div className="jp-drawer-cta">
                {isDone && (
                  <div className="jp-drawer-btn-row animate-fade-up">
                    <button type="button" className="jp-drawer-btn jp-drawer-btn-secondary" onClick={onClose}>
                      Chiudi
                    </button>
                    <button
                      type="button"
                      className="jp-drawer-btn jp-drawer-btn-emerald"
                      onClick={() => {
                        if (deployUrl) window.open(deployUrl, '_blank', 'noopener,noreferrer');
                      }}
                      disabled={!deployUrl}
                    >
                      <span aria-hidden>↗</span> Open site
                    </button>
                  </div>
                )}

                {isError && (
                  <div className="jp-drawer-btn-row animate-fade-up">
                    <button type="button" className="jp-drawer-btn jp-drawer-btn-ghost" onClick={onClose}>
                      Annulla
                    </button>
                    <button type="button" className="jp-drawer-btn jp-drawer-btn-destructive" onClick={onRetry}>
                      Retry
                    </button>
                  </div>
                )}

                {isRunning && (
                  <span className="jp-drawer-running-step" aria-hidden>
                    {doneSteps.length + 1} / {DEPLOY_STEPS.length}
                  </span>
                )}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>,
    shadowMount
  );
}


END_OF_FILE_CONTENT
echo "Creating src/components/save-drawer/Visuals.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/save-drawer/Visuals.tsx"
import { useEffect, useRef, useState } from 'react';
import type { CSSProperties } from 'react';

interface Particle {
  id: number;
  x: number;
  y: number;
  size: number;
  dur: number;
  delay: number;
}

const PARTICLE_POOL: Particle[] = Array.from({ length: 44 }, (_, i) => ({
  id: i,
  x: 5 + Math.random() * 90,
  y: 15 + Math.random() * 70,
  size: 1.5 + Math.random() * 2.5,
  dur: 2.8 + Math.random() * 3.5,
  delay: Math.random() * 4,
}));

interface ParticlesProps {
  count: number;
  color: string;
}

export function Particles({ count, color }: ParticlesProps) {
  return (
    <div className="jp-drawer-particles" aria-hidden>
      {PARTICLE_POOL.slice(0, count).map((particle) => (
        <div
          key={particle.id}
          className="jp-drawer-particle"
          style={{
            left: `${particle.x}%`,
            bottom: `${particle.y}%`,
            width: particle.size,
            height: particle.size,
            background: color,
            boxShadow: `0 0 ${particle.size * 3}px ${color}`,
            opacity: 0,
            animation: `particle-float ${particle.dur}s ${particle.delay}s ease-out infinite`,
          }}
        />
      ))}
    </div>
  );
}

const BAR_H = [0.45, 0.75, 0.55, 0.9, 0.65, 0.8, 0.5, 0.72, 0.6, 0.85, 0.42, 0.7];

interface BuildBarsProps {
  active: boolean;
}

export function BuildBars({ active }: BuildBarsProps) {
  if (!active) return <div className="jp-drawer-bars-placeholder" />;

  return (
    <div className="jp-drawer-bars" aria-hidden>
      {BAR_H.map((height, i) => (
        <div
          key={i}
          className="jp-drawer-bar"
          style={{
            height: `${height * 100}%`,
            animation: `bar-eq ${0.42 + i * 0.06}s ${i * 0.04}s ease-in-out infinite alternate`,
          }}
        />
      ))}
    </div>
  );
}

const BURST_COLORS = ['#34d399', '#60a5fa', '#a78bfa', '#f59e0b', '#f472b6'];

export function SuccessBurst() {
  return (
    <div className="jp-drawer-burst" aria-hidden>
      {Array.from({ length: 16 }).map((_, i) => (
        <div
          key={i}
          className="jp-drawer-burst-dot"
          style={
            {
              background: BURST_COLORS[i % BURST_COLORS.length],
              ['--r' as string]: `${i * 22.5}deg`,
              animation: `burst-ray 0.85s ${i * 0.03}s cubic-bezier(0,0.6,0.5,1) forwards`,
              transform: `rotate(${i * 22.5}deg)`,
              transformOrigin: '50% 50%',
              opacity: 0,
            } as CSSProperties
          }
        />
      ))}
    </div>
  );
}

interface ElapsedTimerProps {
  running: boolean;
}

export function ElapsedTimer({ running }: ElapsedTimerProps) {
  const [elapsed, setElapsed] = useState(0);
  const startRef = useRef<number | null>(null);
  const rafRef = useRef<number | null>(null);

  useEffect(() => {
    if (!running) return;
    if (!startRef.current) startRef.current = performance.now();

    const tick = () => {
      if (!startRef.current) return;
      setElapsed(Math.floor((performance.now() - startRef.current) / 1000));
      rafRef.current = requestAnimationFrame(tick);
    };

    rafRef.current = requestAnimationFrame(tick);
    return () => {
      if (rafRef.current) cancelAnimationFrame(rafRef.current);
    };
  }, [running]);

  const sec = String(elapsed % 60).padStart(2, '0');
  const min = String(Math.floor(elapsed / 60)).padStart(2, '0');
  return <span className="jp-drawer-elapsed" aria-live="off">{min}:{sec}</span>;
}


END_OF_FILE_CONTENT
echo "Creating src/components/save-drawer/saverStyle.css..."
cat << 'END_OF_FILE_CONTENT' > "src/components/save-drawer/saverStyle.css"
/* Save Drawer strict_full isolated stylesheet */

.jp-drawer-root {
  --background: 222 18% 6%;
  --foreground: 210 20% 96%;
  --card: 222 16% 8%;
  --card-foreground: 210 20% 96%;
  --primary: 0 0% 95%;
  --primary-foreground: 222 18% 6%;
  --secondary: 220 14% 13%;
  --secondary-foreground: 210 20% 96%;
  --destructive: 0 72% 51%;
  --destructive-foreground: 0 0% 98%;
  --border: 220 14% 13%;
  --radius: 0.6rem;
  font-family: 'Geist', system-ui, sans-serif;
}

.jp-drawer-overlay {
  position: fixed;
  inset: 0;
  z-index: 2147483600;
  background: rgb(0 0 0 / 0.4);
  backdrop-filter: blur(2px);
}

.jp-drawer-shell {
  position: fixed;
  left: 0;
  right: 0;
  z-index: 2147483601;
  display: flex;
  justify-content: center;
  padding: 0 1rem;
}

.jp-drawer-card {
  position: relative;
  width: 100%;
  max-width: 31rem;
  overflow: hidden;
  border-radius: 1rem;
  border: 1px solid rgb(255 255 255 / 0.07);
}

.jp-drawer-ambient {
  position: absolute;
  inset: 0;
  pointer-events: none;
}

.jp-drawer-shimmer {
  position: absolute;
  inset: 0;
  overflow: hidden;
  pointer-events: none;
}

.jp-drawer-shimmer-bar {
  position: absolute;
  inset-block: 0;
  width: 35%;
}

.jp-drawer-content {
  position: relative;
  z-index: 10;
  padding: 2rem 2rem 1.75rem;
}

.jp-drawer-header {
  margin-bottom: 1.5rem;
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
}

.jp-drawer-header-left {
  display: flex;
  flex-direction: column;
  gap: 0.625rem;
}

.jp-drawer-status {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.75rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.1em;
  transition: color 0.5s;
}

.jp-drawer-status-dot {
  width: 0.375rem;
  height: 0.375rem;
  border-radius: 9999px;
  display: inline-block;
}

.jp-drawer-copy {
  min-height: 52px;
}

.jp-drawer-copy-title {
  margin: 0;
  color: white;
  line-height: 1.25;
  font-weight: 600;
}

.jp-drawer-copy-title-lg {
  font-size: 1.125rem;
}

.jp-drawer-copy-title-md {
  font-size: 1rem;
}

.jp-drawer-copy-sub {
  margin: 0.125rem 0 0;
  color: rgb(255 255 255 / 0.4);
  font-size: 0.875rem;
}

.jp-drawer-copy-sub-error {
  color: rgb(255 255 255 / 0.35);
}

.jp-drawer-poem-line {
  margin: 0;
  font-size: 0.875rem;
  font-weight: 300;
  line-height: 1.5;
}

.jp-drawer-poem-line-1 {
  color: rgb(255 255 255 / 0.55);
}

.jp-drawer-poem-line-2 {
  color: rgb(255 255 255 / 0.3);
}

.jp-drawer-right {
  margin-left: 1.5rem;
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 0.5rem;
  flex-shrink: 0;
}

.jp-drawer-countdown-wrap {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 0.5rem;
}

.jp-drawer-countdown-text {
  font-family: 'Geist Mono', ui-monospace, SFMono-Regular, Menlo, monospace;
  font-size: 0.75rem;
  font-weight: 600;
  color: #34d399;
}

.jp-drawer-countdown-track {
  width: 6rem;
  height: 0.125rem;
  border-radius: 9999px;
  overflow: hidden;
  background: rgb(255 255 255 / 0.1);
}

.jp-drawer-countdown-bar {
  width: 100%;
  height: 100%;
  border-radius: 9999px;
  background: #34d399;
}

.jp-drawer-track-row {
  margin-bottom: 1rem;
  display: flex;
  align-items: center;
}

.jp-drawer-bars-wrap {
  margin-bottom: 1rem;
  display: flex;
  justify-content: center;
}

.jp-drawer-separator {
  margin-bottom: 1rem;
  height: 1px;
  width: 100%;
  border: 0;
  background: rgb(255 255 255 / 0.06);
}

.jp-drawer-footer {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.jp-drawer-progress {
  flex: 1;
  height: 2px;
  border-radius: 9999px;
  overflow: hidden;
  background: rgb(255 255 255 / 0.06);
}

.jp-drawer-progress-indicator {
  height: 100%;
}

.jp-drawer-cta {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex-shrink: 0;
}

.jp-drawer-running-step {
  font-family: 'Geist Mono', ui-monospace, SFMono-Regular, Menlo, monospace;
  font-size: 0.75rem;
  color: rgb(255 255 255 / 0.2);
}

.jp-drawer-btn-row {
  display: flex;
  gap: 0.5rem;
}

.jp-drawer-btn {
  border: 1px solid transparent;
  border-radius: 0.375rem;
  font-size: 0.8125rem;
  font-weight: 500;
  line-height: 1;
  height: 2.25rem;
  padding: 0 0.75rem;
  cursor: pointer;
  transition: all 0.2s ease;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 0.375rem;
}

.jp-drawer-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.jp-drawer-btn-secondary {
  background: hsl(var(--secondary));
  color: hsl(var(--secondary-foreground));
}

.jp-drawer-btn-secondary:hover {
  filter: brightness(1.08);
}

.jp-drawer-btn-emerald {
  background: #34d399;
  color: #18181b;
  font-weight: 600;
}

.jp-drawer-btn-emerald:hover {
  background: #6ee7b7;
}

.jp-drawer-btn-ghost {
  background: transparent;
  color: rgb(255 255 255 / 0.9);
}

.jp-drawer-btn-ghost:hover {
  background: rgb(255 255 255 / 0.08);
}

.jp-drawer-btn-destructive {
  background: hsl(var(--destructive));
  color: hsl(var(--destructive-foreground));
}

.jp-drawer-btn-destructive:hover {
  filter: brightness(1.06);
}

.jp-drawer-node-wrap {
  position: relative;
  z-index: 10;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.625rem;
}

.jp-drawer-node {
  position: relative;
  width: 3rem;
  height: 3rem;
  border-radius: 9999px;
  border: 1px solid transparent;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.5s;
}

.jp-drawer-node-pending {
  border-color: rgb(255 255 255 / 0.08);
  background: rgb(255 255 255 / 0.02);
}

.jp-drawer-node-glyph {
  font-size: 1.125rem;
  line-height: 1;
}

.jp-drawer-node-glyph-active {
  display: inline-block;
}

.jp-drawer-node-glyph-pending {
  color: rgb(255 255 255 / 0.15);
}

.jp-drawer-node-ring {
  position: absolute;
  border-radius: 9999px;
  border: 1px solid transparent;
}

.jp-drawer-node-label {
  font-size: 10px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.1em;
  transition: color 0.5s;
}

.jp-drawer-connector {
  position: relative;
  z-index: 0;
  flex: 1;
  height: 2px;
  margin-top: -24px;
}

.jp-drawer-connector-base {
  position: absolute;
  inset: 0;
  border-radius: 9999px;
  background: rgb(255 255 255 / 0.08);
}

.jp-drawer-connector-fill {
  position: absolute;
  left: 0;
  right: auto;
  top: 0;
  bottom: 0;
  border-radius: 9999px;
}

.jp-drawer-connector-orb {
  position: absolute;
  top: 50%;
  transform: translateY(-50%);
  width: 10px;
  height: 10px;
  border-radius: 9999px;
}

.jp-drawer-particles {
  position: absolute;
  inset: 0;
  overflow: hidden;
  pointer-events: none;
}

.jp-drawer-particle {
  position: absolute;
  border-radius: 9999px;
}

.jp-drawer-bars {
  height: 1.75rem;
  display: flex;
  align-items: flex-end;
  gap: 3px;
}

.jp-drawer-bars-placeholder {
  height: 1.75rem;
}

.jp-drawer-bar {
  width: 3px;
  border-radius: 2px;
  background: #f59e0b;
  transform-origin: bottom;
}

.jp-drawer-burst {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  pointer-events: none;
}

.jp-drawer-burst-dot {
  position: absolute;
  width: 5px;
  height: 5px;
  border-radius: 9999px;
}

.jp-drawer-elapsed {
  font-family: 'Geist Mono', ui-monospace, SFMono-Regular, Menlo, monospace;
  font-size: 0.75rem;
  letter-spacing: 0.1em;
  color: rgb(255 255 255 / 0.25);
}

/* Animation helper classes */
.animate-drawer-up { animation: drawer-up 0.45s cubic-bezier(0.22, 1, 0.36, 1) forwards; }
.animate-fade-in { animation: fade-in 0.25s ease forwards; }
.animate-fade-up { animation: fade-up 0.35s ease forwards; }
.animate-text-in { animation: text-in 0.3s ease forwards; }
.animate-success-pop { animation: success-pop 0.5s cubic-bezier(0.34, 1.56, 0.64, 1) forwards; }
.countdown-bar { animation: countdown-drain 3s linear forwards; }

.stroke-dash-30 {
  stroke-dasharray: 30;
  stroke-dashoffset: 30;
}

.animate-check-draw {
  animation: check-draw 0.4s 0.05s ease forwards;
}

@keyframes check-draw {
  to { stroke-dashoffset: 0; }
}

@keyframes drawer-up {
  from { transform: translateY(100%); opacity: 0; }
  to { transform: translateY(0); opacity: 1; }
}

@keyframes fade-in {
  from { opacity: 0; }
  to { opacity: 1; }
}

@keyframes fade-up {
  from { opacity: 0; transform: translateY(8px); }
  to { transform: translateY(0); opacity: 1; }
}

@keyframes text-in {
  from { opacity: 0; transform: translateX(-6px); }
  to { opacity: 1; transform: translateX(0); }
}

@keyframes success-pop {
  0% { transform: scale(0.88); opacity: 0; }
  60% { transform: scale(1.04); }
  100% { transform: scale(1); opacity: 1; }
}

@keyframes ambient-pulse {
  0%, 100% { opacity: 0.3; }
  50% { opacity: 0.65; }
}

@keyframes shimmer-sweep {
  from { transform: translateX(-100%); }
  to { transform: translateX(250%); }
}

@keyframes node-glow {
  0%, 100% { box-shadow: 0 0 12px var(--glow-color,#60a5fa55); }
  50% { box-shadow: 0 0 28px var(--glow-color,#60a5fa88), 0 0 48px var(--glow-color,#60a5fa22); }
}

@keyframes glyph-rotate {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}

@keyframes ring-expand {
  from { transform: scale(1); opacity: 0.7; }
  to { transform: scale(2.1); opacity: 0; }
}

@keyframes orb-travel {
  from { left: 0%; }
  to { left: calc(100% - 10px); }
}

@keyframes particle-float {
  0% { transform: translateY(0) scale(1); opacity: 0; }
  15% { opacity: 1; }
  100% { transform: translateY(-90px) scale(0.3); opacity: 0; }
}

@keyframes bar-eq {
  from { transform: scaleY(0.4); }
  to { transform: scaleY(1); }
}

@keyframes burst-ray {
  0% { transform: rotate(var(--r, 0deg)) translateX(0); opacity: 1; }
  100% { transform: rotate(var(--r, 0deg)) translateX(56px); opacity: 0; }
}

@keyframes countdown-drain {
  from { width: 100%; }
  to { width: 0%; }
}


END_OF_FILE_CONTENT
mkdir -p "src/components/skills-grid"
echo "Creating src/components/skills-grid/View.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/skills-grid/View.tsx"
// Layout: Hero=B (BENTO GRID), Features=A (BENTO)
import React from 'react';
import { Card, CardContent } from '@/components/ui/card';
import { IconResolver } from '@/lib/IconResolver';
import type { SkillsGridData, SkillsGridSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40'
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40'
};

export const SkillsGrid: React.FC<{ data: SkillsGridData; settings: SkillsGridSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      bg: 'var(--theme-colors-background)',
      text: 'var(--theme-colors-foreground)',
      muted: 'var(--theme-colors-muted-foreground)',
      surface: 'var(--theme-colors-card)',
      border: 'var(--theme-colors-border)'
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)'
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)'
    }
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-accent': 'var(--accent)',
        '--local-border': t.border,
        '--local-surface': t.surface,
        '--local-radius-sm': 'var(--theme-radius-sm)',
        '--local-radius-md': 'var(--theme-radius-md)',
        '--local-radius-lg': 'var(--theme-radius-lg)'
      } as React.CSSProperties}
      className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}
    >
      <div className={containerClass}>
        <div className="mb-10 max-w-2xl">
          {data.label && (
            <div className="jp-section-label inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-accent)] mb-4" data-jp-field="label">
              <span className="w-5 h-px bg-[var(--local-primary)]" />
              {data.label}
            </div>
          )}
          <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">
            {data.title}
          </h2>
        </div>
        <div className="grid gap-5 md:grid-cols-2 xl:grid-cols-3">
          {data.items.map((item, idx) => {
            const Icon = IconResolver[item.icon];
            return (
              <Card
                key={item.id || 'legacy-' + idx}
                className="rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-surface)] text-[var(--local-text)]"
                data-jp-item-id={item.id || 'legacy-' + idx}
                data-jp-item-field="items"
              >
                <CardContent className="space-y-4 p-6">
                  <div className="flex items-center gap-3">
                    {Icon ? <Icon className="h-5 w-5 text-[var(--local-primary)]" /> : null}
                    <span className="jp-meta">{item.category}</span>
                  </div>
                  <h3 className="font-display font-bold text-[1.2rem] leading-tight tracking-tight text-[var(--local-text)]">{item.label}</h3>
                  <p className="text-sm text-[var(--local-text-muted)]">{item.body}</p>
                </CardContent>
              </Card>
            );
          })}
        </div>
      </div>
    </section>
  );
};

END_OF_FILE_CONTENT
echo "Creating src/components/skills-grid/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/skills-grid/index.ts"
export { SkillsGrid } from './View';
export { SkillsGridSchema } from './schema';
export type { SkillsGridData, SkillsGridSettings } from './types';

END_OF_FILE_CONTENT
echo "Creating src/components/skills-grid/schema.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/skills-grid/schema.ts"
import { z } from 'zod';
import { BaseSectionData, BaseArrayItem } from '@olonjs/core';

const SkillItemSchema = BaseArrayItem.extend({
  category: z.string().describe('ui:text'),
  label: z.string().describe('ui:text'),
  icon: z.string().describe('ui:icon-picker'),
  body: z.string().describe('ui:textarea')
});

export const SkillsGridSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  items: z.array(SkillItemSchema).describe('ui:list')
});

END_OF_FILE_CONTENT
echo "Creating src/components/skills-grid/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/skills-grid/types.ts"
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { SkillsGridSchema } from './schema';

export type SkillsGridData = z.infer<typeof SkillsGridSchema>;
export type SkillsGridSettings = z.infer<typeof BaseSectionSettingsSchema>;

END_OF_FILE_CONTENT
mkdir -p "src/components/timeline"
echo "Creating src/components/timeline/View.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/timeline/View.tsx"
// Layout: Hero=E (MAGAZINE), Features=C (TIMELINE)
import React from 'react';
import type { TimelineData, TimelineSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40'
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40'
};

export const Timeline: React.FC<{ data: TimelineData; settings: TimelineSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      bg: 'var(--theme-colors-background)',
      text: 'var(--theme-colors-foreground)',
      muted: 'var(--theme-colors-muted-foreground)',
      surface: 'var(--theme-colors-card)',
      border: 'var(--theme-colors-border)'
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)'
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)'
    }
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-accent': 'var(--accent)',
        '--local-border': t.border,
        '--local-surface': t.surface,
        '--local-radius-sm': 'var(--theme-radius-sm)',
        '--local-radius-md': 'var(--theme-radius-md)',
        '--local-radius-lg': 'var(--theme-radius-lg)'
      } as React.CSSProperties}
      className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}
    >
      <div className={containerClass}>
        <div className="mb-12 max-w-2xl">
          {data.label && (
            <div className="jp-section-label inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-accent)] mb-4" data-jp-field="label">
              <span className="w-5 h-px bg-[var(--local-primary)]" />
              {data.label}
            </div>
          )}
          <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">
            {data.title}
          </h2>
        </div>
        <div className="relative space-y-8 before:absolute before:left-[8px] before:top-1 before:h-[calc(100%-2rem)] before:w-px before:bg-[var(--local-border)]">
          {data.items.map((item, idx) => (
            <div
              key={item.id || 'legacy-' + idx}
              className="relative pl-10"
              data-jp-item-id={item.id || 'legacy-' + idx}
              data-jp-item-field="items"
            >
              <span className="absolute left-0 top-1.5 h-4 w-4 rounded-full border border-[var(--local-border)] bg-[var(--local-primary)]" />
              <div className="rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-surface)] p-6">
                <div className="jp-meta">{item.period}</div>
                <h3 className="mt-3 font-display font-bold text-[1.2rem] leading-tight tracking-tight text-[var(--local-text)]">{item.title}</h3>
                <p className="mt-1 text-sm text-[var(--local-primary)]">{item.organization}</p>
                <p className="mt-3 text-sm text-[var(--local-text-muted)]">{item.body}</p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
};

END_OF_FILE_CONTENT
echo "Creating src/components/timeline/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/timeline/index.ts"
export { Timeline } from './View';
export { TimelineSchema } from './schema';
export type { TimelineData, TimelineSettings } from './types';

END_OF_FILE_CONTENT
echo "Creating src/components/timeline/schema.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/timeline/schema.ts"
import { z } from 'zod';
import { BaseSectionData, BaseArrayItem } from '@olonjs/core';

const TimelineItemSchema = BaseArrayItem.extend({
  period: z.string().describe('ui:text'),
  title: z.string().describe('ui:text'),
  organization: z.string().describe('ui:text'),
  body: z.string().describe('ui:textarea')
});

export const TimelineSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  items: z.array(TimelineItemSchema).describe('ui:list')
});

END_OF_FILE_CONTENT
echo "Creating src/components/timeline/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/timeline/types.ts"
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { TimelineSchema } from './schema';

export type TimelineData = z.infer<typeof TimelineSchema>;
export type TimelineSettings = z.infer<typeof BaseSectionSettingsSchema>;

END_OF_FILE_CONTENT
mkdir -p "src/components/tiptap"
echo "Creating src/components/tiptap/INTEGRATION.md..."
cat << 'END_OF_FILE_CONTENT' > "src/components/tiptap/INTEGRATION.md"
# Tiptap Editorial — Integration Guide

How to add the `tiptap` section to a new tenant.

---

## 1. Copy the component

Copy the entire folder into the new tenant:

```
src/components/tiptap/
  index.ts
  types.ts
  View.tsx
```

---

## 2. Install npm dependencies

Add to the tenant's `package.json` and run `npm install`:

```json
"@tiptap/extension-image": "^2.11.5",
"@tiptap/extension-link": "^2.11.5",
"@tiptap/react": "^2.11.5",
"@tiptap/starter-kit": "^2.11.5",
"react-markdown": "^9.0.1",
"rehype-sanitize": "^6.0.0",
"remark-gfm": "^4.0.1",
"tiptap-markdown": "^0.8.10"
```

---

## 3. Add CSS to `src/index.css`

Two blocks are required — one for the public (visitor) view, one for the editor (studio) view.

```css
/* ==========================================================================
   TIPTAP — Public content typography (visitor view)
   ========================================================================== */
.jp-tiptap-content > * + * { margin-top: 0.75em; }

.jp-tiptap-content h1 { font-size: 2em;    font-weight: 700; line-height: 1.2; margin-top: 1.25em; margin-bottom: 0.25em; }
.jp-tiptap-content h2 { font-size: 1.5em;  font-weight: 700; line-height: 1.3; margin-top: 1.25em; margin-bottom: 0.25em; }
.jp-tiptap-content h3 { font-size: 1.25em; font-weight: 600; line-height: 1.4; margin-top: 1.25em; margin-bottom: 0.25em; }
.jp-tiptap-content h4 { font-size: 1em;    font-weight: 600; line-height: 1.5; margin-top: 1em;    margin-bottom: 0.25em; }

.jp-tiptap-content p  { line-height: 1.7; }
.jp-tiptap-content strong { font-weight: 700; }
.jp-tiptap-content em     { font-style: italic; }
.jp-tiptap-content s      { text-decoration: line-through; }

.jp-tiptap-content a { color: var(--primary); text-decoration: underline; text-underline-offset: 2px; }
.jp-tiptap-content a:hover { opacity: 0.8; }

.jp-tiptap-content code {
  font-family: var(--font-mono, ui-monospace, monospace);
  font-size: 0.875em;
  background: color-mix(in oklch, var(--foreground) 8%, transparent);
  border-radius: 0.25em;
  padding: 0.1em 0.35em;
}
.jp-tiptap-content pre {
  background: color-mix(in oklch, var(--background) 60%, black);
  border-radius: 0.5em;
  padding: 1em 1.25em;
  overflow-x: auto;
}
.jp-tiptap-content pre code { background: none; padding: 0; }

.jp-tiptap-content ul { list-style-type: disc;    padding-left: 1.625em; }
.jp-tiptap-content ol { list-style-type: decimal; padding-left: 1.625em; }
.jp-tiptap-content li { line-height: 1.7; margin-top: 0.25em; }
.jp-tiptap-content li + li { margin-top: 0.25em; }

.jp-tiptap-content blockquote {
  border-left: 3px solid var(--border);
  padding-left: 1em;
  color: var(--muted-foreground);
  font-style: italic;
}
.jp-tiptap-content hr { border: none; border-top: 1px solid var(--border); margin: 1.5em 0; }
.jp-tiptap-content img { max-width: 100%; height: auto; border-radius: 0.5rem; }

/* ==========================================================================
   TIPTAP / PROSEMIRROR — Editor typography (studio view)
   ========================================================================== */
.jp-simple-editor .ProseMirror { outline: none; word-break: break-word; }
.jp-simple-editor .ProseMirror > * + * { margin-top: 0.75em; }

.jp-simple-editor .ProseMirror h1 { font-size: 2em;    font-weight: 700; line-height: 1.2; margin-top: 1.25em; margin-bottom: 0.25em; }
.jp-simple-editor .ProseMirror h2 { font-size: 1.5em;  font-weight: 700; line-height: 1.3; margin-top: 1.25em; margin-bottom: 0.25em; }
.jp-simple-editor .ProseMirror h3 { font-size: 1.25em; font-weight: 600; line-height: 1.4; margin-top: 1.25em; margin-bottom: 0.25em; }
.jp-simple-editor .ProseMirror h4 { font-size: 1em;    font-weight: 600; line-height: 1.5; margin-top: 1em;    margin-bottom: 0.25em; }

.jp-simple-editor .ProseMirror p  { line-height: 1.7; }
.jp-simple-editor .ProseMirror strong { font-weight: 700; }
.jp-simple-editor .ProseMirror em     { font-style: italic; }
.jp-simple-editor .ProseMirror s      { text-decoration: line-through; }

.jp-simple-editor .ProseMirror a { color: var(--primary); text-decoration: underline; text-underline-offset: 2px; }
.jp-simple-editor .ProseMirror a:hover { opacity: 0.8; }

.jp-simple-editor .ProseMirror code {
  font-family: var(--font-mono, ui-monospace, monospace);
  font-size: 0.875em;
  background: color-mix(in oklch, var(--foreground) 8%, transparent);
  border-radius: 0.25em;
  padding: 0.1em 0.35em;
}
.jp-simple-editor .ProseMirror pre {
  background: color-mix(in oklch, var(--background) 60%, black);
  border-radius: 0.5em;
  padding: 1em 1.25em;
  overflow-x: auto;
}
.jp-simple-editor .ProseMirror pre code { background: none; padding: 0; }

.jp-simple-editor .ProseMirror ul { list-style-type: disc;    padding-left: 1.625em; }
.jp-simple-editor .ProseMirror ol { list-style-type: decimal; padding-left: 1.625em; }
.jp-simple-editor .ProseMirror li { line-height: 1.7; margin-top: 0.25em; }
.jp-simple-editor .ProseMirror li + li { margin-top: 0.25em; }

.jp-simple-editor .ProseMirror blockquote {
  border-left: 3px solid var(--border);
  padding-left: 1em;
  color: var(--muted-foreground);
  font-style: italic;
}
.jp-simple-editor .ProseMirror hr { border: none; border-top: 1px solid var(--border); margin: 1.5em 0; }

.jp-simple-editor .ProseMirror img { max-width: 100%; height: auto; border-radius: 0.5rem; }
.jp-simple-editor .ProseMirror img[data-uploading="true"] {
  opacity: 0.6;
  filter: grayscale(0.25);
  outline: 2px dashed rgb(59 130 246 / 0.7);
  outline-offset: 2px;
}
.jp-simple-editor .ProseMirror img[data-upload-error="true"] {
  outline: 2px solid rgb(239 68 68 / 0.8);
  outline-offset: 2px;
}
.jp-simple-editor .ProseMirror p.is-editor-empty:first-child::before {
  content: attr(data-placeholder);
  color: var(--muted-foreground);
  opacity: 0.5;
  pointer-events: none;
  float: left;
  height: 0;
}
```

---

## 4. Register in `src/lib/schemas.ts`

```ts
import { TiptapSchema } from '@/components/tiptap';

export const SECTION_SCHEMAS = {
  // ... existing schemas
  'tiptap': TiptapSchema,
} as const;
```

---

## 5. Register in `src/lib/addSectionConfig.ts`

```ts
const addableSectionTypes = [
  // ... existing types
  'tiptap',
] as const;

const sectionTypeLabels = {
  // ... existing labels
  'tiptap': 'Tiptap Editorial',
};

function getDefaultSectionData(type: string) {
  switch (type) {
    // ... existing cases
    case 'tiptap': return { content: '# Post title\n\nStart writing in Markdown...' };
  }
}
```

---

## 6. Register in `src/lib/ComponentRegistry.tsx`

```tsx
import { Tiptap } from '@/components/tiptap';

export const ComponentRegistry = {
  // ... existing components
  'tiptap': Tiptap,
};
```

---

## 7. Register in `src/types.ts`

```ts
import type { TiptapData, TiptapSettings } from '@/components/tiptap';

export type SectionComponentPropsMap = {
  // ... existing entries
  'tiptap': { data: TiptapData; settings?: TiptapSettings };
};

declare module '@jsonpages/core' {
  export interface SectionDataRegistry {
    // ... existing entries
    'tiptap': TiptapData;
  }
  export interface SectionSettingsRegistry {
    // ... existing entries
    'tiptap': TiptapSettings;
  }
}
```

---

## Notes

- Typography uses tenant CSS variables (`--primary`, `--border`, `--muted-foreground`, `--font-mono`) — no hardcoded colors.
- `@tailwindcss/typography` is **not** required; the CSS blocks above replace it.
- The toolbar is admin-only (studio mode). In visitor mode, content is rendered via `ReactMarkdown`.
- Underline is intentionally excluded: `tiptap-markdown` with `html: false` cannot round-trip `<u>` tags.

END_OF_FILE_CONTENT
echo "Creating src/components/tiptap/View.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/tiptap/View.tsx"
import React from 'react';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import rehypeSanitize from 'rehype-sanitize';
import { useEditor, EditorContent } from '@tiptap/react';
import type { Editor } from '@tiptap/react';
import StarterKit from '@tiptap/starter-kit';
import Link from '@tiptap/extension-link';
import Image from '@tiptap/extension-image';
import { Markdown } from 'tiptap-markdown';
import {
  Undo2, Redo2,
  List, ListOrdered,
  Bold, Italic, Strikethrough,
  Code2, Quote, SquareCode,
  Link2, Unlink2, ImagePlus, Eraser,
} from 'lucide-react';
import { STUDIO_EVENTS, useConfig, useStudio } from '@olonjs/core';
import type { TiptapData, TiptapSettings } from './types';

// ── UI primitives ─────────────────────────────────────────────────
const Btn: React.FC<{
  active?: boolean; title: string; onClick: () => void; children: React.ReactNode;
}> = ({ active = false, title, onClick, children }) => (
  <button
    type="button" title={title}
    onMouseDown={(e) => e.preventDefault()} onClick={onClick}
    className={[
      'inline-flex h-7 min-w-7 items-center justify-center rounded-md px-2 text-xs transition-colors',
      active ? 'bg-zinc-700/70 text-zinc-100' : 'text-zinc-400 hover:bg-zinc-800 hover:text-zinc-200',
    ].join(' ')}
  >{children}</button>
);

const Sep: React.FC = () => (
  <span className="mx-0.5 h-5 w-px shrink-0 bg-zinc-800" aria-hidden />
);

// ── Image extension with upload metadata ──────────────────────────
const UploadableImage = Image.extend({
  addAttributes() {
    const bool = (attr: string) => ({
      default: false,
      parseHTML: (el: HTMLElement) => el.getAttribute(attr) === 'true',
      renderHTML: (attrs: Record<string, unknown>) =>
        attrs[attr.replace('data-', '').replace(/-([a-z])/g, (_: string, c: string) => c.toUpperCase())]
          ? { [attr]: 'true' } : {},
    });
    return {
      ...this.parent?.(),
      uploadId: {
        default: null,
        parseHTML: (el: HTMLElement) => el.getAttribute('data-upload-id'),
        renderHTML: (attrs: Record<string, unknown>) =>
          attrs.uploadId ? { 'data-upload-id': String(attrs.uploadId) } : {},
      },
      uploading: bool('data-uploading'),
      uploadError: bool('data-upload-error'),
      awaitingUpload: bool('data-awaiting-upload'),
    };
  },
});

// ── Helpers ───────────────────────────────────────────────────────
const getMarkdown = (ed: Editor | null | undefined): string =>
  (ed?.storage as { markdown?: { getMarkdown?: () => string } } | undefined)
    ?.markdown?.getMarkdown?.() ?? '';

const svg = (body: string) =>
  'data:image/svg+xml;utf8,' +
  encodeURIComponent(
    '<svg xmlns=\'http://www.w3.org/2000/svg\' width=\'1200\' height=\'420\' viewBox=\'0 0 1200 420\'>' + body + '</svg>'
  );

const RECT = '<rect width=\'1200\' height=\'420\' fill=\'#090B14\' stroke=\'#3F3F46\' stroke-width=\'3\' stroke-dasharray=\'10 10\' rx=\'12\'/>';

const UPLOADING_SRC = svg(
  RECT + '<text x=\'600\' y=\'215\' font-family=\'Inter,Arial,sans-serif\' font-size=\'28\' font-weight=\'700\' fill=\'#A1A1AA\' text-anchor=\'middle\'>Uploading image\u2026</text>'
);

const PICKER_SRC = svg(
  RECT +
  '<text x=\'600\' y=\'200\' font-family=\'Inter,Arial,sans-serif\' font-size=\'32\' font-weight=\'700\' fill=\'#E4E4E7\' text-anchor=\'middle\'>Click to upload or drag &amp; drop</text>' +
  '<text x=\'600\' y=\'248\' font-family=\'Inter,Arial,sans-serif\' font-size=\'22\' fill=\'#A1A1AA\' text-anchor=\'middle\'>Max 5 MB per file</text>'
);

const patchImage = (ed: Editor, uploadId: string, patch: Record<string, unknown>): boolean => {
  let pos: number | null = null;
  ed.state.doc.descendants(
    (node: { type: { name: string }; attrs?: Record<string, unknown> }, p: number) => {
      if (node.type.name === 'image' && node.attrs?.uploadId === uploadId) { pos = p; return false; }
      return true;
    }
  );
  if (pos == null) return false;
  const cur = ed.state.doc.nodeAt(pos);
  if (!cur) return false;
  ed.view.dispatch(ed.state.tr.setNodeMarkup(pos, undefined, { ...cur.attrs, ...patch }));
  return true;
};

const EXTENSIONS = [
  StarterKit,
  Link.configure({ openOnClick: false, autolink: true }),
  UploadableImage,
  Markdown.configure({ html: false }),
];

// ── Studio editor ─────────────────────────────────────────────────
const StudioTiptapEditor: React.FC<{ data: TiptapData }> = ({ data }) => {
  const { assets } = useConfig();
  const hostRef = React.useRef<HTMLDivElement | null>(null);
  const sectionRef = React.useRef<HTMLElement | null>(null);
  const fileInputRef = React.useRef<HTMLInputElement | null>(null);
  const editorRef = React.useRef<Editor | null>(null);
  const pendingUploads = React.useRef<Map<string, Promise<void>>>(new Map());
  const pendingPickerId = React.useRef<string | null>(null);
  const latestMd = React.useRef<string>(data.content ?? '');
  const emittedMd = React.useRef<string>(data.content ?? '');
  const [linkOpen, setLinkOpen] = React.useState(false);
  const [linkUrl, setLinkUrl] = React.useState('');
  const linkInputRef = React.useRef<HTMLInputElement | null>(null);

  const getSectionId = React.useCallback((): string | null => {
    const el = sectionRef.current ?? (hostRef.current?.closest('[data-section-id]') as HTMLElement | null);
    sectionRef.current = el;
    return el?.getAttribute('data-section-id') ?? null;
  }, []);

  const emit = React.useCallback((markdown: string) => {
    latestMd.current = markdown;
    const sectionId = getSectionId();
    if (!sectionId) return;
    window.parent.postMessage({ type: STUDIO_EVENTS.INLINE_FIELD_UPDATE, sectionId, fieldKey: 'content', value: markdown }, window.location.origin);
    emittedMd.current = markdown;
  }, [getSectionId]);

  const setFocusLock = React.useCallback((on: boolean) => {
    sectionRef.current?.classList.toggle('jp-editorial-focus', on);
  }, []);

  const insertPlaceholder = React.useCallback((uploadId: string, src: string, awaitingUpload: boolean) => {
    const ed = editorRef.current;
    if (!ed) return;
    ed.chain().focus().setImage({ src, alt: 'upload-placeholder', title: awaitingUpload ? 'Click to upload' : 'Uploading\u2026', uploadId, uploading: !awaitingUpload, awaitingUpload, uploadError: false } as any).run();
    emit(getMarkdown(ed));
  }, [emit]);

  const doUpload = React.useCallback(async (uploadId: string, file: File) => {
    const uploadFn = assets?.onAssetUpload;
    if (!uploadFn) return;
    const ed = editorRef.current;
    if (!ed) return;
    patchImage(ed, uploadId, { src: UPLOADING_SRC, alt: file.name, title: file.name, uploading: true, awaitingUpload: false, uploadError: false });
    const task = (async () => {
      try {
        const url = await uploadFn(file);
        const cur = editorRef.current;
        if (cur) { patchImage(cur, uploadId, { src: url, alt: file.name, title: file.name, uploadId: null, uploading: false, awaitingUpload: false, uploadError: false }); emit(getMarkdown(cur)); }
      } catch {
        const cur = editorRef.current;
        if (cur) { patchImage(cur, uploadId, { uploading: false, awaitingUpload: false, uploadError: true }); emit(getMarkdown(cur)); }
      } finally { pendingUploads.current.delete(uploadId); }
    })();
    pendingUploads.current.set(uploadId, task);
  }, [assets, emit]);

  const uploadFile = React.useCallback(async (file: File) => {
    const id = crypto.randomUUID();
    insertPlaceholder(id, UPLOADING_SRC, false);
    await doUpload(id, file);
  }, [insertPlaceholder, doUpload]);

  const editor = useEditor({
    extensions: EXTENSIONS,
    content: data.content ?? '',
    editorProps: { attributes: { class: 'min-h-[220px] p-4 outline-none' } },
    onUpdate({ editor: ed }) { emit(getMarkdown(ed)); },
    onFocus() { setFocusLock(true); },
    onBlur() {
      setTimeout(() => {
        if (!hostRef.current?.contains(document.activeElement)) setFocusLock(false);
      }, 100);
    },
    onCreate({ editor: ed }) {
      editorRef.current = ed;
      if (data.content) ed.commands.setContent(data.content);
    },
    onDestroy() { editorRef.current = null; },
  });

  React.useEffect(() => {
    if (!editor || !data.content || data.content === latestMd.current) return;
    latestMd.current = data.content;
    emittedMd.current = data.content;
    editor.commands.setContent(data.content);
  }, [editor, data.content]);

  React.useEffect(() => {
    const host = hostRef.current;
    if (!host) return;
    const onDrop = (e: DragEvent) => {
      e.preventDefault();
      const files = Array.from(e.dataTransfer?.files ?? []).filter(f => f.type.startsWith('image/'));
      files.forEach(f => void uploadFile(f));
    };
    const onPaste = (e: ClipboardEvent) => {
      const files = Array.from(e.clipboardData?.files ?? []).filter(f => f.type.startsWith('image/'));
      if (!files.length) return;
      e.preventDefault();
      files.forEach(f => void uploadFile(f));
    };
    host.addEventListener('drop', onDrop);
    host.addEventListener('paste', onPaste);
    return () => { host.removeEventListener('drop', onDrop); host.removeEventListener('paste', onPaste); };
  }, [uploadFile]);

  const openLink = () => {
    const existing = editor?.getAttributes('link').href ?? '';
    setLinkUrl(existing);
    setLinkOpen(true);
    setTimeout(() => linkInputRef.current?.focus(), 50);
  };

  const applyLink = () => {
    if (!editor) return;
    const url = linkUrl.trim();
    if (url) editor.chain().focus().setLink({ href: url }).run();
    else editor.chain().focus().unsetLink().run();
    setLinkOpen(false);
  };

  const onFileSelected = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    e.target.value = '';
    if (!file) return;
    const pickId = pendingPickerId.current;
    void (async () => {
      try {
        if (pickId) { await doUpload(pickId, file); pendingPickerId.current = null; }
        else { await uploadFile(file); }
      } catch { pendingPickerId.current = null; }
    })();
  };

  const onPickImage = () => {
    if (pendingPickerId.current) return;
    const id = crypto.randomUUID();
    pendingPickerId.current = id;
    insertPlaceholder(id, PICKER_SRC, true);
  };

  const isActive = (name: string, attrs?: Record<string, unknown>) => editor?.isActive(name, attrs) ?? false;

  return (
    <div ref={hostRef} data-jp-field="content" className="space-y-2">
      {editor && (
        <div data-jp-ignore-select="true" className="sticky top-0 z-[65] border-b border-zinc-800 bg-zinc-950">
          <div className="flex flex-wrap items-center justify-center gap-1 p-2">
            <Btn title="Undo" onClick={() => editor.chain().focus().undo().run()}><Undo2 size={13} /></Btn>
            <Btn title="Redo" onClick={() => editor.chain().focus().redo().run()}><Redo2 size={13} /></Btn>
            <Sep />
            <Btn active={isActive('paragraph')} title="Paragraph" onClick={() => editor.chain().focus().setParagraph().run()}>P</Btn>
            <Btn active={isActive('heading', { level: 1 })} title="Heading 1" onClick={() => editor.chain().focus().toggleHeading({ level: 1 }).run()}>H1</Btn>
            <Btn active={isActive('heading', { level: 2 })} title="Heading 2" onClick={() => editor.chain().focus().toggleHeading({ level: 2 }).run()}>H2</Btn>
            <Btn active={isActive('heading', { level: 3 })} title="Heading 3" onClick={() => editor.chain().focus().toggleHeading({ level: 3 }).run()}>H3</Btn>
            <Sep />
            <Btn active={isActive('bold')} title="Bold (Ctrl+B)" onClick={() => editor.chain().focus().toggleBold().run()}><Bold size={13} /></Btn>
            <Btn active={isActive('italic')} title="Italic (Ctrl+I)" onClick={() => editor.chain().focus().toggleItalic().run()}><Italic size={13} /></Btn>
            <Btn active={isActive('strike')} title="Strikethrough" onClick={() => editor.chain().focus().toggleStrike().run()}><Strikethrough size={13} /></Btn>
            <Btn active={isActive('code')} title="Inline code" onClick={() => editor.chain().focus().toggleCode().run()}><Code2 size={13} /></Btn>
            <Sep />
            <Btn active={isActive('bulletList')} title="Bullet list" onClick={() => editor.chain().focus().toggleBulletList().run()}><List size={13} /></Btn>
            <Btn active={isActive('orderedList')} title="Ordered list" onClick={() => editor.chain().focus().toggleOrderedList().run()}><ListOrdered size={13} /></Btn>
            <Btn active={isActive('blockquote')} title="Blockquote" onClick={() => editor.chain().focus().toggleBlockquote().run()}><Quote size={13} /></Btn>
            <Btn active={isActive('codeBlock')} title="Code block" onClick={() => editor.chain().focus().toggleCodeBlock().run()}><SquareCode size={13} /></Btn>
            <Sep />
            <Btn active={isActive('link') || linkOpen} title="Set link" onClick={openLink}><Link2 size={13} /></Btn>
            <Btn title="Remove link" onClick={() => editor.chain().focus().unsetLink().run()}><Unlink2 size={13} /></Btn>
            <Btn title="Insert image" onClick={onPickImage}><ImagePlus size={13} /></Btn>
            <Btn title="Clear formatting" onClick={() => editor.chain().focus().unsetAllMarks().clearNodes().run()}><Eraser size={13} /></Btn>
          </div>
          {linkOpen && (
            <div className="flex items-center gap-2 border-t border-zinc-700 px-2 py-1.5">
              <Link2 size={12} className="shrink-0 text-zinc-500" />
              <input ref={linkInputRef} type="url" value={linkUrl} onChange={(e) => setLinkUrl(e.target.value)}
                onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); applyLink(); } if (e.key === 'Escape') setLinkOpen(false); }}
                placeholder="https://example.com"
                className="min-w-0 flex-1 bg-transparent text-xs text-zinc-100 placeholder:text-zinc-500 outline-none" />
              <button type="button" onMouseDown={(e) => e.preventDefault()} onClick={applyLink} className="shrink-0 rounded px-2 py-0.5 text-xs bg-blue-600 hover:bg-blue-500 text-white transition-colors">Set</button>
              <button type="button" onMouseDown={(e) => e.preventDefault()} onClick={() => setLinkOpen(false)} className="shrink-0 rounded px-2 py-0.5 text-xs bg-zinc-700 hover:bg-zinc-600 text-zinc-200 transition-colors">Cancel</button>
            </div>
          )}
        </div>
      )}
      <EditorContent editor={editor} className="jp-simple-editor" />
      <input ref={fileInputRef} type="file" accept="image/*" className="hidden" onChange={onFileSelected} />
    </div>
  );
};

// ── Public view ───────────────────────────────────────────────────
const PublicTiptapContent: React.FC<{ content: string }> = ({ content }) => (
  <article className="jp-tiptap-content" data-jp-field="content">
    <ReactMarkdown remarkPlugins={[remarkGfm]} rehypePlugins={[rehypeSanitize]}>
      {content}
    </ReactMarkdown>
  </article>
);

// ── Export ────────────────────────────────────────────────────────
export const Tiptap: React.FC<{ data: TiptapData; settings?: TiptapSettings }> = ({ data }) => {
  const { mode } = useStudio();
  return (
    <section
      style={{ '--local-bg': 'var(--background)', '--local-text': 'var(--foreground)' } as React.CSSProperties}
      className="relative z-0 w-full py-12 bg-[var(--local-bg)]"
    >
      <div className="max-w-3xl mx-auto px-6">
        {mode === 'studio' ? (
          <StudioTiptapEditor data={data} />
        ) : (
          <PublicTiptapContent content={data.content ?? ''} />
        )}
      </div>
    </section>
  );
};

END_OF_FILE_CONTENT
echo "Creating src/components/tiptap/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/tiptap/index.ts"
export * from './View';
export * from './schema';
export * from './types';

END_OF_FILE_CONTENT
echo "Creating src/components/tiptap/schema.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/tiptap/schema.ts"
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';

export const TiptapSchema = BaseSectionData.extend({
  content: z.string().default('').describe('ui:editorial-markdown'),
});

export const TiptapSettingsSchema = z.object({});

END_OF_FILE_CONTENT
echo "Creating src/components/tiptap/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/tiptap/types.ts"
import { z } from 'zod';
import { TiptapSchema, TiptapSettingsSchema } from './schema';

export type TiptapData     = z.infer<typeof TiptapSchema>;
export type TiptapSettings = z.infer<typeof TiptapSettingsSchema>;

END_OF_FILE_CONTENT
mkdir -p "src/components/ui"
echo "Creating src/components/ui/OlonMark.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/OlonMark.tsx"
import { cn } from '@olonjs/core'

interface OlonMarkProps {
  size?: number
  /** mono: uses currentColor — for single-colour print/emboss contexts */
  variant?: 'default' | 'mono'
  className?: string
}

export function OlonMark({ size = 32, variant = 'default', className }: OlonMarkProps) {
  const gid = `olon-ring-${size}`

  if (variant === 'mono') {
    return (
      <svg
        viewBox="0 0 100 100"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
        width={size}
        height={size}
        aria-label="Olon mark"
        className={cn('flex-shrink-0', className)}
      >
        <circle cx="50" cy="50" r="38" stroke="currentColor" strokeWidth="20"/>
        <circle cx="50" cy="50" r="15" fill="currentColor"/>
      </svg>
    )
  }

  return (
    <svg
      viewBox="0 0 100 100"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      width={size}
      height={size}
      aria-label="Olon mark"
      className={cn('flex-shrink-0', className)}
    >
      <defs>
        <linearGradient id={gid} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%"   stopColor="var(--olon-ring-top)"/>
          <stop offset="100%" stopColor="var(--olon-ring-bottom)"/>
        </linearGradient>
      </defs>
      <circle cx="50" cy="50" r="38" stroke={`url(#${gid})`} strokeWidth="20"/>
      <circle cx="50" cy="50" r="15" fill="var(--olon-nucleus)"/>
    </svg>
  )
}

interface OlonLogoProps {
  markSize?: number
  fontSize?: number
  variant?: 'default' | 'mono'
  className?: string
}

export function OlonLogo({
  markSize = 32,
  fontSize = 24,
  variant = 'default',
  className,
}: OlonLogoProps) {
  return (
    <div className={cn('flex items-center gap-3', className)}>
      <OlonMark size={markSize} variant={variant}/>
      <span
        style={{
          fontFamily: "'Instrument Sans', Helvetica, Arial, sans-serif",
          fontWeight: 700,
          fontSize,
          letterSpacing: '-0.02em',
          color: 'hsl(var(--foreground))',
          lineHeight: 1,
        }}
      >
        Olon
      </span>
    </div>
  )
}

END_OF_FILE_CONTENT
echo "Creating src/components/ui/accordion.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/accordion.tsx"
import * as React from "react"
import { Accordion as AccordionPrimitive } from "radix-ui"

import { cn } from "@/lib/utils"
import { ChevronDownIcon, ChevronUpIcon } from "lucide-react"

function Accordion({
  className,
  ...props
}: React.ComponentProps<typeof AccordionPrimitive.Root>) {
  return (
    <AccordionPrimitive.Root
      data-slot="accordion"
      className={cn("flex w-full flex-col", className)}
      {...props}
    />
  )
}

function AccordionItem({
  className,
  ...props
}: React.ComponentProps<typeof AccordionPrimitive.Item>) {
  return (
    <AccordionPrimitive.Item
      data-slot="accordion-item"
      className={cn("not-last:border-b", className)}
      {...props}
    />
  )
}

function AccordionTrigger({
  className,
  children,
  ...props
}: React.ComponentProps<typeof AccordionPrimitive.Trigger>) {
  return (
    <AccordionPrimitive.Header className="flex">
      <AccordionPrimitive.Trigger
        data-slot="accordion-trigger"
        className={cn(
          "group/accordion-trigger relative flex flex-1 items-start justify-between rounded-lg border border-transparent py-2.5 text-left text-sm font-medium transition-all outline-none hover:underline focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50 focus-visible:after:border-ring disabled:pointer-events-none disabled:opacity-50 **:data-[slot=accordion-trigger-icon]:ml-auto **:data-[slot=accordion-trigger-icon]:size-4 **:data-[slot=accordion-trigger-icon]:text-muted-foreground",
          className
        )}
        {...props}
      >
        {children}
        <ChevronDownIcon data-slot="accordion-trigger-icon" className="pointer-events-none shrink-0 group-aria-expanded/accordion-trigger:hidden" />
        <ChevronUpIcon data-slot="accordion-trigger-icon" className="pointer-events-none hidden shrink-0 group-aria-expanded/accordion-trigger:inline" />
      </AccordionPrimitive.Trigger>
    </AccordionPrimitive.Header>
  )
}

function AccordionContent({
  className,
  children,
  ...props
}: React.ComponentProps<typeof AccordionPrimitive.Content>) {
  return (
    <AccordionPrimitive.Content
      data-slot="accordion-content"
      className="overflow-hidden text-sm data-open:animate-accordion-down data-closed:animate-accordion-up"
      {...props}
    >
      <div
        className={cn(
          "h-(--radix-accordion-content-height) pt-0 pb-2.5 [&_a]:underline [&_a]:underline-offset-3 [&_a]:hover:text-foreground [&_p:not(:last-child)]:mb-4",
          className
        )}
      >
        {children}
      </div>
    </AccordionPrimitive.Content>
  )
}

export { Accordion, AccordionItem, AccordionTrigger, AccordionContent }

END_OF_FILE_CONTENT
echo "Creating src/components/ui/aspect-ratio.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/aspect-ratio.tsx"
"use client"

import { AspectRatio as AspectRatioPrimitive } from "radix-ui"

function AspectRatio({
  ...props
}: React.ComponentProps<typeof AspectRatioPrimitive.Root>) {
  return <AspectRatioPrimitive.Root data-slot="aspect-ratio" {...props} />
}

export { AspectRatio }


END_OF_FILE_CONTENT
echo "Creating src/components/ui/avatar.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/avatar.tsx"
"use client"

import * as React from "react"
import { Avatar as AvatarPrimitive } from "radix-ui"

import { cn } from "@/lib/utils"

function Avatar({
  className,
  size = "default",
  ...props
}: React.ComponentProps<typeof AvatarPrimitive.Root> & {
  size?: "default" | "sm" | "lg"
}) {
  return (
    <AvatarPrimitive.Root
      data-slot="avatar"
      data-size={size}
      className={cn(
        "group/avatar relative flex size-8 shrink-0 rounded-full select-none after:absolute after:inset-0 after:rounded-full after:border after:border-border after:mix-blend-darken data-[size=lg]:size-10 data-[size=sm]:size-6 dark:after:mix-blend-lighten",
        className
      )}
      {...props}
    />
  )
}

function AvatarImage({
  className,
  ...props
}: React.ComponentProps<typeof AvatarPrimitive.Image>) {
  return (
    <AvatarPrimitive.Image
      data-slot="avatar-image"
      className={cn(
        "aspect-square size-full rounded-full object-cover",
        className
      )}
      {...props}
    />
  )
}

function AvatarFallback({
  className,
  ...props
}: React.ComponentProps<typeof AvatarPrimitive.Fallback>) {
  return (
    <AvatarPrimitive.Fallback
      data-slot="avatar-fallback"
      className={cn(
        "flex size-full items-center justify-center rounded-full bg-muted text-sm text-muted-foreground group-data-[size=sm]/avatar:text-xs",
        className
      )}
      {...props}
    />
  )
}

function AvatarBadge({ className, ...props }: React.ComponentProps<"span">) {
  return (
    <span
      data-slot="avatar-badge"
      className={cn(
        "absolute right-0 bottom-0 z-10 inline-flex items-center justify-center rounded-full bg-primary text-primary-foreground bg-blend-color ring-2 ring-background select-none",
        "group-data-[size=sm]/avatar:size-2 group-data-[size=sm]/avatar:[&>svg]:hidden",
        "group-data-[size=default]/avatar:size-2.5 group-data-[size=default]/avatar:[&>svg]:size-2",
        "group-data-[size=lg]/avatar:size-3 group-data-[size=lg]/avatar:[&>svg]:size-2",
        className
      )}
      {...props}
    />
  )
}

function AvatarGroup({ className, ...props }: React.ComponentProps<"div">) {
  return (
    <div
      data-slot="avatar-group"
      className={cn(
        "group/avatar-group flex -space-x-2 *:data-[slot=avatar]:ring-2 *:data-[slot=avatar]:ring-background",
        className
      )}
      {...props}
    />
  )
}

function AvatarGroupCount({
  className,
  ...props
}: React.ComponentProps<"div">) {
  return (
    <div
      data-slot="avatar-group-count"
      className={cn(
        "relative flex size-8 shrink-0 items-center justify-center rounded-full bg-muted text-sm text-muted-foreground ring-2 ring-background group-has-data-[size=lg]/avatar-group:size-10 group-has-data-[size=sm]/avatar-group:size-6 [&>svg]:size-4 group-has-data-[size=lg]/avatar-group:[&>svg]:size-5 group-has-data-[size=sm]/avatar-group:[&>svg]:size-3",
        className
      )}
      {...props}
    />
  )
}

export {
  Avatar,
  AvatarImage,
  AvatarFallback,
  AvatarGroup,
  AvatarGroupCount,
  AvatarBadge,
}

END_OF_FILE_CONTENT
echo "Creating src/components/ui/badge.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/badge.tsx"
import * as React from "react"
import { cva, type VariantProps } from "class-variance-authority"
import { Slot } from "radix-ui"

import { cn } from "@/lib/utils"

const badgeVariants = cva(
  "group/badge inline-flex h-5 w-fit shrink-0 items-center justify-center gap-1 overflow-hidden rounded-4xl border border-transparent px-2 py-0.5 text-xs font-medium whitespace-nowrap transition-all focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 aria-invalid:border-destructive aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 [&>svg]:pointer-events-none [&>svg]:size-3!",
  {
    variants: {
      variant: {
        default: "bg-primary text-primary-foreground [a]:hover:bg-primary/80",
        secondary:
          "bg-secondary text-secondary-foreground [a]:hover:bg-secondary/80",
        destructive:
          "bg-destructive/10 text-destructive focus-visible:ring-destructive/20 dark:bg-destructive/20 dark:focus-visible:ring-destructive/40 [a]:hover:bg-destructive/20",
        outline:
          "border-border text-foreground [a]:hover:bg-muted [a]:hover:text-muted-foreground",
        ghost:
          "hover:bg-muted hover:text-muted-foreground dark:hover:bg-muted/50",
        link: "text-primary underline-offset-4 hover:underline",
      },
    },
    defaultVariants: {
      variant: "default",
    },
  }
)

function Badge({
  className,
  variant = "default",
  asChild = false,
  ...props
}: React.ComponentProps<"span"> &
  VariantProps<typeof badgeVariants> & { asChild?: boolean }) {
  const Comp = asChild ? Slot.Root : "span"

  return (
    <Comp
      data-slot="badge"
      data-variant={variant}
      className={cn(badgeVariants({ variant }), className)}
      {...props}
    />
  )
}

export { Badge, badgeVariants }

END_OF_FILE_CONTENT
echo "Creating src/components/ui/breadcrumb.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/breadcrumb.tsx"
import * as React from "react"
import { Slot } from "radix-ui"

import { cn } from "@/lib/utils"
import { ChevronRightIcon, MoreHorizontalIcon } from "lucide-react"

function Breadcrumb({ className, ...props }: React.ComponentProps<"nav">) {
  return (
    <nav
      aria-label="breadcrumb"
      data-slot="breadcrumb"
      className={cn(className)}
      {...props}
    />
  )
}

function BreadcrumbList({ className, ...props }: React.ComponentProps<"ol">) {
  return (
    <ol
      data-slot="breadcrumb-list"
      className={cn(
        "flex flex-wrap items-center gap-1.5 text-sm wrap-break-word text-muted-foreground",
        className
      )}
      {...props}
    />
  )
}

function BreadcrumbItem({ className, ...props }: React.ComponentProps<"li">) {
  return (
    <li
      data-slot="breadcrumb-item"
      className={cn("inline-flex items-center gap-1", className)}
      {...props}
    />
  )
}

function BreadcrumbLink({
  asChild,
  className,
  ...props
}: React.ComponentProps<"a"> & {
  asChild?: boolean
}) {
  const Comp = asChild ? Slot.Root : "a"

  return (
    <Comp
      data-slot="breadcrumb-link"
      className={cn("transition-colors hover:text-foreground", className)}
      {...props}
    />
  )
}

function BreadcrumbPage({ className, ...props }: React.ComponentProps<"span">) {
  return (
    <span
      data-slot="breadcrumb-page"
      role="link"
      aria-disabled="true"
      aria-current="page"
      className={cn("font-normal text-foreground", className)}
      {...props}
    />
  )
}

function BreadcrumbSeparator({
  children,
  className,
  ...props
}: React.ComponentProps<"li">) {
  return (
    <li
      data-slot="breadcrumb-separator"
      role="presentation"
      aria-hidden="true"
      className={cn("[&>svg]:size-3.5", className)}
      {...props}
    >
      {children ?? (
        <ChevronRightIcon />
      )}
    </li>
  )
}

function BreadcrumbEllipsis({
  className,
  ...props
}: React.ComponentProps<"span">) {
  return (
    <span
      data-slot="breadcrumb-ellipsis"
      role="presentation"
      aria-hidden="true"
      className={cn(
        "flex size-5 items-center justify-center [&>svg]:size-4",
        className
      )}
      {...props}
    >
      <MoreHorizontalIcon
      />
      <span className="sr-only">More</span>
    </span>
  )
}

export {
  Breadcrumb,
  BreadcrumbList,
  BreadcrumbItem,
  BreadcrumbLink,
  BreadcrumbPage,
  BreadcrumbSeparator,
  BreadcrumbEllipsis,
}

END_OF_FILE_CONTENT
echo "Creating src/components/ui/button.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/button.tsx"
import * as React from "react"
import { cva, type VariantProps } from "class-variance-authority"
import { Slot } from "radix-ui"

import { cn } from "@/lib/utils"

const buttonVariants = cva(
  "group/button inline-flex shrink-0 items-center justify-center rounded-lg border border-transparent bg-clip-padding text-sm font-medium whitespace-nowrap transition-all outline-none select-none focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50 active:not-aria-[haspopup]:translate-y-px disabled:pointer-events-none disabled:opacity-50 aria-invalid:border-destructive aria-invalid:ring-3 aria-invalid:ring-destructive/20 dark:aria-invalid:border-destructive/50 dark:aria-invalid:ring-destructive/40 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4",
  {
    variants: {
      variant: {
        default: "bg-primary text-primary-foreground hover:bg-primary/80",
        outline:
          "border-border bg-background hover:bg-muted hover:text-foreground aria-expanded:bg-muted aria-expanded:text-foreground dark:border-input dark:bg-input/30 dark:hover:bg-input/50",
        secondary:
          "bg-secondary text-secondary-foreground hover:bg-[color-mix(in_oklch,var(--secondary),var(--foreground)_5%)] aria-expanded:bg-secondary aria-expanded:text-secondary-foreground",
        ghost:
          "hover:bg-muted hover:text-foreground aria-expanded:bg-muted aria-expanded:text-foreground dark:hover:bg-muted/50",
        destructive:
          "bg-destructive/10 text-destructive hover:bg-destructive/20 focus-visible:border-destructive/40 focus-visible:ring-destructive/20 dark:bg-destructive/20 dark:hover:bg-destructive/30 dark:focus-visible:ring-destructive/40",
        link: "text-primary underline-offset-4 hover:underline",
      },
      size: {
        default:
          "h-8 gap-1.5 px-2.5 has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2",
        xs: "h-6 gap-1 rounded-[min(var(--radius-md),10px)] px-2 text-xs in-data-[slot=button-group]:rounded-lg has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 [&_svg:not([class*='size-'])]:size-3",
        sm: "h-7 gap-1 rounded-[min(var(--radius-md),12px)] px-2.5 text-[0.8rem] in-data-[slot=button-group]:rounded-lg has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 [&_svg:not([class*='size-'])]:size-3.5",
        lg: "h-9 gap-1.5 px-2.5 has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2",
        icon: "size-8",
        "icon-xs":
          "size-6 rounded-[min(var(--radius-md),10px)] in-data-[slot=button-group]:rounded-lg [&_svg:not([class*='size-'])]:size-3",
        "icon-sm":
          "size-7 rounded-[min(var(--radius-md),12px)] in-data-[slot=button-group]:rounded-lg",
        "icon-lg": "size-9",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  }
)

function Button({
  className,
  variant = "default",
  size = "default",
  asChild = false,
  ...props
}: React.ComponentProps<"button"> &
  VariantProps<typeof buttonVariants> & {
    asChild?: boolean
  }) {
  const Comp = asChild ? Slot.Root : "button"

  return (
    <Comp
      data-slot="button"
      data-variant={variant}
      data-size={size}
      className={cn(buttonVariants({ variant, size, className }))}
      {...props}
    />
  )
}

export { Button, buttonVariants }

END_OF_FILE_CONTENT
echo "Creating src/components/ui/card.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/card.tsx"
import * as React from "react"

import { cn } from "@/lib/utils"

function Card({
  className,
  size = "default",
  ...props
}: React.ComponentProps<"div"> & { size?: "default" | "sm" }) {
  return (
    <div
      data-slot="card"
      data-size={size}
      className={cn(
        "group/card flex flex-col gap-(--card-spacing) overflow-hidden rounded-xl bg-card py-(--card-spacing) text-sm text-card-foreground ring-1 ring-foreground/10 [--card-spacing:--spacing(4)] has-data-[slot=card-footer]:pb-0 has-[>img:first-child]:pt-0 data-[size=sm]:[--card-spacing:--spacing(3)] data-[size=sm]:has-data-[slot=card-footer]:pb-0 *:[img:first-child]:rounded-t-xl *:[img:last-child]:rounded-b-xl",
        className
      )}
      {...props}
    />
  )
}

function CardHeader({ className, ...props }: React.ComponentProps<"div">) {
  return (
    <div
      data-slot="card-header"
      className={cn(
        "group/card-header @container/card-header grid auto-rows-min items-start gap-1 rounded-t-xl px-(--card-spacing) has-data-[slot=card-action]:grid-cols-[1fr_auto] has-data-[slot=card-description]:grid-rows-[auto_auto] [.border-b]:pb-(--card-spacing)",
        className
      )}
      {...props}
    />
  )
}

function CardTitle({ className, ...props }: React.ComponentProps<"div">) {
  return (
    <div
      data-slot="card-title"
      className={cn(
        "text-base leading-snug font-medium group-data-[size=sm]/card:text-sm",
        className
      )}
      {...props}
    />
  )
}

function CardDescription({ className, ...props }: React.ComponentProps<"div">) {
  return (
    <div
      data-slot="card-description"
      className={cn("text-sm text-muted-foreground", className)}
      {...props}
    />
  )
}

function CardAction({ className, ...props }: React.ComponentProps<"div">) {
  return (
    <div
      data-slot="card-action"
      className={cn(
        "col-start-2 row-span-2 row-start-1 self-start justify-self-end",
        className
      )}
      {...props}
    />
  )
}

function CardContent({ className, ...props }: React.ComponentProps<"div">) {
  return (
    <div
      data-slot="card-content"
      className={cn("px-(--card-spacing)", className)}
      {...props}
    />
  )
}

function CardFooter({ className, ...props }: React.ComponentProps<"div">) {
  return (
    <div
      data-slot="card-footer"
      className={cn(
        "flex items-center rounded-b-xl border-t bg-muted/50 p-(--card-spacing)",
        className
      )}
      {...props}
    />
  )
}

export {
  Card,
  CardHeader,
  CardFooter,
  CardTitle,
  CardAction,
  CardDescription,
  CardContent,
}

END_OF_FILE_CONTENT
echo "Creating src/components/ui/checkbox.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/checkbox.tsx"
"use client"

import * as React from "react"
import { Checkbox as CheckboxPrimitive } from "radix-ui"

import { cn } from "@/lib/utils"
import { CheckIcon } from "lucide-react"

function Checkbox({
  className,
  ...props
}: React.ComponentProps<typeof CheckboxPrimitive.Root>) {
  return (
    <CheckboxPrimitive.Root
      data-slot="checkbox"
      className={cn(
        "peer relative flex size-4 shrink-0 items-center justify-center rounded-[4px] border border-input transition-colors outline-none group-has-disabled/field:opacity-50 after:absolute after:-inset-x-3 after:-inset-y-2 focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50 disabled:cursor-not-allowed disabled:opacity-50 aria-invalid:border-destructive aria-invalid:ring-3 aria-invalid:ring-destructive/20 aria-invalid:aria-checked:border-primary dark:bg-input/30 dark:aria-invalid:border-destructive/50 dark:aria-invalid:ring-destructive/40 data-checked:border-primary data-checked:bg-primary data-checked:text-primary-foreground dark:data-checked:bg-primary",
        className
      )}
      {...props}
    >
      <CheckboxPrimitive.Indicator
        data-slot="checkbox-indicator"
        className="grid place-content-center text-current transition-none [&>svg]:size-3.5"
      >
        <CheckIcon
        />
      </CheckboxPrimitive.Indicator>
    </CheckboxPrimitive.Root>
  )
}

export { Checkbox }

END_OF_FILE_CONTENT
echo "Creating src/components/ui/dialog.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/dialog.tsx"
import * as React from "react"
import { Dialog as DialogPrimitive } from "radix-ui"

import { cn } from "@/lib/utils"
import { Button } from "@/components/ui/button"
import { XIcon } from "lucide-react"

function Dialog({
  ...props
}: React.ComponentProps<typeof DialogPrimitive.Root>) {
  return <DialogPrimitive.Root data-slot="dialog" {...props} />
}

function DialogTrigger({
  ...props
}: React.ComponentProps<typeof DialogPrimitive.Trigger>) {
  return <DialogPrimitive.Trigger data-slot="dialog-trigger" {...props} />
}

function DialogPortal({
  ...props
}: React.ComponentProps<typeof DialogPrimitive.Portal>) {
  return <DialogPrimitive.Portal data-slot="dialog-portal" {...props} />
}

function DialogClose({
  ...props
}: React.ComponentProps<typeof DialogPrimitive.Close>) {
  return <DialogPrimitive.Close data-slot="dialog-close" {...props} />
}

function DialogOverlay({
  className,
  ...props
}: React.ComponentProps<typeof DialogPrimitive.Overlay>) {
  return (
    <DialogPrimitive.Overlay
      data-slot="dialog-overlay"
      className={cn(
        "fixed inset-0 isolate z-50 bg-black/10 duration-100 supports-backdrop-filter:backdrop-blur-xs data-open:animate-in data-open:fade-in-0 data-closed:animate-out data-closed:fade-out-0",
        className
      )}
      {...props}
    />
  )
}

function DialogContent({
  className,
  children,
  showCloseButton = true,
  ...props
}: React.ComponentProps<typeof DialogPrimitive.Content> & {
  showCloseButton?: boolean
}) {
  return (
    <DialogPortal>
      <DialogOverlay />
      <DialogPrimitive.Content
        data-slot="dialog-content"
        className={cn(
          "fixed top-1/2 left-1/2 z-50 grid w-full max-w-[calc(100%-2rem)] -translate-x-1/2 -translate-y-1/2 gap-4 rounded-xl bg-popover p-4 text-sm text-popover-foreground ring-1 ring-foreground/10 duration-100 outline-none sm:max-w-sm data-open:animate-in data-open:fade-in-0 data-open:zoom-in-95 data-closed:animate-out data-closed:fade-out-0 data-closed:zoom-out-95",
          className
        )}
        {...props}
      >
        {children}
        {showCloseButton && (
          <DialogPrimitive.Close data-slot="dialog-close" asChild>
            <Button
              variant="ghost"
              className="absolute top-2 right-2"
              size="icon-sm"
            >
              <XIcon
              />
              <span className="sr-only">Close</span>
            </Button>
          </DialogPrimitive.Close>
        )}
      </DialogPrimitive.Content>
    </DialogPortal>
  )
}

function DialogHeader({ className, ...props }: React.ComponentProps<"div">) {
  return (
    <div
      data-slot="dialog-header"
      className={cn("flex flex-col gap-2", className)}
      {...props}
    />
  )
}

function DialogFooter({
  className,
  showCloseButton = false,
  children,
  ...props
}: React.ComponentProps<"div"> & {
  showCloseButton?: boolean
}) {
  return (
    <div
      data-slot="dialog-footer"
      className={cn(
        "-mx-4 -mb-4 flex flex-col-reverse gap-2 rounded-b-xl border-t bg-muted/50 p-4 sm:flex-row sm:justify-end",
        className
      )}
      {...props}
    >
      {children}
      {showCloseButton && (
        <DialogPrimitive.Close asChild>
          <Button variant="outline">Close</Button>
        </DialogPrimitive.Close>
      )}
    </div>
  )
}

function DialogTitle({
  className,
  ...props
}: React.ComponentProps<typeof DialogPrimitive.Title>) {
  return (
    <DialogPrimitive.Title
      data-slot="dialog-title"
      className={cn(
        "text-base leading-none font-medium",
        className
      )}
      {...props}
    />
  )
}

function DialogDescription({
  className,
  ...props
}: React.ComponentProps<typeof DialogPrimitive.Description>) {
  return (
    <DialogPrimitive.Description
      data-slot="dialog-description"
      className={cn(
        "text-sm text-muted-foreground *:[a]:underline *:[a]:underline-offset-3 *:[a]:hover:text-foreground",
        className
      )}
      {...props}
    />
  )
}

export {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogOverlay,
  DialogPortal,
  DialogTitle,
  DialogTrigger,
}

END_OF_FILE_CONTENT
echo "Creating src/components/ui/dropdown-menu.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/dropdown-menu.tsx"
import * as React from "react"
import { DropdownMenu as DropdownMenuPrimitive } from "radix-ui"

import { cn } from "@/lib/utils"
import { CheckIcon, ChevronRightIcon } from "lucide-react"

function DropdownMenu({
  ...props
}: React.ComponentProps<typeof DropdownMenuPrimitive.Root>) {
  return <DropdownMenuPrimitive.Root data-slot="dropdown-menu" {...props} />
}

function DropdownMenuPortal({
  ...props
}: React.ComponentProps<typeof DropdownMenuPrimitive.Portal>) {
  return (
    <DropdownMenuPrimitive.Portal data-slot="dropdown-menu-portal" {...props} />
  )
}

function DropdownMenuTrigger({
  ...props
}: React.ComponentProps<typeof DropdownMenuPrimitive.Trigger>) {
  return (
    <DropdownMenuPrimitive.Trigger
      data-slot="dropdown-menu-trigger"
      {...props}
    />
  )
}

function DropdownMenuContent({
  className,
  align = "start",
  sideOffset = 4,
  ...props
}: React.ComponentProps<typeof DropdownMenuPrimitive.Content>) {
  return (
    <DropdownMenuPrimitive.Portal>
      <DropdownMenuPrimitive.Content
        data-slot="dropdown-menu-content"
        sideOffset={sideOffset}
        align={align}
        className={cn("z-50 max-h-(--radix-dropdown-menu-content-available-height) w-(--radix-dropdown-menu-trigger-width) min-w-32 origin-(--radix-dropdown-menu-content-transform-origin) overflow-x-hidden overflow-y-auto rounded-lg bg-popover p-1 text-popover-foreground shadow-md ring-1 ring-foreground/10 duration-100 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 data-[state=closed]:overflow-hidden data-open:animate-in data-open:fade-in-0 data-open:zoom-in-95 data-closed:animate-out data-closed:fade-out-0 data-closed:zoom-out-95", className )}
        {...props}
      />
    </DropdownMenuPrimitive.Portal>
  )
}

function DropdownMenuGroup({
  ...props
}: React.ComponentProps<typeof DropdownMenuPrimitive.Group>) {
  return (
    <DropdownMenuPrimitive.Group data-slot="dropdown-menu-group" {...props} />
  )
}

function DropdownMenuItem({
  className,
  inset,
  variant = "default",
  ...props
}: React.ComponentProps<typeof DropdownMenuPrimitive.Item> & {
  inset?: boolean
  variant?: "default" | "destructive"
}) {
  return (
    <DropdownMenuPrimitive.Item
      data-slot="dropdown-menu-item"
      data-inset={inset}
      data-variant={variant}
      className={cn(
        "group/dropdown-menu-item relative flex cursor-default items-center gap-1.5 rounded-md px-1.5 py-1 text-sm outline-hidden select-none focus:bg-accent focus:text-accent-foreground not-data-[variant=destructive]:focus:**:text-accent-foreground data-inset:pl-7 data-[variant=destructive]:text-destructive data-[variant=destructive]:focus:bg-destructive/10 data-[variant=destructive]:focus:text-destructive dark:data-[variant=destructive]:focus:bg-destructive/20 data-disabled:pointer-events-none data-disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4 data-[variant=destructive]:*:[svg]:text-destructive",
        className
      )}
      {...props}
    />
  )
}

function DropdownMenuCheckboxItem({
  className,
  children,
  checked,
  inset,
  ...props
}: React.ComponentProps<typeof DropdownMenuPrimitive.CheckboxItem> & {
  inset?: boolean
}) {
  return (
    <DropdownMenuPrimitive.CheckboxItem
      data-slot="dropdown-menu-checkbox-item"
      data-inset={inset}
      className={cn(
        "relative flex cursor-default items-center gap-1.5 rounded-md py-1 pr-8 pl-1.5 text-sm outline-hidden select-none focus:bg-accent focus:text-accent-foreground focus:**:text-accent-foreground data-inset:pl-7 data-disabled:pointer-events-none data-disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4",
        className
      )}
      checked={checked}
      {...props}
    >
      <span
        className="pointer-events-none absolute right-2 flex items-center justify-center"
        data-slot="dropdown-menu-checkbox-item-indicator"
      >
        <DropdownMenuPrimitive.ItemIndicator>
          <CheckIcon
          />
        </DropdownMenuPrimitive.ItemIndicator>
      </span>
      {children}
    </DropdownMenuPrimitive.CheckboxItem>
  )
}

function DropdownMenuRadioGroup({
  ...props
}: React.ComponentProps<typeof DropdownMenuPrimitive.RadioGroup>) {
  return (
    <DropdownMenuPrimitive.RadioGroup
      data-slot="dropdown-menu-radio-group"
      {...props}
    />
  )
}

function DropdownMenuRadioItem({
  className,
  children,
  inset,
  ...props
}: React.ComponentProps<typeof DropdownMenuPrimitive.RadioItem> & {
  inset?: boolean
}) {
  return (
    <DropdownMenuPrimitive.RadioItem
      data-slot="dropdown-menu-radio-item"
      data-inset={inset}
      className={cn(
        "relative flex cursor-default items-center gap-1.5 rounded-md py-1 pr-8 pl-1.5 text-sm outline-hidden select-none focus:bg-accent focus:text-accent-foreground focus:**:text-accent-foreground data-inset:pl-7 data-disabled:pointer-events-none data-disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4",
        className
      )}
      {...props}
    >
      <span
        className="pointer-events-none absolute right-2 flex items-center justify-center"
        data-slot="dropdown-menu-radio-item-indicator"
      >
        <DropdownMenuPrimitive.ItemIndicator>
          <CheckIcon
          />
        </DropdownMenuPrimitive.ItemIndicator>
      </span>
      {children}
    </DropdownMenuPrimitive.RadioItem>
  )
}

function DropdownMenuLabel({
  className,
  inset,
  ...props
}: React.ComponentProps<typeof DropdownMenuPrimitive.Label> & {
  inset?: boolean
}) {
  return (
    <DropdownMenuPrimitive.Label
      data-slot="dropdown-menu-label"
      data-inset={inset}
      className={cn(
        "px-1.5 py-1 text-xs font-medium text-muted-foreground data-inset:pl-7",
        className
      )}
      {...props}
    />
  )
}

function DropdownMenuSeparator({
  className,
  ...props
}: React.ComponentProps<typeof DropdownMenuPrimitive.Separator>) {
  return (
    <DropdownMenuPrimitive.Separator
      data-slot="dropdown-menu-separator"
      className={cn("-mx-1 my-1 h-px bg-border", className)}
      {...props}
    />
  )
}

function DropdownMenuShortcut({
  className,
  ...props
}: React.ComponentProps<"span">) {
  return (
    <span
      data-slot="dropdown-menu-shortcut"
      className={cn(
        "ml-auto text-xs tracking-widest text-muted-foreground group-focus/dropdown-menu-item:text-accent-foreground",
        className
      )}
      {...props}
    />
  )
}

function DropdownMenuSub({
  ...props
}: React.ComponentProps<typeof DropdownMenuPrimitive.Sub>) {
  return <DropdownMenuPrimitive.Sub data-slot="dropdown-menu-sub" {...props} />
}

function DropdownMenuSubTrigger({
  className,
  inset,
  children,
  ...props
}: React.ComponentProps<typeof DropdownMenuPrimitive.SubTrigger> & {
  inset?: boolean
}) {
  return (
    <DropdownMenuPrimitive.SubTrigger
      data-slot="dropdown-menu-sub-trigger"
      data-inset={inset}
      className={cn(
        "flex cursor-default items-center gap-1.5 rounded-md px-1.5 py-1 text-sm outline-hidden select-none focus:bg-accent focus:text-accent-foreground not-data-[variant=destructive]:focus:**:text-accent-foreground data-inset:pl-7 data-open:bg-accent data-open:text-accent-foreground [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4",
        className
      )}
      {...props}
    >
      {children}
      <ChevronRightIcon className="ml-auto" />
    </DropdownMenuPrimitive.SubTrigger>
  )
}

function DropdownMenuSubContent({
  className,
  ...props
}: React.ComponentProps<typeof DropdownMenuPrimitive.SubContent>) {
  return (
    <DropdownMenuPrimitive.SubContent
      data-slot="dropdown-menu-sub-content"
      className={cn("z-50 min-w-[96px] origin-(--radix-dropdown-menu-content-transform-origin) overflow-hidden rounded-lg bg-popover p-1 text-popover-foreground shadow-lg ring-1 ring-foreground/10 duration-100 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 data-open:animate-in data-open:fade-in-0 data-open:zoom-in-95 data-closed:animate-out data-closed:fade-out-0 data-closed:zoom-out-95", className )}
      {...props}
    />
  )
}

export {
  DropdownMenu,
  DropdownMenuPortal,
  DropdownMenuTrigger,
  DropdownMenuContent,
  DropdownMenuGroup,
  DropdownMenuLabel,
  DropdownMenuItem,
  DropdownMenuCheckboxItem,
  DropdownMenuRadioGroup,
  DropdownMenuRadioItem,
  DropdownMenuSeparator,
  DropdownMenuShortcut,
  DropdownMenuSub,
  DropdownMenuSubTrigger,
  DropdownMenuSubContent,
}

END_OF_FILE_CONTENT
echo "Creating src/components/ui/hover-card.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/hover-card.tsx"
"use client"

import * as React from "react"
import { HoverCard as HoverCardPrimitive } from "radix-ui"

import { cn } from "@/lib/utils"

function HoverCard({
  ...props
}: React.ComponentProps<typeof HoverCardPrimitive.Root>) {
  return <HoverCardPrimitive.Root data-slot="hover-card" {...props} />
}

function HoverCardTrigger({
  ...props
}: React.ComponentProps<typeof HoverCardPrimitive.Trigger>) {
  return (
    <HoverCardPrimitive.Trigger data-slot="hover-card-trigger" {...props} />
  )
}

function HoverCardContent({
  className,
  align = "center",
  sideOffset = 4,
  ...props
}: React.ComponentProps<typeof HoverCardPrimitive.Content>) {
  return (
    <HoverCardPrimitive.Portal data-slot="hover-card-portal">
      <HoverCardPrimitive.Content
        data-slot="hover-card-content"
        align={align}
        sideOffset={sideOffset}
        className={cn(
          "z-50 w-64 origin-(--radix-hover-card-content-transform-origin) rounded-lg bg-popover p-2.5 text-sm text-popover-foreground shadow-md ring-1 ring-foreground/10 outline-hidden duration-100 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 data-open:animate-in data-open:fade-in-0 data-open:zoom-in-95 data-closed:animate-out data-closed:fade-out-0 data-closed:zoom-out-95",
          className
        )}
        {...props}
      />
    </HoverCardPrimitive.Portal>
  )
}

export { HoverCard, HoverCardTrigger, HoverCardContent }

END_OF_FILE_CONTENT
echo "Creating src/components/ui/input.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/input.tsx"
import * as React from "react"

import { cn } from "@/lib/utils"

function Input({ className, type, ...props }: React.ComponentProps<"input">) {
  return (
    <input
      type={type}
      data-slot="input"
      className={cn(
        "h-8 w-full min-w-0 rounded-lg border border-input bg-transparent px-2.5 py-1 text-base transition-colors outline-none file:inline-flex file:h-6 file:border-0 file:bg-transparent file:text-sm file:font-medium file:text-foreground placeholder:text-muted-foreground focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50 disabled:pointer-events-none disabled:cursor-not-allowed disabled:bg-input/50 disabled:opacity-50 aria-invalid:border-destructive aria-invalid:ring-3 aria-invalid:ring-destructive/20 md:text-sm dark:bg-input/30 dark:disabled:bg-input/80 dark:aria-invalid:border-destructive/50 dark:aria-invalid:ring-destructive/40",
        className
      )}
      {...props}
    />
  )
}

export { Input }

END_OF_FILE_CONTENT
echo "Creating src/components/ui/label.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/label.tsx"
"use client"

import * as React from "react"
import { Label as LabelPrimitive } from "radix-ui"

import { cn } from "@/lib/utils"

function Label({
  className,
  ...props
}: React.ComponentProps<typeof LabelPrimitive.Root>) {
  return (
    <LabelPrimitive.Root
      data-slot="label"
      className={cn(
        "flex items-center gap-2 text-sm leading-none font-medium select-none group-data-[disabled=true]:pointer-events-none group-data-[disabled=true]:opacity-50 peer-disabled:cursor-not-allowed peer-disabled:opacity-50",
        className
      )}
      {...props}
    />
  )
}

export { Label }

END_OF_FILE_CONTENT
echo "Creating src/components/ui/navigation-menu.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/navigation-menu.tsx"
import * as React from "react"
import { cva } from "class-variance-authority"
import { NavigationMenu as NavigationMenuPrimitive } from "radix-ui"

import { cn } from "@/lib/utils"
import { ChevronDownIcon } from "lucide-react"

function NavigationMenu({
  className,
  children,
  viewport = true,
  ...props
}: React.ComponentProps<typeof NavigationMenuPrimitive.Root> & {
  viewport?: boolean
}) {
  return (
    <NavigationMenuPrimitive.Root
      data-slot="navigation-menu"
      data-viewport={viewport}
      className={cn(
        "group/navigation-menu relative flex max-w-max flex-1 items-center justify-center",
        className
      )}
      {...props}
    >
      {children}
      {viewport && <NavigationMenuViewport />}
    </NavigationMenuPrimitive.Root>
  )
}

function NavigationMenuList({
  className,
  ...props
}: React.ComponentProps<typeof NavigationMenuPrimitive.List>) {
  return (
    <NavigationMenuPrimitive.List
      data-slot="navigation-menu-list"
      className={cn(
        "group flex flex-1 list-none items-center justify-center gap-0",
        className
      )}
      {...props}
    />
  )
}

function NavigationMenuItem({
  className,
  ...props
}: React.ComponentProps<typeof NavigationMenuPrimitive.Item>) {
  return (
    <NavigationMenuPrimitive.Item
      data-slot="navigation-menu-item"
      className={cn("relative", className)}
      {...props}
    />
  )
}

const navigationMenuTriggerStyle = cva(
  "group/navigation-menu-trigger inline-flex h-9 w-max items-center justify-center rounded-lg px-2.5 py-1.5 text-sm font-medium transition-all outline-none hover:bg-muted focus:bg-muted focus-visible:ring-3 focus-visible:ring-ring/50 focus-visible:outline-1 disabled:pointer-events-none disabled:opacity-50 data-popup-open:bg-muted/50 data-popup-open:hover:bg-muted data-open:bg-muted/50 data-open:hover:bg-muted data-open:focus:bg-muted"
)

function NavigationMenuTrigger({
  className,
  children,
  ...props
}: React.ComponentProps<typeof NavigationMenuPrimitive.Trigger>) {
  return (
    <NavigationMenuPrimitive.Trigger
      data-slot="navigation-menu-trigger"
      className={cn(navigationMenuTriggerStyle(), "group", className)}
      {...props}
    >
      {children}{" "}
      <ChevronDownIcon className="relative top-px ml-1 size-3 transition duration-300 group-data-popup-open/navigation-menu-trigger:rotate-180 group-data-open/navigation-menu-trigger:rotate-180" aria-hidden="true" />
    </NavigationMenuPrimitive.Trigger>
  )
}

function NavigationMenuContent({
  className,
  ...props
}: React.ComponentProps<typeof NavigationMenuPrimitive.Content>) {
  return (
    <NavigationMenuPrimitive.Content
      data-slot="navigation-menu-content"
      className={cn(
        "top-0 left-0 w-full p-1 ease-[cubic-bezier(0.22,1,0.36,1)] group-data-[viewport=false]/navigation-menu:top-full group-data-[viewport=false]/navigation-menu:mt-1.5 group-data-[viewport=false]/navigation-menu:overflow-hidden group-data-[viewport=false]/navigation-menu:rounded-lg group-data-[viewport=false]/navigation-menu:bg-popover group-data-[viewport=false]/navigation-menu:text-popover-foreground group-data-[viewport=false]/navigation-menu:shadow group-data-[viewport=false]/navigation-menu:ring-1 group-data-[viewport=false]/navigation-menu:ring-foreground/10 group-data-[viewport=false]/navigation-menu:duration-300 data-[motion=from-end]:slide-in-from-right-52 data-[motion=from-start]:slide-in-from-left-52 data-[motion=to-end]:slide-out-to-right-52 data-[motion=to-start]:slide-out-to-left-52 data-[motion^=from-]:animate-in data-[motion^=from-]:fade-in data-[motion^=to-]:animate-out data-[motion^=to-]:fade-out **:data-[slot=navigation-menu-link]:focus:ring-0 **:data-[slot=navigation-menu-link]:focus:outline-none md:absolute md:w-auto group-data-[viewport=false]/navigation-menu:data-open:animate-in group-data-[viewport=false]/navigation-menu:data-open:fade-in-0 group-data-[viewport=false]/navigation-menu:data-open:zoom-in-95 group-data-[viewport=false]/navigation-menu:data-closed:animate-out group-data-[viewport=false]/navigation-menu:data-closed:fade-out-0 group-data-[viewport=false]/navigation-menu:data-closed:zoom-out-95",
        className
      )}
      {...props}
    />
  )
}

function NavigationMenuViewport({
  className,
  ...props
}: React.ComponentProps<typeof NavigationMenuPrimitive.Viewport>) {
  return (
    <div
      className={cn(
        "absolute top-full left-0 isolate z-50 flex justify-center"
      )}
    >
      <NavigationMenuPrimitive.Viewport
        data-slot="navigation-menu-viewport"
        className={cn(
          "origin-top-center relative mt-1.5 h-(--radix-navigation-menu-viewport-height) w-full overflow-hidden rounded-lg bg-popover text-popover-foreground shadow ring-1 ring-foreground/10 duration-100 md:w-(--radix-navigation-menu-viewport-width) data-open:animate-in data-open:zoom-in-90 data-closed:animate-out data-closed:zoom-out-90",
          className
        )}
        {...props}
      />
    </div>
  )
}

function NavigationMenuLink({
  className,
  ...props
}: React.ComponentProps<typeof NavigationMenuPrimitive.Link>) {
  return (
    <NavigationMenuPrimitive.Link
      data-slot="navigation-menu-link"
      className={cn(
        "flex items-center gap-2 rounded-lg p-2 text-sm transition-all outline-none hover:bg-muted focus:bg-muted focus-visible:ring-3 focus-visible:ring-ring/50 focus-visible:outline-1 in-data-[slot=navigation-menu-content]:rounded-md data-active:bg-muted/50 data-active:hover:bg-muted data-active:focus:bg-muted [&_svg:not([class*='size-'])]:size-4",
        className
      )}
      {...props}
    />
  )
}

function NavigationMenuIndicator({
  className,
  ...props
}: React.ComponentProps<typeof NavigationMenuPrimitive.Indicator>) {
  return (
    <NavigationMenuPrimitive.Indicator
      data-slot="navigation-menu-indicator"
      className={cn(
        "top-full z-1 flex h-1.5 items-end justify-center overflow-hidden data-[state=hidden]:animate-out data-[state=hidden]:fade-out data-[state=visible]:animate-in data-[state=visible]:fade-in",
        className
      )}
      {...props}
    >
      <div className="relative top-[60%] h-2 w-2 rotate-45 rounded-tl-sm bg-border shadow-md" />
    </NavigationMenuPrimitive.Indicator>
  )
}

export {
  NavigationMenu,
  NavigationMenuList,
  NavigationMenuItem,
  NavigationMenuContent,
  NavigationMenuTrigger,
  NavigationMenuLink,
  NavigationMenuIndicator,
  NavigationMenuViewport,
  navigationMenuTriggerStyle,
}

END_OF_FILE_CONTENT
echo "Creating src/components/ui/progress.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/progress.tsx"
import * as React from "react"
import { Progress as ProgressPrimitive } from "radix-ui"

import { cn } from "@/lib/utils"

function Progress({
  className,
  value,
  ...props
}: React.ComponentProps<typeof ProgressPrimitive.Root>) {
  return (
    <ProgressPrimitive.Root
      data-slot="progress"
      className={cn(
        "relative flex h-1 w-full items-center overflow-x-hidden rounded-full bg-muted",
        className
      )}
      {...props}
    >
      <ProgressPrimitive.Indicator
        data-slot="progress-indicator"
        className="size-full flex-1 bg-primary transition-all"
        style={{ transform: `translateX(-${100 - (value || 0)}%)` }}
      />
    </ProgressPrimitive.Root>
  )
}

export { Progress }

END_OF_FILE_CONTENT
echo "Creating src/components/ui/scroll-area.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/scroll-area.tsx"
import * as React from "react"
import { ScrollArea as ScrollAreaPrimitive } from "radix-ui"

import { cn } from "@/lib/utils"

function ScrollArea({
  className,
  children,
  ...props
}: React.ComponentProps<typeof ScrollAreaPrimitive.Root>) {
  return (
    <ScrollAreaPrimitive.Root
      data-slot="scroll-area"
      className={cn("relative", className)}
      {...props}
    >
      <ScrollAreaPrimitive.Viewport
        data-slot="scroll-area-viewport"
        className="size-full rounded-[inherit] transition-[color,box-shadow] outline-none focus-visible:ring-[3px] focus-visible:ring-ring/50 focus-visible:outline-1"
      >
        {children}
      </ScrollAreaPrimitive.Viewport>
      <ScrollBar />
      <ScrollAreaPrimitive.Corner />
    </ScrollAreaPrimitive.Root>
  )
}

function ScrollBar({
  className,
  orientation = "vertical",
  ...props
}: React.ComponentProps<typeof ScrollAreaPrimitive.ScrollAreaScrollbar>) {
  return (
    <ScrollAreaPrimitive.ScrollAreaScrollbar
      data-slot="scroll-area-scrollbar"
      data-orientation={orientation}
      orientation={orientation}
      className={cn(
        "flex touch-none p-px transition-colors select-none data-horizontal:h-2.5 data-horizontal:flex-col data-horizontal:border-t data-horizontal:border-t-transparent data-vertical:h-full data-vertical:w-2.5 data-vertical:border-l data-vertical:border-l-transparent",
        className
      )}
      {...props}
    >
      <ScrollAreaPrimitive.ScrollAreaThumb
        data-slot="scroll-area-thumb"
        className="relative flex-1 rounded-full bg-border"
      />
    </ScrollAreaPrimitive.ScrollAreaScrollbar>
  )
}

export { ScrollArea, ScrollBar }

END_OF_FILE_CONTENT
echo "Creating src/components/ui/select.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/select.tsx"
import * as React from "react"
import { Select as SelectPrimitive } from "radix-ui"

import { cn } from "@/lib/utils"
import { ChevronDownIcon, CheckIcon, ChevronUpIcon } from "lucide-react"

function Select({
  ...props
}: React.ComponentProps<typeof SelectPrimitive.Root>) {
  return <SelectPrimitive.Root data-slot="select" {...props} />
}

function SelectGroup({
  className,
  ...props
}: React.ComponentProps<typeof SelectPrimitive.Group>) {
  return (
    <SelectPrimitive.Group
      data-slot="select-group"
      className={cn("scroll-my-1 p-1", className)}
      {...props}
    />
  )
}

function SelectValue({
  ...props
}: React.ComponentProps<typeof SelectPrimitive.Value>) {
  return <SelectPrimitive.Value data-slot="select-value" {...props} />
}

function SelectTrigger({
  className,
  size = "default",
  children,
  ...props
}: React.ComponentProps<typeof SelectPrimitive.Trigger> & {
  size?: "sm" | "default"
}) {
  return (
    <SelectPrimitive.Trigger
      data-slot="select-trigger"
      data-size={size}
      className={cn(
        "flex w-fit items-center justify-between gap-1.5 rounded-lg border border-input bg-transparent py-2 pr-2 pl-2.5 text-sm whitespace-nowrap transition-colors outline-none select-none focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50 disabled:cursor-not-allowed disabled:opacity-50 aria-invalid:border-destructive aria-invalid:ring-3 aria-invalid:ring-destructive/20 data-placeholder:text-muted-foreground data-[size=default]:h-8 data-[size=sm]:h-7 data-[size=sm]:rounded-[min(var(--radius-md),10px)] *:data-[slot=select-value]:line-clamp-1 *:data-[slot=select-value]:flex *:data-[slot=select-value]:items-center *:data-[slot=select-value]:gap-1.5 dark:bg-input/30 dark:hover:bg-input/50 dark:aria-invalid:border-destructive/50 dark:aria-invalid:ring-destructive/40 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4",
        className
      )}
      {...props}
    >
      {children}
      <SelectPrimitive.Icon asChild>
        <ChevronDownIcon className="pointer-events-none size-4 text-muted-foreground" />
      </SelectPrimitive.Icon>
    </SelectPrimitive.Trigger>
  )
}

function SelectContent({
  className,
  children,
  position = "item-aligned",
  align = "center",
  ...props
}: React.ComponentProps<typeof SelectPrimitive.Content>) {
  return (
    <SelectPrimitive.Portal>
      <SelectPrimitive.Content
        data-slot="select-content"
        data-align-trigger={position === "item-aligned"}
        className={cn("relative z-50 max-h-(--radix-select-content-available-height) min-w-36 origin-(--radix-select-content-transform-origin) overflow-x-hidden overflow-y-auto rounded-lg bg-popover text-popover-foreground shadow-md ring-1 ring-foreground/10 duration-100 data-[align-trigger=true]:animate-none data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 data-open:animate-in data-open:fade-in-0 data-open:zoom-in-95 data-closed:animate-out data-closed:fade-out-0 data-closed:zoom-out-95", position ==="popper"&&"data-[side=bottom]:translate-y-1 data-[side=left]:-translate-x-1 data-[side=right]:translate-x-1 data-[side=top]:-translate-y-1", className )}
        position={position}
        align={align}
        {...props}
      >
        <SelectScrollUpButton />
        <SelectPrimitive.Viewport
          data-position={position}
          className={cn(
            "data-[position=popper]:h-(--radix-select-trigger-height) data-[position=popper]:w-full data-[position=popper]:min-w-(--radix-select-trigger-width)",
            position === "popper" && ""
          )}
        >
          {children}
        </SelectPrimitive.Viewport>
        <SelectScrollDownButton />
      </SelectPrimitive.Content>
    </SelectPrimitive.Portal>
  )
}

function SelectLabel({
  className,
  ...props
}: React.ComponentProps<typeof SelectPrimitive.Label>) {
  return (
    <SelectPrimitive.Label
      data-slot="select-label"
      className={cn("px-1.5 py-1 text-xs text-muted-foreground", className)}
      {...props}
    />
  )
}

function SelectItem({
  className,
  children,
  ...props
}: React.ComponentProps<typeof SelectPrimitive.Item>) {
  return (
    <SelectPrimitive.Item
      data-slot="select-item"
      className={cn(
        "relative flex w-full cursor-default items-center gap-1.5 rounded-md py-1 pr-8 pl-1.5 text-sm outline-hidden select-none focus:bg-accent focus:text-accent-foreground not-data-[variant=destructive]:focus:**:text-accent-foreground data-disabled:pointer-events-none data-disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4 *:[span]:last:flex *:[span]:last:items-center *:[span]:last:gap-2",
        className
      )}
      {...props}
    >
      <span className="pointer-events-none absolute right-2 flex size-4 items-center justify-center">
        <SelectPrimitive.ItemIndicator>
          <CheckIcon className="pointer-events-none" />
        </SelectPrimitive.ItemIndicator>
      </span>
      <SelectPrimitive.ItemText>{children}</SelectPrimitive.ItemText>
    </SelectPrimitive.Item>
  )
}

function SelectSeparator({
  className,
  ...props
}: React.ComponentProps<typeof SelectPrimitive.Separator>) {
  return (
    <SelectPrimitive.Separator
      data-slot="select-separator"
      className={cn("pointer-events-none -mx-1 my-1 h-px bg-border", className)}
      {...props}
    />
  )
}

function SelectScrollUpButton({
  className,
  ...props
}: React.ComponentProps<typeof SelectPrimitive.ScrollUpButton>) {
  return (
    <SelectPrimitive.ScrollUpButton
      data-slot="select-scroll-up-button"
      className={cn(
        "z-10 flex cursor-default items-center justify-center bg-popover py-1 [&_svg:not([class*='size-'])]:size-4",
        className
      )}
      {...props}
    >
      <ChevronUpIcon
      />
    </SelectPrimitive.ScrollUpButton>
  )
}

function SelectScrollDownButton({
  className,
  ...props
}: React.ComponentProps<typeof SelectPrimitive.ScrollDownButton>) {
  return (
    <SelectPrimitive.ScrollDownButton
      data-slot="select-scroll-down-button"
      className={cn(
        "z-10 flex cursor-default items-center justify-center bg-popover py-1 [&_svg:not([class*='size-'])]:size-4",
        className
      )}
      {...props}
    >
      <ChevronDownIcon
      />
    </SelectPrimitive.ScrollDownButton>
  )
}

export {
  Select,
  SelectContent,
  SelectGroup,
  SelectItem,
  SelectLabel,
  SelectScrollDownButton,
  SelectScrollUpButton,
  SelectSeparator,
  SelectTrigger,
  SelectValue,
}

END_OF_FILE_CONTENT
echo "Creating src/components/ui/select.txt..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/select.txt"
import * as React from "react"
import { Select as SelectPrimitive } from "radix-ui"

import { cn } from "@/lib/utils"
import { ChevronDownIcon, CheckIcon, ChevronUpIcon } from "lucide-react"

function Select({
  ...props
}: React.ComponentProps<typeof SelectPrimitive.Root>) {
  return <SelectPrimitive.Root data-slot="select" {...props} />
}

function SelectGroup({
  className,
  ...props
}: React.ComponentProps<typeof SelectPrimitive.Group>) {
  return (
    <SelectPrimitive.Group
      data-slot="select-group"
      className={cn("scroll-my-1 p-1", className)}
      {...props}
    />
  )
}

function SelectValue({
  ...props
}: React.ComponentProps<typeof SelectPrimitive.Value>) {
  return <SelectPrimitive.Value data-slot="select-value" {...props} />
}

function SelectTrigger({
  className,
  size = "default",
  children,
  ...props
}: React.ComponentProps<typeof SelectPrimitive.Trigger> & {
  size?: "sm" | "default"
}) {
  return (
    <SelectPrimitive.Trigger
      data-slot="select-trigger"
      data-size={size}
      className={cn(
        "border-input data-placeholder:text-muted-foreground dark:bg-input/30 dark:hover:bg-input/50 focus-visible:border-ring focus-visible:ring-ring/50 aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive dark:aria-invalid:border-destructive/50 gap-1.5 rounded-lg border bg-transparent py-2 pr-2 pl-2.5 text-sm transition-colors select-none focus-visible:ring-3 aria-invalid:ring-3 data-[size=default]:h-8 data-[size=sm]:h-7 data-[size=sm]:rounded-[min(var(--radius-md),10px)] *:data-[slot=select-value]:gap-1.5 [&_svg:not([class*='size-'])]:size-4 flex w-full items-center justify-between whitespace-nowrap outline-none disabled:cursor-not-allowed disabled:opacity-50 *:data-[slot=select-value]:line-clamp-1 *:data-[slot=select-value]:flex *:data-[slot=select-value]:items-center [&_svg]:pointer-events-none [&_svg]:shrink-0",
        className
      )}
      {...props}
    >
      {children}
      <SelectPrimitive.Icon asChild>
        <ChevronDownIcon className="text-muted-foreground size-4 pointer-events-none" />
      </SelectPrimitive.Icon>
    </SelectPrimitive.Trigger>
  )
}

function SelectContent({
  className,
  children,
  position = "popper",
  align = "center",
  ...props
}: React.ComponentProps<typeof SelectPrimitive.Content>) {
  return (
    <SelectPrimitive.Portal>
      <SelectPrimitive.Content
        data-slot="select-content"
        data-align-trigger={position === "item-aligned"}
        className={cn(
          "bg-popover text-popover-foreground data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 data-closed:zoom-out-95 data-open:zoom-in-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 ring-foreground/10 min-w-36 rounded-lg shadow-md ring-1 duration-100 relative z-[110] max-h-(--radix-select-content-available-height) origin-(--radix-select-content-transform-origin) overflow-x-hidden overflow-y-auto data-[align-trigger=true]:animate-none", 
          position === "popper" && "data-[side=bottom]:translate-y-1 data-[side=left]:-translate-x-1 data-[side=right]:translate-x-1 data-[side=top]:-translate-y-1", 
          className 
        )}
        position={position}
        align={align}
        {...props}
      >
        <SelectScrollUpButton />
        <SelectPrimitive.Viewport
          data-position={position}
          className={cn(
            "p-1",
            position === "popper" && "h-(--radix-select-trigger-height) w-full min-w-(--radix-select-trigger-width)"
          )}
        >
          {children}
        </SelectPrimitive.Viewport>
        <SelectScrollDownButton />
      </SelectPrimitive.Content>
    </SelectPrimitive.Portal>
  )
}

function SelectLabel({
  className,
  ...props
}: React.ComponentProps<typeof SelectPrimitive.Label>) {
  return (
    <SelectPrimitive.Label
      data-slot="select-label"
      className={cn("text-muted-foreground px-1.5 py-1 text-xs", className)}
      {...props}
    />
  )
}

function SelectItem({
  className,
  children,
  ...props
}: React.ComponentProps<typeof SelectPrimitive.Item>) {
  return (
    <SelectPrimitive.Item
      data-slot="select-item"
      className={cn(
        "focus:bg-accent focus:text-accent-foreground not-data-[variant=destructive]:focus:**:text-accent-foreground gap-1.5 rounded-md py-1 pr-8 pl-1.5 text-sm [&_svg:not([class*='size-'])]:size-4 *:[span]:last:flex *:[span]:last:items-center *:[span]:last:gap-2 relative flex w-full cursor-default items-center outline-hidden select-none data-disabled:pointer-events-none data-disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0",
        className
      )}
      {...props}
    >
      <span className="pointer-events-none absolute right-2 flex size-4 items-center justify-center">
        <SelectPrimitive.ItemIndicator>
          <CheckIcon className="pointer-events-none" />
        </SelectPrimitive.ItemIndicator>
      </span>
      <SelectPrimitive.ItemText>{children}</SelectPrimitive.ItemText>
    </SelectPrimitive.Item>
  )
}

function SelectSeparator({
  className,
  ...props
}: React.ComponentProps<typeof SelectPrimitive.Separator>) {
  return (
    <SelectPrimitive.Separator
      data-slot="select-separator"
      className={cn("bg-border -mx-1 my-1 h-px pointer-events-none", className)}
      {...props}
    />
  )
}

function SelectScrollUpButton({
  className,
  ...props
}: React.ComponentProps<typeof SelectPrimitive.ScrollUpButton>) {
  return (
    <SelectPrimitive.ScrollUpButton
      data-slot="select-scroll-up-button"
      className={cn("bg-popover z-10 flex cursor-default items-center justify-center py-1 [&_svg:not([class*='size-'])]:size-4", className)}
      {...props}
    >
      <ChevronUpIcon />
    </SelectPrimitive.ScrollUpButton>
  )
}

function SelectScrollDownButton({
  className,
  ...props
}: React.ComponentProps<typeof SelectPrimitive.ScrollDownButton>) {
  return (
    <SelectPrimitive.ScrollDownButton
      data-slot="select-scroll-down-button"
      className={cn("bg-popover z-10 flex cursor-default items-center justify-center py-1 [&_svg:not([class*='size-'])]:size-4", className)}
      {...props}
    >
      <ChevronDownIcon />
    </SelectPrimitive.ScrollDownButton>
  )
}

export {
  Select,
  SelectContent,
  SelectGroup,
  SelectItem,
  SelectLabel,
  SelectScrollDownButton,
  SelectScrollUpButton,
  SelectSeparator,
  SelectTrigger,
  SelectValue,
}




END_OF_FILE_CONTENT
echo "Creating src/components/ui/separator.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/separator.tsx"
import * as React from "react"
import { Separator as SeparatorPrimitive } from "radix-ui"

import { cn } from "@/lib/utils"

function Separator({
  className,
  orientation = "horizontal",
  decorative = true,
  ...props
}: React.ComponentProps<typeof SeparatorPrimitive.Root>) {
  return (
    <SeparatorPrimitive.Root
      data-slot="separator"
      decorative={decorative}
      orientation={orientation}
      className={cn(
        "shrink-0 bg-border data-horizontal:h-px data-horizontal:w-full data-vertical:w-px data-vertical:self-stretch",
        className
      )}
      {...props}
    />
  )
}

export { Separator }

END_OF_FILE_CONTENT
echo "Creating src/components/ui/sheet.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/sheet.tsx"
"use client"

import * as React from "react"
import { Dialog as SheetPrimitive } from "radix-ui"

import { cn } from "@/lib/utils"
import { Button } from "@/components/ui/button"
import { XIcon } from "lucide-react"

function Sheet({ ...props }: React.ComponentProps<typeof SheetPrimitive.Root>) {
  return <SheetPrimitive.Root data-slot="sheet" {...props} />
}

function SheetTrigger({
  ...props
}: React.ComponentProps<typeof SheetPrimitive.Trigger>) {
  return <SheetPrimitive.Trigger data-slot="sheet-trigger" {...props} />
}

function SheetClose({
  ...props
}: React.ComponentProps<typeof SheetPrimitive.Close>) {
  return <SheetPrimitive.Close data-slot="sheet-close" {...props} />
}

function SheetPortal({
  ...props
}: React.ComponentProps<typeof SheetPrimitive.Portal>) {
  return <SheetPrimitive.Portal data-slot="sheet-portal" {...props} />
}

function SheetOverlay({
  className,
  ...props
}: React.ComponentProps<typeof SheetPrimitive.Overlay>) {
  return (
    <SheetPrimitive.Overlay
      data-slot="sheet-overlay"
      className={cn(
        "fixed inset-0 z-50 bg-black/10 duration-100 supports-backdrop-filter:backdrop-blur-xs data-open:animate-in data-open:fade-in-0 data-closed:animate-out data-closed:fade-out-0",
        className
      )}
      {...props}
    />
  )
}

function SheetContent({
  className,
  children,
  side = "right",
  showCloseButton = true,
  ...props
}: React.ComponentProps<typeof SheetPrimitive.Content> & {
  side?: "top" | "right" | "bottom" | "left"
  showCloseButton?: boolean
}) {
  return (
    <SheetPortal>
      <SheetOverlay />
      <SheetPrimitive.Content
        data-slot="sheet-content"
        data-side={side}
        className={cn(
          "fixed z-50 flex flex-col gap-4 bg-popover bg-clip-padding text-sm text-popover-foreground shadow-lg transition duration-200 ease-in-out data-[side=bottom]:inset-x-0 data-[side=bottom]:bottom-0 data-[side=bottom]:h-auto data-[side=bottom]:border-t data-[side=left]:inset-y-0 data-[side=left]:left-0 data-[side=left]:h-full data-[side=left]:w-3/4 data-[side=left]:border-r data-[side=right]:inset-y-0 data-[side=right]:right-0 data-[side=right]:h-full data-[side=right]:w-3/4 data-[side=right]:border-l data-[side=top]:inset-x-0 data-[side=top]:top-0 data-[side=top]:h-auto data-[side=top]:border-b data-[side=left]:sm:max-w-sm data-[side=right]:sm:max-w-sm data-open:animate-in data-open:fade-in-0 data-[side=bottom]:data-open:slide-in-from-bottom-10 data-[side=left]:data-open:slide-in-from-left-10 data-[side=right]:data-open:slide-in-from-right-10 data-[side=top]:data-open:slide-in-from-top-10 data-closed:animate-out data-closed:fade-out-0 data-[side=bottom]:data-closed:slide-out-to-bottom-10 data-[side=left]:data-closed:slide-out-to-left-10 data-[side=right]:data-closed:slide-out-to-right-10 data-[side=top]:data-closed:slide-out-to-top-10",
          className
        )}
        {...props}
      >
        {children}
        {showCloseButton && (
          <SheetPrimitive.Close data-slot="sheet-close" asChild>
            <Button
              variant="ghost"
              className="absolute top-3 right-3"
              size="icon-sm"
            >
              <XIcon
              />
              <span className="sr-only">Close</span>
            </Button>
          </SheetPrimitive.Close>
        )}
      </SheetPrimitive.Content>
    </SheetPortal>
  )
}

function SheetHeader({ className, ...props }: React.ComponentProps<"div">) {
  return (
    <div
      data-slot="sheet-header"
      className={cn("flex flex-col gap-0.5 p-4", className)}
      {...props}
    />
  )
}

function SheetFooter({ className, ...props }: React.ComponentProps<"div">) {
  return (
    <div
      data-slot="sheet-footer"
      className={cn("mt-auto flex flex-col gap-2 p-4", className)}
      {...props}
    />
  )
}

function SheetTitle({
  className,
  ...props
}: React.ComponentProps<typeof SheetPrimitive.Title>) {
  return (
    <SheetPrimitive.Title
      data-slot="sheet-title"
      className={cn(
        "text-base font-medium text-foreground",
        className
      )}
      {...props}
    />
  )
}

function SheetDescription({
  className,
  ...props
}: React.ComponentProps<typeof SheetPrimitive.Description>) {
  return (
    <SheetPrimitive.Description
      data-slot="sheet-description"
      className={cn("text-sm text-muted-foreground", className)}
      {...props}
    />
  )
}

export {
  Sheet,
  SheetTrigger,
  SheetClose,
  SheetContent,
  SheetHeader,
  SheetFooter,
  SheetTitle,
  SheetDescription,
}

END_OF_FILE_CONTENT
echo "Creating src/components/ui/skeleton.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/skeleton.tsx"
import { cn } from "@/lib/utils"

function Skeleton({ className, ...props }: React.ComponentProps<"div">) {
  return (
    <div
      data-slot="skeleton"
      className={cn("animate-pulse rounded-md bg-muted", className)}
      {...props}
    />
  )
}

export { Skeleton }

END_OF_FILE_CONTENT
echo "Creating src/components/ui/switch.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/switch.tsx"
import * as React from "react"
import { Switch as SwitchPrimitive } from "radix-ui"

import { cn } from "@/lib/utils"

function Switch({
  className,
  size = "default",
  ...props
}: React.ComponentProps<typeof SwitchPrimitive.Root> & {
  size?: "sm" | "default"
}) {
  return (
    <SwitchPrimitive.Root
      data-slot="switch"
      data-size={size}
      className={cn(
        "peer group/switch relative inline-flex shrink-0 items-center rounded-full border border-transparent transition-all outline-none after:absolute after:-inset-x-3 after:-inset-y-2 focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50 aria-invalid:border-destructive aria-invalid:ring-3 aria-invalid:ring-destructive/20 data-[size=default]:h-[18.4px] data-[size=default]:w-[32px] data-[size=sm]:h-[14px] data-[size=sm]:w-[24px] dark:aria-invalid:border-destructive/50 dark:aria-invalid:ring-destructive/40 data-checked:bg-primary data-unchecked:bg-input dark:data-unchecked:bg-input/80 data-disabled:cursor-not-allowed data-disabled:opacity-50",
        className
      )}
      {...props}
    >
      <SwitchPrimitive.Thumb
        data-slot="switch-thumb"
        className="pointer-events-none block rounded-full bg-background ring-0 transition-transform group-data-[size=default]/switch:size-4 group-data-[size=sm]/switch:size-3 group-data-[size=default]/switch:data-checked:translate-x-[calc(100%-2px)] group-data-[size=sm]/switch:data-checked:translate-x-[calc(100%-2px)] dark:data-checked:bg-primary-foreground group-data-[size=default]/switch:data-unchecked:translate-x-0 group-data-[size=sm]/switch:data-unchecked:translate-x-0 dark:data-unchecked:bg-foreground"
      />
    </SwitchPrimitive.Root>
  )
}

export { Switch }

END_OF_FILE_CONTENT
echo "Creating src/components/ui/table.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/table.tsx"
import * as React from "react"

import { cn } from "@/lib/utils"

function Table({ className, ...props }: React.ComponentProps<"table">) {
  return (
    <div
      data-slot="table-container"
      className="relative w-full overflow-x-auto"
    >
      <table
        data-slot="table"
        className={cn("w-full caption-bottom text-sm", className)}
        {...props}
      />
    </div>
  )
}

function TableHeader({ className, ...props }: React.ComponentProps<"thead">) {
  return (
    <thead
      data-slot="table-header"
      className={cn("[&_tr]:border-b", className)}
      {...props}
    />
  )
}

function TableBody({ className, ...props }: React.ComponentProps<"tbody">) {
  return (
    <tbody
      data-slot="table-body"
      className={cn("[&_tr:last-child]:border-0", className)}
      {...props}
    />
  )
}

function TableFooter({ className, ...props }: React.ComponentProps<"tfoot">) {
  return (
    <tfoot
      data-slot="table-footer"
      className={cn(
        "border-t bg-muted/50 font-medium [&>tr]:last:border-b-0",
        className
      )}
      {...props}
    />
  )
}

function TableRow({ className, ...props }: React.ComponentProps<"tr">) {
  return (
    <tr
      data-slot="table-row"
      className={cn(
        "border-b transition-colors hover:bg-muted/50 has-aria-expanded:bg-muted/50 data-[state=selected]:bg-muted",
        className
      )}
      {...props}
    />
  )
}

function TableHead({ className, ...props }: React.ComponentProps<"th">) {
  return (
    <th
      data-slot="table-head"
      className={cn(
        "h-10 px-2 text-left align-middle font-medium whitespace-nowrap text-foreground [&:has([role=checkbox])]:pr-0",
        className
      )}
      {...props}
    />
  )
}

function TableCell({ className, ...props }: React.ComponentProps<"td">) {
  return (
    <td
      data-slot="table-cell"
      className={cn(
        "p-2 align-middle whitespace-nowrap [&:has([role=checkbox])]:pr-0",
        className
      )}
      {...props}
    />
  )
}

function TableCaption({
  className,
  ...props
}: React.ComponentProps<"caption">) {
  return (
    <caption
      data-slot="table-caption"
      className={cn("mt-4 text-sm text-muted-foreground", className)}
      {...props}
    />
  )
}

export {
  Table,
  TableHeader,
  TableBody,
  TableFooter,
  TableHead,
  TableRow,
  TableCell,
  TableCaption,
}

END_OF_FILE_CONTENT
echo "Creating src/components/ui/tabs.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/tabs.tsx"
"use client"

import * as React from "react"
import { cva, type VariantProps } from "class-variance-authority"
import { Tabs as TabsPrimitive } from "radix-ui"

import { cn } from "@/lib/utils"

function Tabs({
  className,
  orientation = "horizontal",
  ...props
}: React.ComponentProps<typeof TabsPrimitive.Root>) {
  return (
    <TabsPrimitive.Root
      data-slot="tabs"
      data-orientation={orientation}
      className={cn(
        "group/tabs flex gap-2 data-horizontal:flex-col",
        className
      )}
      {...props}
    />
  )
}

const tabsListVariants = cva(
  "group/tabs-list inline-flex w-fit items-center justify-center rounded-lg p-[3px] text-muted-foreground group-data-horizontal/tabs:h-8 group-data-vertical/tabs:h-fit group-data-vertical/tabs:flex-col data-[variant=line]:rounded-none",
  {
    variants: {
      variant: {
        default: "bg-muted",
        line: "gap-1 bg-transparent",
      },
    },
    defaultVariants: {
      variant: "default",
    },
  }
)

function TabsList({
  className,
  variant = "default",
  ...props
}: React.ComponentProps<typeof TabsPrimitive.List> &
  VariantProps<typeof tabsListVariants>) {
  return (
    <TabsPrimitive.List
      data-slot="tabs-list"
      data-variant={variant}
      className={cn(tabsListVariants({ variant }), className)}
      {...props}
    />
  )
}

function TabsTrigger({
  className,
  ...props
}: React.ComponentProps<typeof TabsPrimitive.Trigger>) {
  return (
    <TabsPrimitive.Trigger
      data-slot="tabs-trigger"
      className={cn(
        "relative inline-flex h-[calc(100%-1px)] flex-1 items-center justify-center gap-1.5 rounded-md border border-transparent px-1.5 py-0.5 text-sm font-medium whitespace-nowrap text-foreground/60 transition-all group-data-vertical/tabs:w-full group-data-vertical/tabs:justify-start hover:text-foreground focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 focus-visible:outline-1 focus-visible:outline-ring disabled:pointer-events-none disabled:opacity-50 has-data-[icon=inline-end]:pr-1 has-data-[icon=inline-start]:pl-1 dark:text-muted-foreground dark:hover:text-foreground group-data-[variant=default]/tabs-list:data-active:shadow-sm group-data-[variant=line]/tabs-list:data-active:shadow-none [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4",
        "group-data-[variant=line]/tabs-list:bg-transparent group-data-[variant=line]/tabs-list:data-active:bg-transparent dark:group-data-[variant=line]/tabs-list:data-active:border-transparent dark:group-data-[variant=line]/tabs-list:data-active:bg-transparent",
        "data-active:bg-background data-active:text-foreground dark:data-active:border-input dark:data-active:bg-input/30 dark:data-active:text-foreground",
        "after:absolute after:bg-foreground after:opacity-0 after:transition-opacity group-data-horizontal/tabs:after:inset-x-0 group-data-horizontal/tabs:after:bottom-[-5px] group-data-horizontal/tabs:after:h-0.5 group-data-vertical/tabs:after:inset-y-0 group-data-vertical/tabs:after:-right-1 group-data-vertical/tabs:after:w-0.5 group-data-[variant=line]/tabs-list:data-active:after:opacity-100",
        className
      )}
      {...props}
    />
  )
}

function TabsContent({
  className,
  ...props
}: React.ComponentProps<typeof TabsPrimitive.Content>) {
  return (
    <TabsPrimitive.Content
      data-slot="tabs-content"
      className={cn("flex-1 text-sm outline-none", className)}
      {...props}
    />
  )
}

export { Tabs, TabsList, TabsTrigger, TabsContent, tabsListVariants }

END_OF_FILE_CONTENT
echo "Creating src/components/ui/textarea.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/textarea.tsx"
import * as React from "react"

import { cn } from "@/lib/utils"

function Textarea({ className, ...props }: React.ComponentProps<"textarea">) {
  return (
    <textarea
      data-slot="textarea"
      className={cn(
        "flex field-sizing-content min-h-16 w-full rounded-lg border border-input bg-transparent px-2.5 py-2 text-base transition-colors outline-none placeholder:text-muted-foreground focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50 disabled:cursor-not-allowed disabled:bg-input/50 disabled:opacity-50 aria-invalid:border-destructive aria-invalid:ring-3 aria-invalid:ring-destructive/20 md:text-sm dark:bg-input/30 dark:disabled:bg-input/80 dark:aria-invalid:border-destructive/50 dark:aria-invalid:ring-destructive/40",
        className
      )}
      {...props}
    />
  )
}

export { Textarea }

END_OF_FILE_CONTENT
echo "Creating src/components/ui/toggle-group.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/toggle-group.tsx"
import * as React from "react"
import { type VariantProps } from "class-variance-authority"
import { ToggleGroup as ToggleGroupPrimitive } from "radix-ui"

import { cn } from "@/lib/utils"
import { toggleVariants } from "@/components/ui/toggle"

const ToggleGroupContext = React.createContext<
  VariantProps<typeof toggleVariants> & {
    spacing?: number
    orientation?: "horizontal" | "vertical"
  }
>({
  size: "default",
  variant: "default",
  spacing: 2,
  orientation: "horizontal",
})

function ToggleGroup({
  className,
  variant,
  size,
  spacing = 2,
  orientation = "horizontal",
  children,
  ...props
}: React.ComponentProps<typeof ToggleGroupPrimitive.Root> &
  VariantProps<typeof toggleVariants> & {
    spacing?: number
    orientation?: "horizontal" | "vertical"
  }) {
  return (
    <ToggleGroupPrimitive.Root
      data-slot="toggle-group"
      data-variant={variant}
      data-size={size}
      data-spacing={spacing}
      data-orientation={orientation}
      style={{ "--gap": spacing } as React.CSSProperties}
      className={cn(
        "group/toggle-group flex w-fit flex-row items-center gap-[--spacing(var(--gap))] rounded-lg data-[size=sm]:rounded-[min(var(--radius-md),10px)] data-vertical:flex-col data-vertical:items-stretch",
        className
      )}
      {...props}
    >
      <ToggleGroupContext.Provider
        value={{ variant, size, spacing, orientation }}
      >
        {children}
      </ToggleGroupContext.Provider>
    </ToggleGroupPrimitive.Root>
  )
}

function ToggleGroupItem({
  className,
  children,
  variant = "default",
  size = "default",
  ...props
}: React.ComponentProps<typeof ToggleGroupPrimitive.Item> &
  VariantProps<typeof toggleVariants>) {
  const context = React.useContext(ToggleGroupContext)

  return (
    <ToggleGroupPrimitive.Item
      data-slot="toggle-group-item"
      data-variant={context.variant || variant}
      data-size={context.size || size}
      data-spacing={context.spacing}
      className={cn(
        "shrink-0 group-data-[spacing=0]/toggle-group:rounded-none group-data-[spacing=0]/toggle-group:px-2 focus:z-10 focus-visible:z-10 group-data-[spacing=0]/toggle-group:has-data-[icon=inline-end]:pr-1.5 group-data-[spacing=0]/toggle-group:has-data-[icon=inline-start]:pl-1.5 group-data-horizontal/toggle-group:data-[spacing=0]:first:rounded-l-lg group-data-vertical/toggle-group:data-[spacing=0]:first:rounded-t-lg group-data-horizontal/toggle-group:data-[spacing=0]:last:rounded-r-lg group-data-vertical/toggle-group:data-[spacing=0]:last:rounded-b-lg group-data-horizontal/toggle-group:data-[spacing=0]:data-[variant=outline]:border-l-0 group-data-vertical/toggle-group:data-[spacing=0]:data-[variant=outline]:border-t-0 group-data-horizontal/toggle-group:data-[spacing=0]:data-[variant=outline]:first:border-l group-data-vertical/toggle-group:data-[spacing=0]:data-[variant=outline]:first:border-t",
        toggleVariants({
          variant: context.variant || variant,
          size: context.size || size,
        }),
        className
      )}
      {...props}
    >
      {children}
    </ToggleGroupPrimitive.Item>
  )
}

export { ToggleGroup, ToggleGroupItem }

END_OF_FILE_CONTENT
echo "Creating src/components/ui/toggle.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/toggle.tsx"
"use client"

import * as React from "react"
import { cva, type VariantProps } from "class-variance-authority"
import { Toggle as TogglePrimitive } from "radix-ui"

import { cn } from "@/lib/utils"

const toggleVariants = cva(
  "group/toggle inline-flex items-center justify-center gap-1 rounded-lg text-sm font-medium whitespace-nowrap transition-all outline-none hover:bg-muted hover:text-foreground focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 disabled:pointer-events-none disabled:opacity-50 aria-invalid:border-destructive aria-invalid:ring-destructive/20 aria-pressed:bg-muted data-[state=on]:bg-muted dark:aria-invalid:ring-destructive/40 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4",
  {
    variants: {
      variant: {
        default: "bg-transparent",
        outline: "border border-input bg-transparent hover:bg-muted",
      },
      size: {
        default:
          "h-8 min-w-8 px-2.5 has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2",
        sm: "h-7 min-w-7 rounded-[min(var(--radius-md),12px)] px-2.5 text-[0.8rem] has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 [&_svg:not([class*='size-'])]:size-3.5",
        lg: "h-9 min-w-9 px-2.5 has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  }
)

function Toggle({
  className,
  variant = "default",
  size = "default",
  ...props
}: React.ComponentProps<typeof TogglePrimitive.Root> &
  VariantProps<typeof toggleVariants>) {
  return (
    <TogglePrimitive.Root
      data-slot="toggle"
      className={cn(toggleVariants({ variant, size, className }))}
      {...props}
    />
  )
}

export { Toggle, toggleVariants }

END_OF_FILE_CONTENT
echo "Creating src/components/ui/tooltip.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/tooltip.tsx"
"use client"

import * as React from "react"
import { Tooltip as TooltipPrimitive } from "radix-ui"

import { cn } from "@/lib/utils"

function TooltipProvider({
  delayDuration = 0,
  ...props
}: React.ComponentProps<typeof TooltipPrimitive.Provider>) {
  return (
    <TooltipPrimitive.Provider
      data-slot="tooltip-provider"
      delayDuration={delayDuration}
      {...props}
    />
  )
}

function Tooltip({
  ...props
}: React.ComponentProps<typeof TooltipPrimitive.Root>) {
  return <TooltipPrimitive.Root data-slot="tooltip" {...props} />
}

function TooltipTrigger({
  ...props
}: React.ComponentProps<typeof TooltipPrimitive.Trigger>) {
  return <TooltipPrimitive.Trigger data-slot="tooltip-trigger" {...props} />
}

function TooltipContent({
  className,
  sideOffset = 0,
  children,
  ...props
}: React.ComponentProps<typeof TooltipPrimitive.Content>) {
  return (
    <TooltipPrimitive.Portal>
      <TooltipPrimitive.Content
        data-slot="tooltip-content"
        sideOffset={sideOffset}
        className={cn(
          "z-50 inline-flex w-fit max-w-xs origin-(--radix-tooltip-content-transform-origin) items-center gap-1.5 rounded-md bg-foreground px-3 py-1.5 text-xs text-background has-data-[slot=kbd]:pr-1.5 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 **:data-[slot=kbd]:relative **:data-[slot=kbd]:isolate **:data-[slot=kbd]:z-50 **:data-[slot=kbd]:rounded-sm data-[state=delayed-open]:animate-in data-[state=delayed-open]:fade-in-0 data-[state=delayed-open]:zoom-in-95 data-open:animate-in data-open:fade-in-0 data-open:zoom-in-95 data-closed:animate-out data-closed:fade-out-0 data-closed:zoom-out-95",
          className
        )}
        {...props}
      >
        {children}
        <TooltipPrimitive.Arrow className="z-50 size-2.5 translate-y-[calc(-50%_-_2px)] rotate-45 rounded-[2px] bg-foreground fill-foreground" />
      </TooltipPrimitive.Content>
    </TooltipPrimitive.Portal>
  )
}

export { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger }

END_OF_FILE_CONTENT
mkdir -p "src/data"
mkdir -p "src/data/collections"
mkdir -p "src/data/collections/autori"
echo "Creating src/data/collections/autori/autori.json..."
cat << 'END_OF_FILE_CONTENT' > "src/data/collections/autori/autori.json"
{
  "george-orwell": {
    "id": "george-orwell",
    "name": "George Orwell"
  },
  "umberto-eco": {
    "id": "umberto-eco",
    "name": "Umberto Eco"
  },
  "primo-levi": {
    "id": "primo-levi",
    "name": "Primo Levi"
  },
  "italo-calvino": {
    "id": "italo-calvino",
    "name": "Italo Calvino"
  },
  "giuseppe-tomasi-di-lampedusa": {
    "id": "giuseppe-tomasi-di-lampedusa",
    "name": "Giuseppe Tomasi di Lampedusa"
  },
  "italo-svevo": {
    "id": "italo-svevo",
    "name": "Italo Svevo"
  },
  "alessandro-manzoni": {
    "id": "alessandro-manzoni",
    "name": "Alessandro Manzoni"
  },
  "roberto-saviano": {
    "id": "roberto-saviano",
    "name": "Roberto Saviano"
  },
  "alessandro-baricco": {
    "id": "alessandro-baricco",
    "name": "Alessandro Baricco"
  },
  "natalia-ginzburg": {
    "id": "natalia-ginzburg",
    "name": "Natalia Ginzburg"
  },
  "gabriel-garcia-marquez": {
    "id": "gabriel-garcia-marquez",
    "name": "Gabriel Garcia Marquez"
  },
  "ray-bradbury": {
    "id": "ray-bradbury",
    "name": "Ray Bradbury"
  },
  "frank-herbert": {
    "id": "frank-herbert",
    "name": "Frank Herbert"
  },
  "william-gibson": {
    "id": "william-gibson",
    "name": "William Gibson"
  },
  "j-r-r-tolkien": {
    "id": "j-r-r-tolkien",
    "name": "J. R. R. Tolkien"
  },
  "j-k-rowling": {
    "id": "j-k-rowling",
    "name": "J. K. Rowling"
  },
  "jane-austen": {
    "id": "jane-austen",
    "name": "Jane Austen"
  },
  "herman-melville": {
    "id": "herman-melville",
    "name": "Herman Melville"
  },
  "fedor-dostoevskij": {
    "id": "fedor-dostoevskij",
    "name": "Fedor Dostoevskij"
  },
  "lev-tolstoj": {
    "id": "lev-tolstoj",
    "name": "Lev Tolstoj"
  },
  "michail-bulgakov": {
    "id": "michail-bulgakov",
    "name": "Michail Bulgakov"
  },
  "cormac-mccarthy": {
    "id": "cormac-mccarthy",
    "name": "Cormac McCarthy"
  },
  "david-mitchell": {
    "id": "david-mitchell",
    "name": "David Mitchell"
  },
  "haruki-murakami": {
    "id": "haruki-murakami",
    "name": "Haruki Murakami"
  },
  "chimamanda-ngozi-adichie": {
    "id": "chimamanda-ngozi-adichie",
    "name": "Chimamanda Ngozi Adichie"
  },
  "isabel-allende": {
    "id": "isabel-allende",
    "name": "Isabel Allende"
  },
  "toni-morrison": {
    "id": "toni-morrison",
    "name": "Toni Morrison"
  },
  "junot-diaz": {
    "id": "junot-diaz",
    "name": "Junot Diaz"
  },
  "jonathan-franzen": {
    "id": "jonathan-franzen",
    "name": "Jonathan Franzen"
  }
}
END_OF_FILE_CONTENT
mkdir -p "src/data/collections/libri"
echo "Creating src/data/collections/libri/libri.json..."
cat << 'END_OF_FILE_CONTENT' > "src/data/collections/libri/libri.json"
{
  "1984": {
    "id": "1984",
    "title": "1984",
    "author": {
      "$ref": "../autori/autori.json#/alessandro-baricco"
    },
    "year": 1949,
    "genre": "Distopia",
    "summary": "Un regime totalitario controlla linguaggio, memoria e pensiero."
  },
  "il-nome-della-rosa": {
    "id": "il-nome-della-rosa",
    "title": "Il nome della rosa",
    "author": {
      "$ref": "../autori/autori.json#/umberto-eco"
    },
    "year": 1980,
    "genre": "Romanzo storico",
    "summary": "Un'indagine in un'abbazia medievale diventa una riflessione su conoscenza, potere e interpretazione."
  },
  "se-questo-e-un-uomo": {
    "id": "se-questo-e-un-uomo",
    "title": "Se questo e un uomo",
    "author": {
      "$ref": "../autori/autori.json#/primo-levi"
    },
    "year": 1947,
    "genre": "Memoria",
    "summary": "La testimonianza essenziale di Levi sull'esperienza del lager e sulla dignita umana."
  },
  "le-citta-invisibili": {
    "id": "le-citta-invisibili",
    "title": "Le citta invisibili",
    "author": {
      "$ref": "../autori/autori.json#/italo-calvino"
    },
    "year": 1972,
    "genre": "Letteratura fantastica",
    "summary": "Marco Polo racconta a Kublai Khan citta immaginarie che parlano di memoria, desiderio e linguaggio."
  },
  "il-gattopardo": {
    "id": "il-gattopardo",
    "title": "Il Gattopardo",
    "author": {
      "$ref": "../autori/autori.json#/giuseppe-tomasi-di-lampedusa"
    },
    "year": 1958,
    "genre": "Romanzo storico",
    "summary": "Il tramonto dell'aristocrazia siciliana durante l'unificazione italiana."
  },
  "la-coscienza-di-zeno": {
    "id": "la-coscienza-di-zeno",
    "title": "La coscienza di Zeno",
    "author": {
      "$ref": "../autori/autori.json#/italo-svevo"
    },
    "year": 1923,
    "genre": "Romanzo psicologico",
    "summary": "Un diario ironico e nevrotico attraversa memoria, terapia e autoinganno."
  },
  "i-promessi-sposi": {
    "id": "i-promessi-sposi",
    "title": "I promessi sposi",
    "author": {
      "$ref": "../autori/autori.json#/alessandro-manzoni"
    },
    "year": 1842,
    "genre": "Classico",
    "summary": "La vicenda di Renzo e Lucia dentro carestia, guerra, peste e provvidenza."
  },
  "il-barone-rampante": {
    "id": "il-barone-rampante",
    "title": "Il barone rampante",
    "author": {
      "$ref": "../autori/autori.json#/italo-calvino"
    },
    "year": 1957,
    "genre": "Romanzo filosofico",
    "summary": "Cosimo sceglie di vivere sugli alberi e trasforma la distanza in una forma di liberta."
  },
  "gomorra": {
    "id": "gomorra",
    "title": "Gomorra",
    "author": {
      "$ref": "../autori/autori.json#/roberto-saviano"
    },
    "year": 2006,
    "genre": "Inchiesta",
    "summary": "Un reportage narrativo sulle economie e le violenze del sistema camorristico."
  },
  "oceano-mare": {
    "id": "oceano-mare",
    "title": "Oceano mare",
    "author": {
      "$ref": "../autori/autori.json#/alessandro-baricco"
    },
    "year": 1993,
    "genre": "Romanzo letterario",
    "summary": "Storie diverse si incontrano in una locanda sul mare, tra cura, naufragio e mistero."
  },
  "lessico-famigliare": {
    "id": "lessico-famigliare",
    "title": "Lessico famigliare",
    "author": {
      "$ref": "../autori/autori.json#/natalia-ginzburg"
    },
    "year": 1963,
    "genre": "Memoria narrativa",
    "summary": "Una famiglia prende forma attraverso parole, tic linguistici e memoria civile."
  },
  "cent-anni-di-solitudine": {
    "id": "cent-anni-di-solitudine",
    "title": "Cent'anni di solitudine",
    "author": {
      "$ref": "../autori/autori.json#/gabriel-garcia-marquez"
    },
    "year": 1967,
    "genre": "Realismo magico",
    "summary": "La saga dei Buendia e di Macondo intreccia mito, storia e destino."
  },
  "fahrenheit-451": {
    "id": "fahrenheit-451",
    "title": "Fahrenheit 451",
    "author": {
      "$ref": "../autori/autori.json#/ray-bradbury"
    },
    "year": 1953,
    "genre": "Distopia",
    "summary": "In un futuro dove i libri bruciano, leggere diventa un atto di resistenza."
  },
  "dune": {
    "id": "dune",
    "title": "Dune",
    "author": {
      "$ref": "../autori/autori.json#/frank-herbert"
    },
    "year": 1965,
    "genre": "Fantascienza",
    "summary": "Politica, ecologia e messianismo si scontrano sul pianeta desertico Arrakis."
  },
  "neuromancer": {
    "id": "neuromancer",
    "title": "Neuromancer",
    "author": {
      "$ref": "../autori/autori.json#/william-gibson"
    },
    "year": 1984,
    "genre": "Cyberpunk",
    "summary": "Un hacker decaduto viene trascinato in un colpo che attraversa cyberspazio e intelligenze artificiali."
  },
  "il-signore-degli-anelli": {
    "id": "il-signore-degli-anelli",
    "title": "Il Signore degli Anelli",
    "author": {
      "$ref": "../autori/autori.json#/j-r-r-tolkien"
    },
    "year": 1954,
    "genre": "Fantasy",
    "summary": "La Compagnia affronta il potere dell'Anello in una delle grandi epopee moderne."
  },
  "harry-potter-e-la-pietra-filosofale": {
    "id": "harry-potter-e-la-pietra-filosofale",
    "title": "Harry Potter e la pietra filosofale",
    "author": {
      "$ref": "../autori/autori.json#/j-k-rowling"
    },
    "year": 1997,
    "genre": "Fantasy",
    "summary": "Un ragazzo scopre il mondo magico e il proprio posto in una storia piu grande."
  },
  "orgoglio-e-pregiudizio": {
    "id": "orgoglio-e-pregiudizio",
    "title": "Orgoglio e pregiudizio",
    "author": {
      "$ref": "../autori/autori.json#/jane-austen"
    },
    "year": 1813,
    "genre": "Classico",
    "summary": "Elizabeth Bennet e Mr. Darcy si misurano con classe, carattere e giudizio sociale."
  },
  "moby-dick": {
    "id": "moby-dick",
    "title": "Moby Dick",
    "author": {
      "$ref": "../autori/autori.json#/herman-melville"
    },
    "year": 1851,
    "genre": "Avventura",
    "summary": "La caccia alla balena bianca diventa ossessione metafisica e viaggio nell'abisso."
  },
  "delitto-e-castigo": {
    "id": "delitto-e-castigo",
    "title": "Delitto e castigo",
    "author": {
      "$ref": "../autori/autori.json#/fedor-dostoevskij"
    },
    "year": 1866,
    "genre": "Romanzo psicologico",
    "summary": "Raskolnikov attraversa colpa, febbre morale e possibilita di redenzione."
  },
  "anna-karenina": {
    "id": "anna-karenina",
    "title": "Anna Karenina",
    "author": {
      "$ref": "../autori/autori.json#/lev-tolstoj"
    },
    "year": 1877,
    "genre": "Classico",
    "summary": "Una storia d'amore e rovina dentro la societa russa dell'Ottocento."
  },
  "il-maestro-e-margherita": {
    "id": "il-maestro-e-margherita",
    "title": "Il maestro e Margherita",
    "author": {
      "$ref": "../autori/autori.json#/michail-bulgakov"
    },
    "year": 1967,
    "genre": "Satira fantastica",
    "summary": "Il diavolo visita Mosca in un romanzo visionario su arte, censura e amore."
  },
  "la-strada": {
    "id": "la-strada",
    "title": "La strada",
    "author": {
      "$ref": "../autori/autori.json#/cormac-mccarthy"
    },
    "year": 2006,
    "genre": "Post-apocalittico",
    "summary": "Padre e figlio attraversano un mondo bruciato portando con se una fragile idea di bene."
  },
  "cloud-atlas": {
    "id": "cloud-atlas",
    "title": "Cloud Atlas",
    "author": {
      "$ref": "../autori/autori.json#/david-mitchell"
    },
    "year": 2004,
    "genre": "Romanzo corale",
    "summary": "Sei storie in epoche diverse compongono una meditazione su potere, memoria e reincorrenza."
  },
  "kafka-sulla-spiaggia": {
    "id": "kafka-sulla-spiaggia",
    "title": "Kafka sulla spiaggia",
    "author": {
      "$ref": "../autori/autori.json#/haruki-murakami"
    },
    "year": 2002,
    "genre": "Surrealismo",
    "summary": "Fuga, destino e sogno si intrecciano in un romanzo sospeso tra reale e mitico."
  },
  "americanah": {
    "id": "americanah",
    "title": "Americanah",
    "author": {
      "$ref": "../autori/autori.json#/chimamanda-ngozi-adichie"
    },
    "year": 2013,
    "genre": "Romanzo contemporaneo",
    "summary": "Migrazione, razza e identita raccontate attraverso una storia d'amore tra Nigeria e Stati Uniti."
  },
  "la-casa-degli-spiriti": {
    "id": "la-casa-degli-spiriti",
    "title": "La casa degli spiriti",
    "author": {
      "$ref": "../autori/autori.json#/isabel-allende"
    },
    "year": 1982,
    "genre": "Saga familiare",
    "summary": "La storia della famiglia Trueba intreccia politica, memoria e realismo magico."
  },
  "beloved": {
    "id": "beloved",
    "title": "Beloved",
    "author": {
      "$ref": "../autori/autori.json#/toni-morrison"
    },
    "year": 1987,
    "genre": "Romanzo storico",
    "summary": "Il trauma della schiavitu ritorna come presenza viva nella casa di Sethe."
  },
  "la-breve-favolosa-vita-di-oscar-wao": {
    "id": "la-breve-favolosa-vita-di-oscar-wao",
    "title": "La breve favolosa vita di Oscar Wao",
    "author": {
      "$ref": "../autori/autori.json#/junot-diaz"
    },
    "year": 2007,
    "genre": "Romanzo contemporaneo",
    "summary": "Famiglia, diaspora dominicana e cultura pop si intrecciano nella storia di Oscar."
  },
  "le-correzioni": {
    "id": "le-correzioni",
    "title": "Le correzioni",
    "author": {
      "$ref": "../autori/autori.json#/jonathan-franzen"
    },
    "year": 2001,
    "genre": "Romanzo familiare",
    "summary": "Una famiglia americana tenta di ritrovarsi mentre ciascuno affronta le proprie fratture."
  }
}
END_OF_FILE_CONTENT
mkdir -p "src/data/collections/posts"
echo "Creating src/data/collections/posts/posts.json..."
cat << 'END_OF_FILE_CONTENT' > "src/data/collections/posts/posts.json"
{
  "schema-driven-content-without-regret": {
    "id": "schema-driven-content-without-regret",
    "slug": "schema-driven-content-without-regret",
    "title": "Schema-Driven Content Without Regret",
    "dek": "How to use strict content schemas to speed up publishing instead of trapping editors in brittle abstractions.",
    "date": "2026-01-14",
    "readingTime": "8 min read",
    "tags": ["content systems", "schemas", "cms"],
    "related": ["structured authoring", "editor UX", "validation"],
    "content": [
      "Schema-driven content is often sold as a governance tool, but the more interesting question is whether it improves editorial flow. In practice, teams only keep a structured system if it reduces ambiguity and removes repetitive review cycles.",
      "The most durable pattern I have seen is to encode the invariants that already matter in production: URL shape, required metadata, relation integrity, and render-safe field types. Everything else should remain flexible enough for editors to work at writing speed.",
      "A useful schema is narrow where breakage is expensive and permissive where exploration is editorial. That usually means strong contracts for taxonomy, embeds, and navigation, combined with lighter constraints for narrative structure.",
      "The implementation detail many teams miss is feedback timing. Validation at publish time is too late. Editors need field-level guidance, sensible defaults, and previews that reflect the same render path the site will use in production.",
      "If a schema makes authors feel policed instead of supported, it will be bypassed. Good systems make the correct shape the path of least resistance."
    ]
  },
  "end-to-end-type-safety-is-an-org-design-problem": {
    "id": "end-to-end-type-safety-is-an-org-design-problem",
    "slug": "end-to-end-type-safety-is-an-org-design-problem",
    "title": "End-to-End Type Safety Is an Org Design Problem",
    "dek": "Type safety fails less often because of missing tooling than because ownership boundaries are unclear between APIs, content, and frontend surfaces.",
    "date": "2026-02-03",
    "readingTime": "10 min read",
    "tags": ["type safety", "typescript", "platform"],
    "related": ["schema ownership", "api contracts", "frontend architecture"],
    "content": [
      "Teams like to frame end-to-end type safety as a language feature, but the harder part is deciding who owns the contract when multiple systems touch the same data. A generated client is only as trustworthy as the source of truth behind it.",
      "The best implementations start with a small number of canonical schemas and treat all renderers, APIs, and jobs as consumers of those schemas rather than parallel authors. That changes how work is divided across teams.",
      "One anti-pattern is allowing every boundary to reshape data independently while still claiming the system is typed. Types become decorative when transforms are untracked or conventions live in Slack threads.",
      "Type safety becomes real when schema changes are reviewable, migration paths are explicit, and runtime validation exists where trust actually breaks down. Compile-time guarantees are necessary, but they are not sufficient.",
      "In other words: if your organization cannot agree on ownership, TypeScript will not save you."
    ]
  },
  "tooling-for-ai-agents-needs-boring-infrastructure": {
    "id": "tooling-for-ai-agents-needs-boring-infrastructure",
    "slug": "tooling-for-ai-agents-needs-boring-infrastructure",
    "title": "Tooling for AI Agents Needs Boring Infrastructure",
    "dek": "Reliable agent systems depend less on model novelty and more on the operational discipline behind tool execution, tracing, and failure handling.",
    "date": "2026-02-22",
    "readingTime": "9 min read",
    "tags": ["ai agents", "tooling", "observability"],
    "related": ["workflow engines", "safety", "runtime policy"],
    "content": [
      "The most common mistake in agent platforms is treating tool invocation like a side feature. In reality, once an agent can act on external systems, execution plumbing becomes the product.",
      "You need structured envelopes for inputs and outputs, durable traces, retry semantics, and a policy layer that can stop or reroute risky actions. None of this is glamorous, which is exactly why it matters.",
      "Boring infrastructure wins because it creates predictable failure modes. When an agent call fails, operators should know whether the model selected the wrong tool, the tool returned invalid data, or a downstream dependency timed out.",
      "This is also where developer experience matters. If adding a new tool requires bespoke wrappers and custom telemetry, teams will duplicate logic and drift immediately.",
      "The organizations shipping credible agent systems are usually the ones that quietly solved execution discipline first."
    ]
  },
  "developer-experience-begins-with-system-legibility": {
    "id": "developer-experience-begins-with-system-legibility",
    "slug": "developer-experience-begins-with-system-legibility",
    "title": "Developer Experience Begins with System Legibility",
    "dek": "Fast onboarding and clean APIs matter, but DX improves most when engineers can explain what the system is doing and why.",
    "date": "2026-03-11",
    "readingTime": "7 min read",
    "tags": ["developer experience", "platform", "observability"],
    "related": ["internal tools", "docs", "operability"],
    "content": [
      "Developer experience is often reduced to ergonomics: better CLI design, cleaner SDKs, nicer templates. Those things help, but they do not compensate for a system that is hard to read.",
      "Legibility means an engineer can trace a request, inspect a configuration source, understand the active contract, and predict what a change will affect. It is the difference between confidence and cargo culting.",
      "In platform work, the highest leverage improvements are often explanatory rather than flashy. A good error message, visible ownership metadata, or a schema diff can save more time than a redesigned dashboard.",
      "This is one reason documentation should be treated as runtime support, not marketing exhaust. Engineers need systems that explain themselves while they are in motion.",
      "If a platform is elegant only when presented in architecture slides, the developer experience is not actually good."
    ]
  }
}

END_OF_FILE_CONTENT
mkdir -p "src/data/collections/projects"
echo "Creating src/data/collections/projects/projects.json..."
cat << 'END_OF_FILE_CONTENT' > "src/data/collections/projects/projects.json"
{
  "ledger-graph-migration": {
    "id": "ledger-graph-migration",
    "slug": "ledger-graph-migration",
    "title": "Ledger Graph Migration",
    "category": "Data Platform",
    "year": "2025",
    "summary": "Rebuilt a payment-ledger dependency service from ad-hoc SQL traversals into a graph-backed event pipeline that could explain settlement state in milliseconds instead of minutes.",
    "context": "A fintech platform had grown a reconciliation engine around recursive SQL and delayed batch jobs. Operators could not answer why a payout was blocked without running custom scripts.",
    "problem": "The system mixed transactional writes, lineage queries, and retry orchestration in one relational workflow, producing lock contention and opaque incident handling.",
    "architecture": "I separated the write path from the explanation path, emitting append-only ledger events into Kafka, materializing relationship edges into a graph projection, and exposing deterministic trace queries through a typed service boundary.",
    "result": "Median payout-trace latency dropped from 11.4 minutes to 420 milliseconds, and incident triage time during settlement windows fell by 68 percent.",
    "outcomeLong": "The biggest gain was not only latency but operator confidence. Support and finance teams could inspect state transitions without waking engineering, while platform teams gained a clean contract for downstream analytics and audit exports.",
    "stack": ["TypeScript", "Kafka", "PostgreSQL", "Neo4j", "OpenTelemetry"]
  },
  "docs-schema-pipeline": {
    "id": "docs-schema-pipeline",
    "slug": "docs-schema-pipeline",
    "title": "Docs Schema Pipeline",
    "category": "Developer Experience",
    "year": "2024",
    "summary": "Designed a schema-driven documentation pipeline for an internal platform so product docs, API references, and release notes could be authored once and published consistently across surfaces.",
    "context": "Teams maintained markdown fragments, API snippets, and changelog entries in separate systems, which caused drift between the product, docs site, and support tooling.",
    "problem": "Every team solved structured content differently, so navigation, metadata, and validation rules changed from one repository to the next.",
    "architecture": "I introduced a shared content schema package, JSON-authored publishing manifests, and TypeScript-generated render contracts that enforced field-level guarantees from authoring to delivery.",
    "result": "Documentation publishing time fell from two days of manual QA to a 20-minute automated pipeline, while support ticket deflection improved 24 percent after launch.",
    "outcomeLong": "The program created a repeatable way to evolve docs as a product surface. New documentation types no longer needed a custom renderer or manual governance process.",
    "stack": ["TypeScript", "Zod", "Node.js", "Vite", "GitHub Actions"]
  },
  "agent-tooling-control-plane": {
    "id": "agent-tooling-control-plane",
    "slug": "agent-tooling-control-plane",
    "title": "Agent Tooling Control Plane",
    "category": "AI Infrastructure",
    "year": "2025",
    "summary": "Built a control plane for tool-enabled AI agents that standardized tool registration, execution traces, and safety policies across multiple internal assistants.",
    "context": "Three teams were building AI copilots with duplicated wrappers around APIs, uneven telemetry, and no shared policy layer for rate limits or human escalation.",
    "problem": "Agents could call tools, but operations had no consistent record of which action happened, why it happened, or whether a fallback path was available.",
    "architecture": "I defined a typed tool registry, execution envelopes with structured inputs and outputs, and a policy runtime that could intercept calls for approval, retries, and observability before forwarding to the target system.",
    "result": "Time to add a new tool dropped from roughly 3 engineer-days to under 4 hours, and production debugging of failed agent actions improved because every step shipped with normalized traces.",
    "outcomeLong": "The control plane became a foundation for safer experimentation. Teams could ship domain-specific assistants without rewriting execution plumbing, while security retained central visibility into tool access patterns.",
    "stack": ["TypeScript", "Temporal", "Redis", "OpenTelemetry", "gRPC"]
  },
  "warehouse-query-gateway": {
    "id": "warehouse-query-gateway",
    "slug": "warehouse-query-gateway",
    "title": "Warehouse Query Gateway",
    "category": "Backend Architecture",
    "year": "2023",
    "summary": "Introduced a typed query gateway in front of a multi-tenant analytics warehouse to prevent unsafe workloads, normalize caching, and make query cost visible to product teams.",
    "context": "A SaaS analytics product allowed many internal services to hit the warehouse directly, leading to noisy-neighbor issues and expensive exploratory queries in production paths.",
    "problem": "There was no shared contract for query shape, access policy, or caching strategy, so every service optimized independently and often poorly.",
    "architecture": "I inserted a gateway that accepted only named, schema-validated query definitions, applied tenant-aware caching, and attached cost telemetry to every execution path before forwarding requests to the warehouse.",
    "result": "Warehouse spend dropped 31 percent quarter over quarter, p95 dashboard latency improved by 43 percent, and support incidents tied to runaway queries nearly disappeared.",
    "outcomeLong": "The gateway clarified ownership around analytics workloads and made performance decisions legible. Teams could reason about the cost of product features before launch instead of after billing surprises.",
    "stack": ["Go", "PostgreSQL", "BigQuery", "Redis", "Prometheus"]
  }
}

END_OF_FILE_CONTENT
mkdir -p "src/data/config"
echo "Creating src/data/config/menu.json..."
cat << 'END_OF_FILE_CONTENT' > "src/data/config/menu.json"
{
  "main": [
    { "id": "nav-about", "label": "About", "href": "/about" },
    { "id": "nav-work", "label": "Work", "href": "/work" },
    { "id": "nav-blog", "label": "Blog", "href": "/blog" },
    { "id": "nav-contact", "label": "Contact", "href": "/contact", "isCta": true }
  ],
  "footer": [
    { "id": "foot-github", "label": "GitHub", "href": "https://github.com/andrewlinh", "icon": "github" },
    { "id": "foot-linkedin", "label": "LinkedIn", "href": "https://www.linkedin.com/in/andrewlinh", "icon": "linkedin" },
    { "id": "foot-rss", "label": "RSS", "href": "/blog/rss.xml", "icon": "rss" },
    { "id": "foot-email", "label": "Email", "href": "mailto:hello@andrewlinh.dev", "icon": "mail" }
  ]
}

END_OF_FILE_CONTENT
echo "Creating src/data/config/menu_example_for_schema.json..."
cat << 'END_OF_FILE_CONTENT' > "src/data/config/menu_example_for_schema.json"
{
  "main": [
    { 
      "label": "Why",
      "href": "/why",
      "children": [
        {
          "label": "Overview",
          "href": "/platform/overview"
        },
        {
          "label": "Architecture",
          "href": "/platform/architecture"
        },
        {
          "label": "Security",
          "href": "/platform/security"
        },
        {
          "label": "Integrations",
          "href": "/platform/integrations"
        },
        {
          "label": "Roadmap",
          "href": "/platform/roadmap"
        }
      ]
    },
    {
      "label": "Solutions",
      "href": "/solutions"
    },
    {
      "label": "Pricing",
      "href": "/pricing"
    },
    {
      "label": "Resources",
      "href": "/resources"
    }
  ]
}
END_OF_FILE_CONTENT
echo "Creating src/data/config/site.json..."
cat << 'END_OF_FILE_CONTENT' > "src/data/config/site.json"
{
  "header": {
    "id": "global-header",
    "type": "header",
    "data": {
      "announcement": "Systems architecture, structured data, and AI-native tooling.",
      "logoText": "Andrew Linh",
      "logoHighlight": "systems architect",
      "menu": { "$ref": "../config/menu.json#/main" }
    },
    "settings": { "sticky": true }
  },
  "footer": {
    "id": "global-footer",
    "type": "footer",
    "data": {
      "brandText": "Andrew Linh",
      "brandHighlight": "technical writing",
      "summary": "A personal portfolio and editorial home for backend architecture, developer tools, and calm, precise systems design.",
      "email": "hello@andrewlinh.dev",
      "copyright": "© 2026 Andrew Linh. All rights reserved.",
      "menu": { "$ref": "../config/menu.json#/footer" }
    },
    "settings": { "showLogo": true }
  },
  "identity": {
    "title": "Andrew Linh"
  }
}

END_OF_FILE_CONTENT
echo "Creating src/data/config/theme.json..."
cat << 'END_OF_FILE_CONTENT' > "src/data/config/theme.json"
{
  "name": "Andrew Linh",
  "tokens": {
    "colors": {
      "background": "#0a0d0c",
      "foreground": "#eef2ef",
      "card": "#111514",
      "card-foreground": "#eef2ef",
      "elevated": "#171c1a",
      "overlay": "#0d110fff",
      "primary": "#5dd39e",
      "primary-foreground": "#07100b",
      "primary-light": "#8be6ba",
      "primary-dark": "#2e8f64",
      "accent": "#7ce3b0",
      "accent-foreground": "#07100b",
      "secondary": "#151a18",
      "secondary-foreground": "#d5ddd8",
      "muted": "#101413",
      "muted-foreground": "#95a29a",
      "border": "#202826",
      "border-strong": "#31403b",
      "input": "#151a18",
      "ring": "#5dd39e",
      "destructive": "#b84f5f",
      "destructive-foreground": "#fff3f5",
      "success": "#4bc289",
      "success-foreground": "#06110b",
      "warning": "#c9a35c",
      "warning-foreground": "#171108",
      "info": "#62b8a2",
      "info-foreground": "#06110d"
    },
    "typography": {
      "fontFamily": {
        "primary": "\"Instrument Sans\", ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif",
        "mono": "\"SFMono-Regular\", \"SF Mono\", Consolas, \"Liberation Mono\", Menlo, monospace",
        "display": "\"Instrument Serif\", ui-serif, Georgia, Cambria, \"Times New Roman\", Times, serif"
      },
      "wordmark": {
        "fontFamily": "\"Instrument Sans\", ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif",
        "weight": "600"
      }
    },
    "borderRadius": {
      "sm": "6px",
      "md": "10px",
      "lg": "14px",
      "xl": "18px",
      "full": "9999px"
    },
    "spacing": {
      "container-max": "1152px",
      "section-y": "104px",
      "header-h": "64px",
      "sidebar-w": "240px"
    },
    "zIndex": {
      "base": "0",
      "elevated": "10",
      "dropdown": "100",
      "sticky": "200",
      "overlay": "300",
      "modal": "400",
      "toast": "500"
    },
    "modes": {
      "light": {
        "colors": {
          "background": "#f7f8f7",
          "foreground": "#111614",
          "card": "#ffffff",
          "card-foreground": "#111614",
          "elevated": "#eef1ef",
          "overlay": "#f5f7f6ee",
          "primary": "#267a53",
          "primary-foreground": "#f7fff9",
          "primary-light": "#5cb98a",
          "primary-dark": "#1d6041",
          "accent": "#2f8d60",
          "accent-foreground": "#f7fff9",
          "secondary": "#eef1ef",
          "secondary-foreground": "#1b221f",
          "muted": "#f0f3f1",
          "muted-foreground": "#5b6861",
          "border": "#d9e1dd",
          "border-strong": "#bcc8c2",
          "input": "#ffffff",
          "ring": "#267a53",
          "destructive": "#b84f5f",
          "destructive-foreground": "#fff7f8",
          "success": "#2b8e61",
          "success-foreground": "#f6fffa",
          "warning": "#a7792a",
          "warning-foreground": "#fff8ec",
          "info": "#2f7e70",
          "info-foreground": "#f5fffd"
        }
      }
    }
  }
}

END_OF_FILE_CONTENT
mkdir -p "src/data/pages"
echo "Creating src/data/pages/about.json..."
cat << 'END_OF_FILE_CONTENT' > "src/data/pages/about.json"
{
  "id": "about-page",
  "slug": "about",
  "meta": {
    "title": "About Andrew Linh — Architecture, Writing, and Systems Thinking",
    "description": "Learn about Andrew Linh’s professional path, technical stack, and design philosophy across backend systems, developer tooling, structured content, and AI-native infrastructure."
  },
  "sections": [
    {
      "id": "about-page-hero",
      "type": "page-hero",
      "data": {
        "label": "About",
        "title": "A systems architect who writes to make architecture legible",
        "description": "My work sits between implementation detail and organizational clarity: platform strategy, typed interfaces, infrastructure decisions, and the narratives teams need in order to operate them well."
      },
      "settings": { "theme": "dark" }
    },
    {
      "id": "about-bio-panel",
      "type": "bio-panel",
      "data": {
        "label": "Background",
        "title": "From backend delivery to platform-level system design",
        "description": "I began in application engineering, moved into data-heavy backend systems, and gradually specialized in the layer where product requirements meet platform constraints. Over time that expanded into technical writing: design docs, schema governance, internal documentation, and public essays about reliable systems.",
        "image": {
          "url": "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=900&q=80",
          "alt": "Close portrait of a thoughtful engineer seated near a window"
        },
        "note": "I prefer simple interfaces, explicit contracts, and infrastructure that explains itself."
      },
      "settings": { "theme": "dark" }
    },
    {
      "id": "about-timeline",
      "type": "timeline",
      "data": {
        "label": "Path",
        "title": "Professional trajectory",
        "items": [
          {
            "id": "timeline-1",
            "period": "2017–2019",
            "title": "Backend Engineer",
            "organization": "Product engineering teams",
            "body": "Built API services and operational tooling for SaaS products, with a focus on data integrity, deployment safety, and incident response."
          },
          {
            "id": "timeline-2",
            "period": "2019–2022",
            "title": "Senior Systems Engineer",
            "organization": "Platform and data organizations",
            "body": "Led architecture work around event pipelines, typed service boundaries, and warehouse-facing backend systems with multi-team dependencies."
          },
          {
            "id": "timeline-3",
            "period": "2022–2024",
            "title": "Staff Architect",
            "organization": "Developer platform initiatives",
            "body": "Designed internal tooling and contract layers that improved reliability, reduced duplicated infra work, and made system behavior easier to reason about."
          },
          {
            "id": "timeline-4",
            "period": "2024–Present",
            "title": "Independent Architect and Writer",
            "organization": "Consulting and editorial practice",
            "body": "Advising teams on backend architecture, structured content systems, AI-native tooling, and technical communication that survives implementation."
          }
        ]
      },
      "settings": { "theme": "dark" }
    },
    {
      "id": "about-skills-grid",
      "type": "skills-grid",
      "data": {
        "label": "Stack",
        "title": "Tools and systems I reach for often",
        "items": [
          {
            "id": "skill-1",
            "category": "Language",
            "label": "TypeScript",
            "icon": "braces",
            "body": "My default choice for end-to-end contracts across API design, content systems, and internal platforms."
          },
          {
            "id": "skill-2",
            "category": "Infrastructure",
            "label": "Distributed services",
            "icon": "server",
            "body": "Service boundaries, queue-backed workflows, event processing, and operationally legible runtime patterns."
          },
          {
            "id": "skill-3",
            "category": "Data",
            "label": "Relational and analytical stores",
            "icon": "database",
            "body": "PostgreSQL, warehouse query governance, lineage-aware data design, and schema lifecycle management."
          },
          {
            "id": "skill-4",
            "category": "AI systems",
            "label": "Agent tooling and policy layers",
            "icon": "cpu",
            "body": "Tool registries, execution envelopes, observability, and runtime controls for AI-native products."
          },
          {
            "id": "skill-5",
            "category": "Platform",
            "label": "Workflow orchestration",
            "icon": "workflow",
            "body": "Designing deterministic workflow surfaces that coordinate retries, approvals, and long-running jobs safely."
          }
        ]
      },
      "settings": { "theme": "dark" }
    },
    {
      "id": "about-philosophy",
      "type": "philosophy",
      "data": {
        "label": "Philosophy",
        "title": "How I think about architecture work",
        "description": "The goal is rarely maximal complexity. It is usually the smallest durable system that can explain itself.",
        "items": [
          {
            "id": "principle-1",
            "title": "Legibility is a feature",
            "body": "Systems should make it easy to understand ownership, active configuration, and the consequences of change. If only the original author can explain the architecture, the system is underdesigned."
          },
          {
            "id": "principle-2",
            "title": "Contracts beat conventions",
            "body": "Important boundaries deserve typed, reviewable contracts with runtime validation in the places trust actually breaks down."
          },
          {
            "id": "principle-3",
            "title": "Operational calm matters",
            "body": "A design that performs well on happy paths but generates confusing incidents is not complete. Failure modes must be boring and diagnosable."
          }
        ]
      },
      "settings": { "theme": "dark" }
    }
  ]
}

END_OF_FILE_CONTENT
mkdir -p "src/data/pages/authors"
echo "Creating src/data/pages/authors.json..."
cat << 'END_OF_FILE_CONTENT' > "src/data/pages/authors.json"
{
  "id": "authors-page",
  "slug": "authors",
  "meta": {
    "title": "Authors",
    "description": "Author directory powered by the autori collection."
  },
  "sections": [
    {
      "id": "authors-list-1",
      "type": "authors-list",
      "data": {
        "anchorId": "authors",
        "eyebrow": "Collection demo",
        "title": "Authors",
        "description": "A collection-backed directory of authors referenced by books.",
        "items": {
          "$ref": "../collections/autori/autori.json"
        }
      }
    }
  ],
  "global-header": false
}

END_OF_FILE_CONTENT
mkdir -p "src/data/pages/authors/[authorId]"
echo "Creating src/data/pages/authors/[authorId]/libri.json..."
cat << 'END_OF_FILE_CONTENT' > "src/data/pages/authors/[authorId]/libri.json"
{
  "id": "author-books-page",
  "slug": "authors/[authorId]/libri",
  "meta": {
    "title": "Libri per autore",
    "description": "Catalogo libri filtrato per autore."
  },
  "sections": [
    {
      "id": "books-list-author-filter",
      "type": "books-list",
      "data": {
        "anchorId": "libri-autore",
        "eyebrow": "Author books",
        "title": "Libri",
        "description": "Libri filtrati per autore dalla collection autori.",
        "items": {
          "$ref": "../../collections/libri/libri.json"
        },
        "pageSize": 10
      }
    }
  ],
  "global-header": false
}

END_OF_FILE_CONTENT
echo "Creating src/data/pages/blog.json..."
cat << 'END_OF_FILE_CONTENT' > "src/data/pages/blog.json"
{
  "id": "blog-page",
  "slug": "blog",
  "meta": {
    "title": "Blog — Writing on Structured Systems and Developer Tooling",
    "description": "Read essays by Andrew Linh on schema-driven content, end-to-end type safety, AI agent tooling, developer experience, and practical backend architecture."
  },
  "sections": [
    {
      "id": "blog-page-hero",
      "type": "page-hero",
      "data": {
        "label": "Blog",
        "title": "Essays on structured systems, developer tooling, and architectural clarity",
        "description": "Writing here focuses on the contracts, runtime behaviors, and organizational choices that make software easier to build and operate."
      },
      "settings": { "theme": "dark" }
    },
    {
      "id": "blog-rollup-main",
      "type": "blog-rollup",
      "data": {
        "label": "All posts",
        "title": "Recent articles",
        "description": "Long-form notes drawn from consulting work, platform design, and technical editorial practice.",
        "items": { "$ref": "../collections/posts/posts.json" }
      },
      "settings": { "theme": "dark" }
    },
    {
      "id": "blog-philosophy-panel",
      "type": "philosophy",
      "data": {
        "label": "Editorial stance",
        "title": "What the blog tries to do",
        "description": "I prefer writing that turns architecture into practical decision-making rather than abstract inspiration.",
        "items": [
          {
            "id": "blog-principle-1",
            "title": "Specific over vague",
            "body": "Concrete examples, explicit trade-offs, and operational consequences matter more than broad best-practice slogans."
          },
          {
            "id": "blog-principle-2",
            "title": "Systems over tools",
            "body": "I care less about novelty than about how a tool changes ownership, failure modes, and maintenance burden."
          },
          {
            "id": "blog-principle-3",
            "title": "Writing as infrastructure",
            "body": "Good technical writing reduces ambiguity in exactly the same way good interfaces do."
          }
        ]
      },
      "settings": { "theme": "dark" }
    },
    {
      "id": "blog-contact-cta",
      "type": "contact-cta",
      "data": {
        "label": "Commissioned writing",
        "title": "Need a technical article, architecture memo, or internal platform narrative?",
        "description": "I also work with teams on developer-facing documentation, system explainers, and editorial framing for technically complex products.",
        "primaryCta": { "id": "blog-contact-cta-1", "label": "Get in touch", "href": "/contact", "variant": "primary" },
        "secondaryCta": { "id": "blog-contact-cta-2", "label": "See work", "href": "/work", "variant": "secondary" }
      },
      "settings": { "theme": "accent" }
    }
  ]
}

END_OF_FILE_CONTENT
echo "Creating src/data/pages/contact.json..."
cat << 'END_OF_FILE_CONTENT' > "src/data/pages/contact.json"
{
  "id": "contact-page",
  "slug": "contact",
  "meta": {
    "title": "Contact Andrew Linh — Consulting and Technical Writing",
    "description": "Contact Andrew Linh for consulting on backend architecture, structured data systems, AI-native tooling, developer platforms, or technical writing engagements."
  },
  "sections": [
    {
      "id": "contact-page-hero",
      "type": "page-hero",
      "data": {
        "label": "Contact",
        "title": "Let’s talk about architecture, tooling, or writing",
        "description": "If you are working on a backend platform, a structured content system, or internal tooling that needs sharper contracts and clearer operational behavior, I would be glad to hear more."
      },
      "settings": { "theme": "dark" }
    },
    {
      "id": "contact-form-section",
      "type": "contact-form",
      "data": {
        "label": "Reach out",
        "title": "Project inquiries and editorial work",
        "description": "Share the problem space, current team shape, and what success would look like. Short notes are fine.",
        "email": "hello@andrewlinh.dev",
        "formNote": "Typical topics: architecture reviews, platform strategy, structured content modeling, AI agent tooling, and technical writing retainers.",
        "links": [
          { "id": "contact-link-1", "label": "GitHub", "href": "https://github.com/andrewlinh", "icon": "github" },
          { "id": "contact-link-2", "label": "LinkedIn", "href": "https://www.linkedin.com/in/andrewlinh", "icon": "linkedin" },
          { "id": "contact-link-3", "label": "RSS", "href": "/blog/rss.xml", "icon": "rss" }
        ]
      },
      "settings": { "theme": "dark" }
    },
    {
      "id": "contact-bio-panel",
      "type": "bio-panel",
      "data": {
        "label": "Working style",
        "title": "Calm collaboration, explicit decisions, written follow-through",
        "description": "I like engagements where architecture is discussed in enough detail to make trade-offs visible. That often means short discovery conversations, a clear document trail, and simple communication rhythms.",
        "image": {
          "url": "https://images.unsplash.com/photo-1497366754035-f200968a6e72?auto=format&fit=crop&w=900&q=80",
          "alt": "Minimal meeting space with laptop and notebook on a table"
        },
        "note": "Remote-friendly, async-friendly, and comfortable working with product, platform, and leadership stakeholders."
      },
      "settings": { "theme": "dark" }
    },
    {
      "id": "contact-final-cta",
      "type": "contact-cta",
      "data": {
        "label": "Availability",
        "title": "Open to focused consulting engagements and writing commissions",
        "description": "The best fit is usually a well-scoped systems problem with real business stakes and a team that values technical clarity.",
        "primaryCta": { "id": "contact-final-cta-1", "label": "Email Andrew", "href": "mailto:hello@andrewlinh.dev", "variant": "primary" },
        "secondaryCta": { "id": "contact-final-cta-2", "label": "Browse case studies", "href": "/work", "variant": "secondary" }
      },
      "settings": { "theme": "accent" }
    }
  ]
}

END_OF_FILE_CONTENT
echo "Creating src/data/pages/form.json..."
cat << 'END_OF_FILE_CONTENT' > "src/data/pages/form.json"
{
  "id": "form-page",
  "slug": "form",
  "meta": {
    "title": "Home",
    "description": "OlonJS tenant alpha — form smoke test"
  },
  "sections": [
    {
      "id": "form-demo-1",
      "type": "form-demo",
      "data": {
        "anchorId": "form-demo",
        "recipientEmail": "test@olonjs.io",
        "icon": "mail",
        "title": "contact us",
        "description": "Compila il modulo e ti risponderemo al più presto.",
        "submitLabel": "Invia",
        "successMessage": "Richiesta inviata con successo."
      }
    }
  ],
  "global-header": false
}
END_OF_FILE_CONTENT
echo "Creating src/data/pages/home.json..."
cat << 'END_OF_FILE_CONTENT' > "src/data/pages/home.json"
{
  "id": "home-page",
  "slug": "home",
  "meta": {
    "title": "Andrew Linh — Systems Architect and Technical Writer",
    "description": "Explore the portfolio and writing of Andrew Linh, a systems architect focused on backend platforms, structured data systems, developer tools, and AI-native infrastructure."
  },
  "sections": [
    {
      "id": "home-editorial-hero",
      "type": "editorial-hero",
      "data": {
        "label": "Andrew Linh",
        "title": "Systems architecture for products that need",
        "titleHighlight": "clarity under load.",
        "description": "I design backend platforms, structured data systems, and AI-native tooling with an emphasis on legibility, type safety, and operational calm.",
        "status": "Available for consulting in Q2",
        "primaryCta": { "id": "home-hero-cta-1", "label": "Start a conversation", "href": "/contact", "variant": "primary" },
        "secondaryCta": { "id": "home-hero-cta-2", "label": "See selected work", "href": "/work", "variant": "secondary" }
      },
      "settings": { "paddingTop": "xl", "paddingBottom": "lg", "theme": "dark" }
    },
    {
      "id": "home-featured-projects",
      "type": "featured-projects",
      "data": {
        "label": "Selected work",
        "title": "Case studies in backend architecture and system design",
        "description": "A small set of projects where the technical problem was clear, the architectural trade-offs mattered, and the outcome was measurable.",
        "items": { "$ref": "../collections/projects/projects.json" }
      },
      "settings": { "theme": "dark" }
    },
    {
      "id": "home-blog-rollup",
      "type": "blog-rollup",
      "data": {
        "label": "Latest writing",
        "title": "Notes on content systems, type contracts, and AI tooling",
        "description": "Recent essays from the editorial side of the practice.",
        "items": { "$ref": "../collections/posts/posts.json" }
      },
      "settings": { "theme": "dark" }
    },
    {
      "id": "home-bio-panel",
      "type": "bio-panel",
      "data": {
        "label": "Short bio",
        "title": "Technical depth, editorial discipline, and a bias toward calm systems",
        "description": "I work at the intersection of architecture and explanation. My background spans backend platform design, data contracts, and internal developer tooling. I care about making systems easier to reason about, not only faster to ship.",
        "image": {
          "url": "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=900&q=80",
          "alt": "Portrait of a technical professional in a dark studio setting"
        },
        "note": "Based in Europe, working globally across product, platform, and editorial teams."
      },
      "settings": { "theme": "dark" }
    },
    {
      "id": "home-contact-cta",
      "type": "contact-cta",
      "data": {
        "label": "Contact",
        "title": "Need an architect who can also write the system down clearly?",
        "description": "I help teams design backend platforms, developer-facing infrastructure, and structured content systems that remain understandable after launch.",
        "primaryCta": { "id": "home-contact-cta-1", "label": "Contact Andrew", "href": "/contact", "variant": "primary" },
        "secondaryCta": { "id": "home-contact-cta-2", "label": "Read the blog", "href": "/blog", "variant": "secondary" }
      },
      "settings": { "theme": "accent" }
    }
  ]
}

END_OF_FILE_CONTENT
mkdir -p "src/data/pages/libri"
echo "Creating src/data/pages/libri.json..."
cat << 'END_OF_FILE_CONTENT' > "src/data/pages/libri.json"
{
  "id": "libri-page",
  "slug": "libri",
  "meta": {
    "title": "Libri",
    "description": "Catalogo libri dimostrativo alimentato da COP collections."
  },
  "sections": [
    {
      "id": "books-list-1",
      "type": "books-list",
      "data": {
        "anchorId": "catalogo-libri",
        "eyebrow": "Collection demo",
        "title": "Libri",
        "description": "Una pagina collection con titoli, paginazione lato componente e filtro autore.",
        "items": {
          "$ref": "../collections/libri/libri.json"
        },
        "pageSize": 10
      }
    }
  ],
  "global-header": false
}
END_OF_FILE_CONTENT
echo "Creating src/data/pages/libri/[slug].json..."
cat << 'END_OF_FILE_CONTENT' > "src/data/pages/libri/[slug].json"
{
  "id": "libro-detail-page",
  "slug": "libri/[slug]",
  "meta": {
    "title": "Dettaglio libro",
    "description": "Pagina dinamica dettaglio libro alimentata dalla collection libri."
  },
  "sections": [
    {
      "id": "book-detail-1",
      "type": "book-detail",
      "data": {
        "anchorId": "dettaglio-libro",
        "item": {
          "$ref": "collection:current"
        },
        "backLabel": "← Torna ai libri"
      }
    }
  ],
  "collection": {
    "source": "libri",
    "paramKey": "slug"
  },
  "global-header": false
}
END_OF_FILE_CONTENT
echo "Creating src/data/pages/posts-detail.json..."
cat << 'END_OF_FILE_CONTENT' > "src/data/pages/posts-detail.json"
{
  "id": "posts-detail-page",
  "slug": "blog/[slug]",
  "collection": { "source": "posts", "paramKey": "slug" },
  "meta": {
    "title": "Article detail page for Andrew Linh technical writing",
    "description": "Long-form article detail page for Andrew Linh’s blog, with publication metadata, topic tags, related themes, and structured editorial content."
  },
  "sections": [
    {
      "id": "post-detail-section",
      "type": "post-detail",
      "data": { "item": { "$ref": "collection:current" } },
      "settings": { "theme": "dark" }
    }
  ]
}

END_OF_FILE_CONTENT
echo "Creating src/data/pages/projects-detail.json..."
cat << 'END_OF_FILE_CONTENT' > "src/data/pages/projects-detail.json"
{
  "id": "projects-detail-page",
  "slug": "work/[slug]",
  "collection": { "source": "projects", "paramKey": "slug" },
  "meta": {
    "title": "Project case study detail page for Andrew Linh portfolio",
    "description": "Detailed case study page for Andrew Linh’s architecture portfolio, including context, technical problem, architectural decision, delivery stack, and measurable outcomes."
  },
  "sections": [
    {
      "id": "project-detail-section",
      "type": "project-detail",
      "data": { "item": { "$ref": "collection:current" } },
      "settings": { "theme": "dark" }
    }
  ]
}

END_OF_FILE_CONTENT
echo "Creating src/data/pages/work.json..."
cat << 'END_OF_FILE_CONTENT' > "src/data/pages/work.json"
{
  "id": "work-page",
  "slug": "work",
  "meta": {
    "title": "Work — Case Studies in Backend and Data Architecture",
    "description": "Browse detailed project case studies by Andrew Linh covering backend platforms, data systems, AI tooling, and developer experience architecture."
  },
  "sections": [
    {
      "id": "work-page-hero",
      "type": "page-hero",
      "data": {
        "label": "Work",
        "title": "Project case studies with context, trade-offs, and measurable outcomes",
        "description": "Each project page documents the technical problem, the architecture decision, the stack involved, and the concrete business or operational result."
      },
      "settings": { "theme": "dark" }
    },
    {
      "id": "work-featured-projects",
      "type": "featured-projects",
      "data": {
        "label": "Case studies",
        "title": "Recent architecture engagements",
        "description": "Representative projects across data platforms, AI infrastructure, and developer-facing backend systems.",
        "items": { "$ref": "../collections/projects/projects.json" }
      },
      "settings": { "theme": "dark" }
    },
    {
      "id": "work-bio-panel",
      "type": "bio-panel",
      "data": {
        "label": "Approach",
        "title": "I document the architecture, not only the implementation",
        "description": "Good case studies should show why a system changed, which trade-offs were accepted, and how the outcome was measured. That same discipline improves delivery work itself.",
        "image": {
          "url": "https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=900&q=80",
          "alt": "Laptop and notebook on a minimalist desk in a dark office"
        },
        "note": "Available for architecture reviews, design systems for internal platforms, and technical writing around complex software."
      },
      "settings": { "theme": "dark" }
    },
    {
      "id": "work-contact-cta",
      "type": "contact-cta",
      "data": {
        "label": "Discuss a project",
        "title": "Have a platform problem that needs both architecture and explanation?",
        "description": "I work best on systems that are already important to the business and need to become more reliable, more legible, or easier for multiple teams to evolve.",
        "primaryCta": { "id": "work-contact-cta-1", "label": "Book an intro call", "href": "/contact", "variant": "primary" },
        "secondaryCta": { "id": "work-contact-cta-2", "label": "Read the blog", "href": "/blog", "variant": "secondary" }
      },
      "settings": { "theme": "accent" }
    }
  ]
}

END_OF_FILE_CONTENT
mkdir -p "src/emails"
echo "Creating src/emails/LeadNotificationEmail.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/emails/LeadNotificationEmail.tsx"
import React from "react";
import {
  Body,
  Button,
  Container,
  Head,
  Heading,
  Hr,
  Html,
  Img,
  Preview,
  Section,
  Text,
} from "@react-email/components";

type LeadData = Record<string, unknown>;

type EmailTheme = {
  colors?: {
    primary?: string;
    secondary?: string;
    accent?: string;
    background?: string;
    surface?: string;
    surfaceAlt?: string;
    text?: string;
    textMuted?: string;
    border?: string;
  };
  typography?: {
    fontFamily?: {
      primary?: string;
      display?: string;
      mono?: string;
    };
  };
  borderRadius?: {
    sm?: string;
    md?: string;
    lg?: string;
    xl?: string;
  };
};

export type LeadNotificationEmailProps = {
  tenantName: string;
  correlationId: string;
  replyTo?: string | null;
  leadData: LeadData;
  brandName?: string;
  logoUrl?: string;
  logoAlt?: string;
  tagline?: string;
  theme?: EmailTheme;
};

function safeString(value: unknown): string {
  if (value == null) return "-";
  if (typeof value === "string") {
    const trimmed = value.trim();
    return trimmed || "-";
  }
  return JSON.stringify(value);
}

function flattenLeadData(data: LeadData) {
  return Object.entries(data)
    .filter(([key]) => !key.startsWith("_"))
    .slice(0, 20)
    .map(([key, value]) => ({ label: key, value: safeString(value) }));
}

export function LeadNotificationEmail({
  tenantName,
  correlationId,
  replyTo,
  leadData,
  brandName,
  logoUrl,
  logoAlt,
  tagline,
  theme,
}: LeadNotificationEmailProps) {
  const fields = flattenLeadData(leadData);
  const brandLabel = brandName || tenantName;

  const colors = {
    primary: theme?.colors?.primary || "#2D5016",
    background: theme?.colors?.background || "#FAFAF5",
    surface: theme?.colors?.surface || "#FFFFFF",
    text: theme?.colors?.text || "#1C1C14",
    textMuted: theme?.colors?.textMuted || "#5A5A4A",
    border: theme?.colors?.border || "#D8D5C5",
  };

  const fonts = {
    primary: theme?.typography?.fontFamily?.primary || "Inter, Arial, sans-serif",
    display: theme?.typography?.fontFamily?.display || "Georgia, serif",
  };

  const radius = {
    md: theme?.borderRadius?.md || "10px",
    lg: theme?.borderRadius?.lg || "16px",
  };

  return (
    <Html>
      <Head />
      <Preview>Nuovo lead ricevuto da {brandLabel}</Preview>
      <Body style={{ backgroundColor: colors.background, color: colors.text, fontFamily: fonts.primary, padding: "24px" }}>
        <Container style={{ backgroundColor: colors.surface, border: `1px solid ${colors.border}`, borderRadius: radius.lg, padding: "24px" }}>
          <Section>
            {logoUrl ? <Img src={logoUrl} alt={logoAlt || brandLabel} height="44" style={{ marginBottom: "8px" }} /> : null}
            <Text style={{ color: colors.text, fontSize: "18px", fontWeight: 700, margin: "0 0 6px 0" }}>{brandLabel}</Text>
            <Text style={{ color: colors.textMuted, marginTop: "0", marginBottom: "0" }}>{tagline || "Notifica automatica lead"}</Text>
          </Section>

          <Hr style={{ borderColor: colors.border, margin: "20px 0" }} />

          <Heading as="h2" style={{ color: colors.text, margin: "0 0 12px 0", fontSize: "22px", fontFamily: fonts.display }}>
            Nuovo lead da {tenantName}
          </Heading>
          <Text style={{ color: colors.textMuted, marginTop: "0", marginBottom: "16px" }}>Correlation ID: {correlationId}</Text>

          <Section style={{ border: `1px solid ${colors.border}`, borderRadius: radius.md, padding: "12px" }}>
            {fields.length === 0 ? (
              <Text style={{ color: colors.textMuted, margin: 0 }}>Nessun campo lead disponibile.</Text>
            ) : (
              fields.map((field) => (
                <Text key={field.label} style={{ margin: "0 0 8px 0", color: colors.text, fontSize: "14px", wordBreak: "break-word" }}>
                  <strong>{field.label}:</strong> {field.value}
                </Text>
              ))
            )}
          </Section>

          <Section style={{ marginTop: "18px" }}>
            <Button
              href={replyTo ? `mailto:${replyTo}` : "mailto:"}
              style={{
                backgroundColor: colors.primary,
                color: "#ffffff",
                borderRadius: radius.md,
                textDecoration: "none",
                padding: "12px 18px",
                fontWeight: 600,
              }}
            >
              Rispondi ora
            </Button>
          </Section>
        </Container>
      </Body>
    </Html>
  );
}

export default LeadNotificationEmail;

END_OF_FILE_CONTENT
echo "Creating src/emails/LeadSenderConfirmationEmail.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/emails/LeadSenderConfirmationEmail.tsx"
import React from "react";
import {
  Body,
  Container,
  Head,
  Heading,
  Hr,
  Html,
  Img,
  Preview,
  Section,
  Text,
} from "@react-email/components";

type LeadData = Record<string, unknown>;

type EmailTheme = {
  colors?: {
    primary?: string;
    secondary?: string;
    accent?: string;
    background?: string;
    surface?: string;
    surfaceAlt?: string;
    text?: string;
    textMuted?: string;
    border?: string;
  };
  typography?: {
    fontFamily?: {
      primary?: string;
      display?: string;
      mono?: string;
    };
  };
  borderRadius?: {
    sm?: string;
    md?: string;
    lg?: string;
    xl?: string;
  };
};

export type LeadSenderConfirmationEmailProps = {
  tenantName: string;
  correlationId: string;
  leadData: LeadData;
  brandName?: string;
  logoUrl?: string;
  logoAlt?: string;
  tagline?: string;
  theme?: EmailTheme;
};

function safeString(value: unknown): string {
  if (value == null) return "-";
  if (typeof value === "string") {
    const trimmed = value.trim();
    return trimmed || "-";
  }
  return JSON.stringify(value);
}

function flattenLeadData(data: LeadData) {
  const skipKeys = new Set(["recipientEmail", "tenant", "source", "submittedAt", "email_confirm"]);
  return Object.entries(data)
    .filter(([key]) => !key.startsWith("_") && !skipKeys.has(key))
    .slice(0, 12)
    .map(([key, value]) => ({ label: key, value: safeString(value) }));
}

export function LeadSenderConfirmationEmail({
  tenantName,
  correlationId,
  leadData,
  brandName,
  logoUrl,
  logoAlt,
  tagline,
  theme,
}: LeadSenderConfirmationEmailProps) {
  const fields = flattenLeadData(leadData);
  const brandLabel = brandName || tenantName;

  const colors = {
    primary: theme?.colors?.primary || "#2D5016",
    background: theme?.colors?.background || "#FAFAF5",
    surface: theme?.colors?.surface || "#FFFFFF",
    text: theme?.colors?.text || "#1C1C14",
    textMuted: theme?.colors?.textMuted || "#5A5A4A",
    border: theme?.colors?.border || "#D8D5C5",
  };

  const fonts = {
    primary: theme?.typography?.fontFamily?.primary || "Inter, Arial, sans-serif",
    display: theme?.typography?.fontFamily?.display || "Georgia, serif",
  };

  const radius = {
    md: theme?.borderRadius?.md || "10px",
    lg: theme?.borderRadius?.lg || "16px",
  };

  return (
    <Html>
      <Head />
      <Preview>Conferma invio richiesta - {brandLabel}</Preview>
      <Body style={{ backgroundColor: colors.background, color: colors.background, fontFamily: fonts.primary, padding: "24px" }}>
        <Container style={{ backgroundColor: colors.primary, color: colors.background, border: `1px solid ${colors.border}`, borderRadius: radius.lg, padding: "24px" }}>
          <Section>
            {logoUrl ? <Img src={logoUrl} alt={logoAlt || brandLabel} height="44" style={{ marginBottom: "8px" }} /> : null}
            <Text style={{ color: colors.background, fontSize: "18px", fontWeight: 700, margin: "0 0 6px 0" }}>{brandLabel}</Text>
            <Text style={{ color: colors.background, marginTop: "0", marginBottom: "0" }}>{tagline || "Conferma automatica di ricezione"}</Text>
          </Section>

          <Hr style={{ borderColor: colors.border, margin: "20px 0" }} />

          <Heading as="h2" style={{ color: colors.background, margin: "0 0 12px 0", fontSize: "22px", fontFamily: fonts.display }}>
            Richiesta ricevuta
          </Heading>
          <Text style={{ color: colors.background, marginTop: "0", marginBottom: "16px" }}>
            Grazie, abbiamo ricevuto la tua richiesta per {tenantName}. Ti risponderemo il prima possibile.
          </Text>

          <Section style={{ border: `1px solid ${colors.border}`, borderRadius: radius.md, padding: "12px" }}>
            <Text style={{ margin: "0 0 8px 0", color: colors.background, fontWeight: 600 }}>Riepilogo inviato</Text>
            {fields.length === 0 ? (
              <Text style={{ color: colors.background, margin: 0 }}>Nessun dettaglio disponibile.</Text>
            ) : (
              fields.map((field) => (
                <Text key={field.label} style={{ margin: "0 0 8px 0", color: colors.background, fontSize: "14px", wordBreak: "break-word" }}>
                  <strong>{field.label}:</strong> {field.value}
                </Text>
              ))
            )}
          </Section>

          <Hr style={{ borderColor: colors.border, margin: "20px 0 12px 0" }} />
          <Text style={{ color: colors.background, fontSize: "12px", margin: 0 }}>Riferimento richiesta: {correlationId}</Text>
        </Container>
      </Body>
    </Html>
  );
}

export default LeadSenderConfirmationEmail;

END_OF_FILE_CONTENT
echo "Creating src/entry-ssg.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/entry-ssg.tsx"
import { renderToString } from 'react-dom/server';
import { StaticRouter } from 'react-router-dom/server';
import {
  ConfigProvider,
  PageRenderer,
  StudioProvider,
  contract,
  resolvePageMatchFromRegistry,
  resolveRuntimeConfig,
} from '@olonjs/core';
import type { JsonPagesConfig, PageConfig, SiteConfig, ThemeConfig } from '@/types';
import { ThemeProvider } from '@/components/ThemeProvider';
import { ComponentRegistry } from '@/lib/ComponentRegistry';
import { SECTION_SCHEMAS } from '@/lib/schemas';
import { collectionSchemas, collections, menuConfig, pages, refDocuments, siteConfig, themeConfig } from '@/runtime';
import tenantCss from '@/index.css?inline';

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function normalizeSlug(input: string): string {
  return input.trim().toLowerCase().replace(/\\/g, '/').replace(/^\/+|\/+$/g, '');
}

function getSortedSlugs(): string[] {
  return Object.keys(pages).sort((a, b) => a.localeCompare(b));
}

function resolvePage(slug: string): { slug: string; registrySlug: string; page: PageConfig; params: Record<string, string> } {
  const normalized = normalizeSlug(slug);
  const pageMatch = resolvePageMatchFromRegistry(pages, normalized);
  if (pageMatch) {
    return {
      slug: normalized || pageMatch.registrySlug,
      registrySlug: pageMatch.registrySlug,
      page: pageMatch.page,
      params: pageMatch.params,
    };
  }

  const slugs = getSortedSlugs();
  if (slugs.length === 0) {
    throw new Error('[SSG_CONFIG_ERROR] No pages found under src/data/pages');
  }

  const home = slugs.find((item) => item === 'home');
  const fallbackSlug = home ?? slugs[0];
  return { slug: fallbackSlug, registrySlug: fallbackSlug, page: pages[fallbackSlug], params: {} };
}

function flattenThemeTokens(
  input: unknown,
  pathSegments: string[] = [],
  out: Array<{ name: string; value: string }> = []
): Array<{ name: string; value: string }> {
  if (typeof input === 'string') {
    const cleaned = input.trim();
    if (cleaned.length > 0 && pathSegments.length > 0) {
      out.push({ name: `--theme-${pathSegments.join('-')}`, value: cleaned });
    }
    return out;
  }

  if (!isRecord(input)) return out;

  const entries = Object.entries(input).sort(([a], [b]) => a.localeCompare(b));
  for (const [key, value] of entries) {
    flattenThemeTokens(value, [...pathSegments, key], out);
  }
  return out;
}

function buildThemeCssFromSot(theme: ThemeConfig): string {
  const root: Record<string, unknown> = isRecord(theme) ? theme : {};
  const tokens = root['tokens'];
  const flattened = flattenThemeTokens(tokens);
  if (flattened.length === 0) return '';
  const serialized = flattened.map((item) => `${item.name}:${item.value}`).join(';');
  return `:root{${serialized}}`;
}

function isRemoteStylesheetHref(value: string): boolean {
  return /^https?:\/\//i.test(value.trim());
}

function extractLeadingRemoteCssImports(cssText: string): { hrefs: string[]; rest: string } {
  const hrefs = new Set<string>();
  const leadingTriviaPattern = /^(?:\s+|\/\*[\s\S]*?\*\/)*/;
  const importPattern =
    /^@import(?:\s+url\(\s*(?:'([^']+)'|"([^"]+)"|([^'")\s][^)]*))\s*\)|\s*(['"])([^'"]+)\4)\s*([^;]*);/i;
  let rest = cssText;

  for (;;) {
    const trivia = rest.match(leadingTriviaPattern);
    if (trivia && trivia[0]) {
      rest = rest.slice(trivia[0].length);
    }

    const match = rest.match(importPattern);
    if (!match) break;

    const href = (match[1] ?? match[2] ?? match[3] ?? match[5] ?? '').trim();
    const trailingDirectives = (match[6] ?? '').trim();
    if (!isRemoteStylesheetHref(href) || trailingDirectives.length > 0) {
      break;
    }

    hrefs.add(href);
    rest = rest.slice(match[0].length);
  }

  return { hrefs: Array.from(hrefs), rest };
}

function resolveTenantId(): string {
  const site: Record<string, unknown> = isRecord(siteConfig) ? siteConfig : {};
  const identityRaw = site['identity'];
  const identity: Record<string, unknown> = isRecord(identityRaw) ? identityRaw : {};
  const titleRaw = typeof identity.title === 'string' ? identity.title : '';
  const title = titleRaw.trim();
  if (title.length > 0) {
    const normalized = title.toLowerCase().replace(/[^a-z0-9-]+/g, '-').replace(/^-+|-+$/g, '');
    if (normalized.length > 0) return normalized;
  }

  const slugs = getSortedSlugs();
  if (slugs.length === 0) {
    throw new Error('[SSG_CONFIG_ERROR] Cannot resolve tenantId without site.identity.title or pages');
  }
  return slugs[0].replace(/\//g, '-');
}

export function render(slug: string): string {
  const resolved = resolvePage(slug);
  const location = resolved.slug === 'home' ? '/' : `/${resolved.slug}`;
  const collectionContext = contract.resolveCollectionContext(resolved.page, resolved.params, collections);
  const resolvedRuntime = resolveRuntimeConfig({
    pages: { [resolved.registrySlug]: resolved.page },
    siteConfig,
    themeConfig,
    menuConfig,
    collections,
    collectionSchemas,
    collectionContext,
    refDocuments,
  });
  const resolvedPage = resolvedRuntime.pages[resolved.registrySlug] ?? resolved.page;

  return renderToString(
    <StaticRouter location={location}>
      <ConfigProvider
        config={{
          registry: ComponentRegistry as JsonPagesConfig['registry'],
          schemas: SECTION_SCHEMAS as unknown as JsonPagesConfig['schemas'],
          tenantId: resolveTenantId(),
        }}
      >
        <StudioProvider mode="visitor">
          <ThemeProvider>
            <PageRenderer
              pageConfig={resolvedPage}
              siteConfig={resolvedRuntime.siteConfig}
              menuConfig={resolvedRuntime.menuConfig}
            />
          </ThemeProvider>
        </StudioProvider>
      </ConfigProvider>
    </StaticRouter>
  );
}

export function getCss(): string {
  const themeCss = buildThemeCssFromSot(themeConfig);
  const { rest } = extractLeadingRemoteCssImports(tenantCss);
  if (!themeCss) return rest;
  return `${themeCss}\n${rest}`;
}

export function getRemoteStylesheets(): string[] {
  return extractLeadingRemoteCssImports(tenantCss).hrefs;
}

export function getPageMeta(slug: string): { title: string; description: string } {
  const resolved = resolvePage(slug);
  const rawMeta = isRecord((resolved.page as unknown as { meta?: unknown }).meta)
    ? ((resolved.page as unknown as { meta?: Record<string, unknown> }).meta as Record<string, unknown>)
    : {};

  const title = typeof rawMeta.title === 'string' ? rawMeta.title : resolved.slug;
  const description = typeof rawMeta.description === 'string' ? rawMeta.description : '';
  return { title, description };
}

export function getWebMcpBuildState(): {
  pages: Record<string, PageConfig>;
  schemas: JsonPagesConfig['schemas'];
  collections: JsonPagesConfig['collections'];
  collectionSchemas: JsonPagesConfig['collectionSchemas'];
  siteConfig: SiteConfig;
  themeConfig: ThemeConfig;
  menuConfig: JsonPagesConfig['menuConfig'];
  refDocuments: JsonPagesConfig['refDocuments'];
} {
  return {
    pages,
    schemas: SECTION_SCHEMAS as unknown as JsonPagesConfig['schemas'],
    collections,
    collectionSchemas,
    siteConfig,
    themeConfig,
    menuConfig,
    refDocuments,
  };
}

END_OF_FILE_CONTENT
echo "Creating src/fonts.css..."
cat << 'END_OF_FILE_CONTENT' > "src/fonts.css"
@import url('https://fonts.googleapis.com/css2?family=Instrument+Sans:ital,wght@0,400;0,500;0,600;0,700;1,400&family=JetBrains+Mono:wght@400;500&display=swap');

END_OF_FILE_CONTENT
mkdir -p "src/hooks"
echo "Creating src/hooks/useDocumentMeta.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/hooks/useDocumentMeta.ts"
import { useEffect } from 'react';
import type { PageMeta } from '@/types';

export const useDocumentMeta = (meta: PageMeta): void => {
  useEffect(() => {
    // Set document title
    document.title = meta.title;

    // Set or update meta description
    let metaDescription = document.querySelector('meta[name="description"]');
    if (!metaDescription) {
      metaDescription = document.createElement('meta');
      metaDescription.setAttribute('name', 'description');
      document.head.appendChild(metaDescription);
    }
    metaDescription.setAttribute('content', meta.description);
  }, [meta.title, meta.description]);
};





END_OF_FILE_CONTENT
echo "Creating src/index.css..."
cat << 'END_OF_FILE_CONTENT' > "src/index.css"
@import url('');
@import "tailwindcss";
@source "./**/*.tsx";

@theme {
  --color-background:           var(--background);
  --color-foreground:           var(--foreground);
  --color-card:                 var(--card);
  --color-card-foreground:      var(--card-foreground);
  --color-primary:              var(--primary);
  --color-primary-foreground:   var(--primary-foreground);
  --color-secondary:            var(--secondary);
  --color-secondary-foreground: var(--secondary-foreground);
  --color-muted:                var(--muted);
  --color-muted-foreground:     var(--muted-foreground);
  --color-accent:               var(--accent);
  --color-border:               var(--border);
  --radius-lg:                  var(--theme-radius-lg);
  --radius-md:                  var(--theme-radius-md);
  --radius-sm:                  var(--theme-radius-sm);
  --font-primary: var(--theme-font-primary);
  --font-mono:    var(--theme-font-mono);
  --font-display: var(--theme-font-display);
}

:root {
  --background:           var(--theme-colors-background);
  --foreground:           var(--theme-colors-foreground);
  --card:                 var(--theme-colors-card);
  --card-foreground:      var(--theme-colors-card-foreground);
  --elevated:             var(--theme-colors-elevated);
  --overlay:              var(--theme-colors-overlay);
  --primary:              var(--theme-colors-primary);
  --primary-foreground:   var(--theme-colors-primary-foreground);
  --primary-light:        var(--theme-colors-primary-light);
  --primary-dark:         var(--theme-colors-primary-dark);
  --secondary:            var(--theme-colors-secondary);
  --secondary-foreground: var(--theme-colors-secondary-foreground);
  --muted:                var(--theme-colors-muted);
  --muted-foreground:     var(--theme-colors-muted-foreground);
  --accent:               var(--theme-colors-accent);
  --accent-foreground:    var(--theme-colors-accent-foreground);
  --border:               var(--theme-colors-border);
  --border-strong:        var(--theme-colors-border-strong);
  --input:                var(--theme-colors-input);
  --ring:                 var(--theme-colors-ring);
  --destructive:          var(--theme-colors-destructive);
  --destructive-foreground: var(--theme-colors-destructive-foreground);
  --success:              var(--theme-colors-success);
  --success-foreground:   var(--theme-colors-success-foreground);
  --warning:              var(--theme-colors-warning);
  --warning-foreground:   var(--theme-colors-warning-foreground);
  --info:                 var(--theme-colors-info);
  --info-foreground:      var(--theme-colors-info-foreground);
  --radius:               var(--theme-radius-lg);

  --demo-surface:         color-mix(in oklch, var(--card) 86%, var(--background));
  --demo-surface-soft:    color-mix(in oklch, var(--card) 72%, var(--background));
  --demo-surface-strong:  color-mix(in oklch, var(--background) 82%, black);
  --demo-surface-deep:    color-mix(in oklch, var(--background) 70%, black);
  --demo-border-soft:     color-mix(in oklch, var(--foreground) 8%, transparent);
  --demo-border-strong:   color-mix(in oklch, var(--primary) 24%, transparent);
  --demo-accent-soft:     color-mix(in oklch, var(--primary) 10%, transparent);
  --demo-accent-strong:   color-mix(in oklch, var(--primary) 18%, transparent);
  --demo-text-soft:       color-mix(in oklch, var(--foreground) 88%, var(--muted-foreground));
  --demo-text-faint:      color-mix(in oklch, var(--muted-foreground) 72%, transparent);
}

[data-theme="light"] {
  --background:           var(--theme-modes-light-colors-background);
  --foreground:           var(--theme-modes-light-colors-foreground);
  --card:                 var(--theme-modes-light-colors-card);
  --card-foreground:      var(--theme-modes-light-colors-card-foreground);
  --elevated:             var(--theme-modes-light-colors-elevated);
  --overlay:              var(--theme-modes-light-colors-overlay);
  --primary:              var(--theme-modes-light-colors-primary);
  --primary-foreground:   var(--theme-modes-light-colors-primary-foreground);
  --primary-light:        var(--theme-modes-light-colors-primary-light);
  --primary-dark:         var(--theme-modes-light-colors-primary-dark);
  --secondary:            var(--theme-modes-light-colors-secondary);
  --secondary-foreground: var(--theme-modes-light-colors-secondary-foreground);
  --muted:                var(--theme-modes-light-colors-muted);
  --muted-foreground:     var(--theme-modes-light-colors-muted-foreground);
  --accent:               var(--theme-modes-light-colors-accent);
  --accent-foreground:    var(--theme-modes-light-colors-accent-foreground);
  --border:               var(--theme-modes-light-colors-border);
  --border-strong:        var(--theme-modes-light-colors-border-strong);
  --input:                var(--theme-modes-light-colors-input);
  --ring:                 var(--theme-modes-light-colors-ring);
  --destructive:          var(--theme-modes-light-colors-destructive);
  --destructive-foreground: var(--theme-modes-light-colors-destructive-foreground);
  --success:              var(--theme-modes-light-colors-success);
  --success-foreground:   var(--theme-modes-light-colors-success-foreground);
  --warning:              var(--theme-modes-light-colors-warning);
  --warning-foreground:   var(--theme-modes-light-colors-warning-foreground);
  --info:                 var(--theme-modes-light-colors-info);
  --info-foreground:      var(--theme-modes-light-colors-info-foreground);
}

@layer base {
  * { border-color: var(--border); }
  html { scroll-behavior: smooth; }
  body {
    background-color: var(--background);
    color: var(--foreground);
    font-family: var(--font-primary);
    line-height: 1.7;
    overflow-x: hidden;
    @apply antialiased;
  }
  h1, h2, h3, h4, h5, h6 {
    font-family: var(--font-display, var(--font-primary));
    letter-spacing: -0.02em;
  }
  code, pre, kbd, samp {
    font-family: var(--font-mono);
  }
}

.font-display {
  font-family: var(--font-display, var(--font-primary));
}

.font-primary {
  font-family: var(--font-primary);
}

.font-mono {
  font-family: var(--font-mono);
}

.prose-terminal {
  color: var(--foreground);
}

.prose-terminal p {
  color: var(--demo-text-soft);
}

.prose-terminal strong {
  color: var(--foreground);
}

.prose-terminal a {
  color: var(--primary);
  text-decoration: underline;
  text-decoration-color: color-mix(in oklch, var(--primary) 40%, transparent);
  text-underline-offset: 0.2em;
}

.prose-terminal code {
  background: var(--demo-surface);
  border: 1px solid var(--demo-border-soft);
  border-radius: var(--theme-radius-sm);
  padding: 0.12rem 0.35rem;
}

.jp-chip {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  border: 1px solid var(--demo-border-soft);
  background: color-mix(in oklch, var(--card) 76%, transparent);
  border-radius: 9999px;
  padding: 0.45rem 0.85rem;
  font-family: var(--font-mono);
  font-size: 0.72rem;
  font-weight: 600;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--muted-foreground);
}

.jp-meta {
  font-family: var(--font-mono);
  font-size: 0.74rem;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--muted-foreground);
}

@keyframes jp-fadeUp {
  from { opacity: 0; transform: translateY(20px); }
  to   { opacity: 1; transform: translateY(0); }
}
.jp-animate-in { opacity: 0; animation: jp-fadeUp 0.7s ease forwards; }
.jp-d1 { animation-delay: 0.1s; }
.jp-d2 { animation-delay: 0.2s; }
.jp-d3 { animation-delay: 0.3s; }
.jp-d4 { animation-delay: 0.4s; }

@keyframes jp-pulseDot {
  0%, 100% { opacity: 1; transform: scale(1); }
  50% { opacity: 0.5; transform: scale(0.85); }
}
.jp-pulse-dot { animation: jp-pulseDot 2s ease infinite; }

[data-jp-section-overlay] {
  position: absolute; inset: 0; z-index: 9999;
  pointer-events: none; border: 2px solid transparent;
  transition: border-color 0.15s, background-color 0.15s;
}
[data-section-id]:hover [data-jp-section-overlay] {
  border: 2px dashed color-mix(in oklch, var(--primary) 50%, transparent);
  background-color: color-mix(in oklch, var(--primary) 6%, transparent);
}
[data-section-id][data-jp-selected] [data-jp-section-overlay] {
  border: 2px solid var(--primary);
  background-color: color-mix(in oklch, var(--primary) 10%, transparent);
}
[data-jp-section-overlay] > div {
  position: absolute; top: 0; right: 0;
  padding: 0.2rem 0.55rem;
  font-size: 9px; font-weight: 800;
  text-transform: uppercase; letter-spacing: 0.1em;
  background: var(--primary); color: #fff;
  opacity: 0; transition: opacity 0.15s;
}
[data-section-id]:hover [data-jp-section-overlay] > div,
[data-section-id][data-jp-selected] [data-jp-section-overlay] > div { opacity: 1; }

END_OF_FILE_CONTENT
mkdir -p "src/lib"
echo "Creating src/lib/CollectionRegistry.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/CollectionRegistry.ts"
import { ProjectsCollectionSchema } from '@/collections/projects';
import { PostsCollectionSchema } from '@/collections/posts';

export const CollectionRegistry = {
  projects: ProjectsCollectionSchema,
  posts: PostsCollectionSchema
} as const;

export type CollectionType = keyof typeof CollectionRegistry;

END_OF_FILE_CONTENT
echo "Creating src/lib/ComponentRegistry.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/ComponentRegistry.tsx"
import React from 'react';
import { Header } from '@/components/header';
import { Footer } from '@/components/footer';
import { EditorialHero } from '@/components/editorial-hero';
import { PageHero } from '@/components/page-hero';
import { FeaturedProjects } from '@/components/featured-projects';
import { BlogRollup } from '@/components/blog-rollup';
import { BioPanel } from '@/components/bio-panel';
import { ContactCta } from '@/components/contact-cta';
import { Timeline } from '@/components/timeline';
import { SkillsGrid } from '@/components/skills-grid';
import { Philosophy } from '@/components/philosophy';
import { ContactForm } from '@/components/contact-form';
import { ProjectDetail } from '@/components/project-detail';
import { PostDetail } from '@/components/post-detail';

import type { SectionType } from '@olonjs/core';
import type { SectionComponentPropsMap } from '@/types';

export const ComponentRegistry: {
  [K in SectionType]: React.FC<SectionComponentPropsMap[K]>;
} = {
  'header': Header,
  'footer': Footer,
  'editorial-hero': EditorialHero,
  'page-hero': PageHero,
  'featured-projects': FeaturedProjects,
  'blog-rollup': BlogRollup,
  'bio-panel': BioPanel,
  'contact-cta': ContactCta,
  'timeline': Timeline,
  'skills-grid': SkillsGrid,
  'philosophy': Philosophy,
  'contact-form': ContactForm,
  'project-detail': ProjectDetail,
  'post-detail': PostDetail
};

END_OF_FILE_CONTENT
echo "Creating src/lib/IconResolver.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/IconResolver.tsx"
import type { LucideIcon } from 'lucide-react';
import {
  Braces,
  Database,
  Server,
  Cpu,
  Workflow,
  Github,
  Linkedin,
  Rss,
  Mail
} from 'lucide-react';

export const iconMap: Record<string, LucideIcon> = {
  braces: Braces,
  database: Database,
  server: Server,
  cpu: Cpu,
  workflow: Workflow,
  github: Github,
  linkedin: Linkedin,
  rss: Rss,
  mail: Mail
};

export const IconResolver = iconMap;

END_OF_FILE_CONTENT
echo "Creating src/lib/addSectionConfig.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/addSectionConfig.ts"
import type { AddSectionConfig } from '@olonjs/core';

const addableSectionTypes = [
  'editorial-hero',
  'page-hero',
  'featured-projects',
  'blog-rollup',
  'bio-panel',
  'contact-cta',
  'timeline',
  'skills-grid',
  'philosophy',
  'contact-form',
  'project-detail',
  'post-detail'
] as const;

const sectionTypeLabels: Record<string, string> = {
  'editorial-hero': 'Editorial Hero',
  'page-hero': 'Page Hero',
  'featured-projects': 'Featured Projects',
  'blog-rollup': 'Blog Rollup',
  'bio-panel': 'Bio Panel',
  'contact-cta': 'Contact CTA',
  'timeline': 'Timeline',
  'skills-grid': 'Skills Grid',
  'philosophy': 'Philosophy',
  'contact-form': 'Contact Form',
  'project-detail': 'Project Detail',
  'post-detail': 'Post Detail'
};

function getDefaultSectionData(type: string): Record<string, unknown> {
  switch (type) {
    case 'editorial-hero':
      return { title: 'Systems architecture with editorial clarity', description: 'I design backend platforms and write about structured data systems.', primaryCta: { id: 'cta-1', label: 'Get in touch', href: '/contact', variant: 'primary' } };
    case 'page-hero':
      return { title: 'Page title', description: 'Page introduction.' };
    case 'featured-projects':
      return { title: 'Selected work', items: {} };
    case 'blog-rollup':
      return { title: 'Latest writing', items: {} };
    case 'bio-panel':
      return { title: 'About Andrew', description: 'Short biography.' };
    case 'contact-cta':
      return { title: 'Start a conversation', description: 'Reach out for consulting or writing work.' };
    case 'timeline':
      return { title: 'Experience', items: [] };
    case 'skills-grid':
      return { title: 'Technical stack', items: [] };
    case 'philosophy':
      return { title: 'Design principles', items: [] };
    case 'contact-form':
      return { title: 'Contact', description: 'Send a note.', email: 'hello@andrewlinh.dev', links: [] };
    case 'project-detail':
      return {};
    case 'post-detail':
      return {};
    default:
      return {};
  }
}

export const addSectionConfig: AddSectionConfig = {
  addableSectionTypes: [...addableSectionTypes],
  sectionTypeLabels,
  getDefaultSectionData
};

END_OF_FILE_CONTENT
echo "Creating src/lib/assetUpload.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/assetUpload.ts"
import { withBasePath } from '@olonjs/core';
import { backoffDelayMs, isRetryableStatus, sleep } from '@/lib/cloud/cloudHttp';

const MAX_UPLOAD_SIZE_BYTES = 5 * 1024 * 1024;
const ASSET_UPLOAD_MAX_RETRIES = 2;
const ASSET_UPLOAD_TIMEOUT_MS = 20_000;
const ALLOWED_IMAGE_MIME_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/avif']);

function resolveImageMimeType(file: File): string {
  if (file.type.startsWith('image/')) return file.type;
  const ext = file.name.split('.').pop()?.toLowerCase();
  const byExt: Record<string, string> = {
    jpg: 'image/jpeg',
    jpeg: 'image/jpeg',
    png: 'image/png',
    webp: 'image/webp',
    gif: 'image/gif',
    avif: 'image/avif',
  };
  return ext ? (byExt[ext] ?? '') : '';
}

export function normalizeUploadedAssetUrl(rawUrl: string, basePath: string): string {
  const trimmed = rawUrl.trim();
  if (!trimmed) return trimmed;
  if (/^(?:https?:)?\/\//i.test(trimmed) || /^data:/i.test(trimmed)) return trimmed;
  const normalizedPath = trimmed.startsWith('/') ? trimmed : `/${trimmed}`;
  return withBasePath(normalizedPath, basePath);
}

async function normalizeImageForRendering(file: File): Promise<File> {
  if (typeof window === 'undefined') return file;
  const mimeType = resolveImageMimeType(file);
  if (!mimeType.startsWith('image/')) return file;

  const objectUrl = URL.createObjectURL(file);
  try {
    const imageEl = await new Promise<HTMLImageElement>((resolve, reject) => {
      const img = new Image();
      img.decoding = 'async';
      img.onload = () => resolve(img);
      img.onerror = () => reject(new Error('Image decode failed before upload.'));
      img.src = objectUrl;
    });

    const width = imageEl.naturalWidth;
    const height = imageEl.naturalHeight;
    if (!width || !height) throw new Error('Image decode failed before upload.');

    const canvas = document.createElement('canvas');
    canvas.width = width;
    canvas.height = height;
    const ctx = canvas.getContext('2d');
    if (!ctx) throw new Error('Canvas context unavailable.');
    ctx.drawImage(imageEl, 0, 0);

    const blob =
      await new Promise<Blob | null>((resolve) => canvas.toBlob((value) => resolve(value), 'image/webp', 0.92))
      ?? await new Promise<Blob | null>((resolve) => canvas.toBlob((value) => resolve(value), 'image/jpeg', 0.92));

    if (!blob) throw new Error('Image re-encode failed.');
    const baseName = file.name.replace(/\.[^.]+$/, '') || `image-${Date.now()}`;
    const ext = blob.type === 'image/webp' ? 'webp' : 'jpg';
    return new File([blob], `${baseName}.${ext}`, {
      type: blob.type,
      lastModified: Date.now(),
    });
  } finally {
    URL.revokeObjectURL(objectUrl);
  }
}

export async function uploadTenantAsset(
  file: File,
  options: {
    basePath: string;
    isCloudMode: boolean;
    cloudApiUrl?: string;
    cloudApiKey?: string;
    apiBases: string[];
    onUploaded?: () => Promise<void>;
  }
): Promise<string> {
  const preparedFile = await normalizeImageForRendering(file);
  const mimeType = resolveImageMimeType(preparedFile);
  if (!mimeType) throw new Error('Invalid file type.');
  if (!ALLOWED_IMAGE_MIME_TYPES.has(mimeType)) {
    throw new Error('Unsupported image format. Allowed: jpeg, png, webp, gif, avif.');
  }
  if (preparedFile.size > MAX_UPLOAD_SIZE_BYTES) {
    throw new Error(`File too large. Max ${MAX_UPLOAD_SIZE_BYTES / 1024 / 1024}MB.`);
  }

  if (options.isCloudMode && options.cloudApiUrl && options.cloudApiKey) {
    let lastError: Error | null = null;
    for (const apiBase of options.apiBases) {
      for (let attempt = 0; attempt <= ASSET_UPLOAD_MAX_RETRIES; attempt += 1) {
        try {
          const formData = new FormData();
          formData.append('file', preparedFile);
          formData.append('filename', preparedFile.name);
          const controller = new AbortController();
          const timeout = window.setTimeout(() => controller.abort(), ASSET_UPLOAD_TIMEOUT_MS);
          const res = await fetch(`${apiBase}/assets/upload`, {
            method: 'POST',
            headers: {
              Authorization: `Bearer ${options.cloudApiKey}`,
              'X-Correlation-Id': crypto.randomUUID(),
            },
            body: formData,
            signal: controller.signal,
          }).finally(() => window.clearTimeout(timeout));
          const body = (await res.json().catch(() => ({}))) as { url?: string; error?: string; code?: string };
          if (res.ok && typeof body.url === 'string') {
            await options.onUploaded?.().catch(() => undefined);
            return normalizeUploadedAssetUrl(body.url, options.basePath);
          }
          lastError = new Error(body.error || body.code || `Cloud upload failed: ${res.status}`);
          if (isRetryableStatus(res.status) && attempt < ASSET_UPLOAD_MAX_RETRIES) {
            await sleep(backoffDelayMs(attempt));
            continue;
          }
          break;
        } catch (error: unknown) {
          const message = error instanceof Error ? error.message : 'Cloud upload failed.';
          lastError = new Error(message);
          if (attempt < ASSET_UPLOAD_MAX_RETRIES) {
            await sleep(backoffDelayMs(attempt));
            continue;
          }
          break;
        }
      }
    }
    throw lastError ?? new Error('Cloud upload failed.');
  }

  const base64 = await new Promise<string>((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve((reader.result as string).split(',')[1] ?? '');
    reader.onerror = () => reject(reader.error);
    reader.readAsDataURL(preparedFile);
  });

  const res = await fetch('/api/upload-asset', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ filename: preparedFile.name, mimeType, data: base64 }),
  });
  const body = (await res.json().catch(() => ({}))) as { url?: string; error?: string };
  if (!res.ok) throw new Error(body.error || `Upload failed: ${res.status}`);
  if (typeof body.url !== 'string' || !body.url.trim()) {
    throw new Error('Invalid server response: missing url');
  }
  await options.onUploaded?.().catch(() => undefined);
  return normalizeUploadedAssetUrl(body.url, options.basePath);
}

END_OF_FILE_CONTENT
echo "Creating src/lib/base-schemas.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/base-schemas.ts"
export {
  BaseSectionData,
  BaseArrayItem,
  BaseSectionSettingsSchema,
  CtaSchema,
  ImageSelectionSchema,
} from '@olonjs/core';

END_OF_FILE_CONTENT
mkdir -p "src/lib/cloud"
echo "Creating src/lib/cloud/bootstrapTelemetry.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/cloud/bootstrapTelemetry.ts"
import type { CloudLoadFailure } from '@/lib/cloud/types';

export function logBootstrapEvent(event: string, details: Record<string, unknown>) {
  console.info('[boot]', { event, at: new Date().toISOString(), ...details });
}

function isObjectRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

export function isCloudLoadFailure(value: unknown): value is CloudLoadFailure {
  return (
    isObjectRecord(value) &&
    typeof value.reasonCode === 'string' &&
    typeof value.message === 'string'
  );
}

export function toCloudLoadFailure(value: unknown): CloudLoadFailure {
  if (isCloudLoadFailure(value)) return value;
  if (value instanceof Error) {
    return { reasonCode: 'CLOUD_LOAD_FAILED', message: value.message };
  }
  return { reasonCode: 'CLOUD_LOAD_FAILED', message: 'Cloud content unavailable.' };
}

END_OF_FILE_CONTENT
echo "Creating src/lib/cloud/cloudCache.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/cloud/cloudCache.ts"
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

END_OF_FILE_CONTENT
echo "Creating src/lib/cloud/cloudContentClient.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/cloud/cloudContentClient.ts"
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

END_OF_FILE_CONTENT
echo "Creating src/lib/cloud/cloudHttp.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/cloud/cloudHttp.ts"
export function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export function isRetryableStatus(status: number): boolean {
  return status === 429 || status === 500 || status === 502 || status === 503 || status === 504;
}

export function backoffDelayMs(attempt: number): number {
  return 250 * Math.pow(2, attempt) + Math.floor(Math.random() * 120);
}

END_OF_FILE_CONTENT
echo "Creating src/lib/cloud/contentCoercion.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/cloud/contentCoercion.ts"
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
  if (!Array.isArray(input.pages)) return null;

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

END_OF_FILE_CONTENT
echo "Creating src/lib/cloud/staticContent.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/cloud/staticContent.ts"
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

END_OF_FILE_CONTENT
echo "Creating src/lib/cloud/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/cloud/types.ts"
import type { JsonPagesConfig } from '@olonjs/core';

export type ContentMode = 'cloud' | 'error';

export type ContentStatus = 'ok' | 'empty_namespace' | 'legacy_fallback';

export type ContentResponse = {
  ok?: boolean;
  siteConfig?: unknown;
  pages?: unknown;
  items?: unknown;
  error?: string;
  code?: string;
  correlationId?: string;
  contentStatus?: ContentStatus;
  usedUnscopedFallback?: boolean;
  namespace?: string;
  namespaceMatchedKeys?: number;
};

export type CachedCloudContent = {
  keyFingerprint: string;
  savedAt: number;
  siteConfig: unknown | null;
  pages: Record<string, unknown>;
  collections?: JsonPagesConfig['collections'];
};

export type CloudLoadFailure = {
  reasonCode: string;
  message: string;
  correlationId?: string;
};

END_OF_FILE_CONTENT
echo "Creating src/lib/cloud/useAdminStudioContent.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/cloud/useAdminStudioContent.ts"
import { useEffect, useRef } from 'react';
import type { Dispatch, SetStateAction } from 'react';
import type { JsonPagesConfig } from '@olonjs/core';
import { applyLegacyCloudPayload, fetchLegacyCloudContentPayload } from '@/lib/cloud/cloudContentClient';
import { cloudFingerprint, writeCachedCloudContent } from '@/lib/cloud/cloudCache';
import { isAdminPath, patchHistoryNavigation } from '@/lib/spp';
import { APP_BASE_PATH } from '@/lib/tenantEnv';
import type { PageConfig, SiteConfig } from '@/types';

const MAX_RETRIES = 2;

type UseAdminStudioContentOptions = {
  enabled: boolean;
  apiCandidates: string[];
  apiKey: string;
  setPages: Dispatch<SetStateAction<Record<string, PageConfig>>>;
  setSiteConfig: Dispatch<SetStateAction<SiteConfig>>;
  setCollections: Dispatch<SetStateAction<NonNullable<JsonPagesConfig['collections']>>>;
};

/** Studio `/admin` sync via legacy `/content` — never mixed into visitor `/render` bootstrap. */
export function useAdminStudioContent({
  enabled,
  apiCandidates,
  apiKey,
  setPages,
  setSiteConfig,
  setCollections,
}: UseAdminStudioContentOptions) {
  const loadedRef = useRef(false);
  const inFlightRef = useRef<Promise<void> | null>(null);

  useEffect(() => {
    if (!enabled || apiCandidates.length === 0 || !apiKey.trim()) return;

    const syncIfAdmin = () => {
      if (!isAdminPath(window.location.pathname, APP_BASE_PATH)) return;
      if (loadedRef.current || inFlightRef.current) return;

      const controller = new AbortController();
      const fingerprint = cloudFingerprint(apiCandidates[0]!, apiKey);

      inFlightRef.current = fetchLegacyCloudContentPayload(
        apiCandidates,
        apiKey,
        controller.signal,
        MAX_RETRIES,
      )
        .then((payload) => {
          const { remotePages, remoteSite } = applyLegacyCloudPayload(payload, {
            setPages,
            setSiteConfig,
          });
          writeCachedCloudContent({
            keyFingerprint: fingerprint,
            savedAt: Date.now(),
            siteConfig: remoteSite ?? null,
            pages: (remotePages ?? {}) as Record<string, unknown>,
          });
          loadedRef.current = true;
        })
        .catch((error: unknown) => {
          if (import.meta.env.DEV) {
            console.warn('[admin-studio] legacy content sync failed', error);
          }
        })
        .finally(() => {
          inFlightRef.current = null;
        });
    };

    syncIfAdmin();
    const unpatch = patchHistoryNavigation(syncIfAdmin);
    return () => {
      unpatch();
      inFlightRef.current = null;
    };
  }, [enabled, apiCandidates, apiKey, setPages, setSiteConfig, setCollections]);
}

END_OF_FILE_CONTENT
echo "Creating src/lib/draftStorage.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/draftStorage.ts"
/**
 * Tenant initial data — file-backed only (no localStorage).
 */

import type { PageConfig, SiteConfig } from '@/types';

export interface HydratedData {
  pages: Record<string, PageConfig>;
  siteConfig: SiteConfig;
}

/**
 * Return pages and siteConfig from file-backed data only.
 */
export function getHydratedData(
  _tenantId: string,
  filePages: Record<string, PageConfig>,
  fileSiteConfig: SiteConfig
): HydratedData {
  return {
    pages: { ...filePages },
    siteConfig: fileSiteConfig,
  };
}

END_OF_FILE_CONTENT
mkdir -p "src/lib/editorial"
echo "Creating src/lib/getFileCollections.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/getFileCollections.ts"
import type { JsonPagesConfig } from '@/types';

type CollectionDocuments = NonNullable<JsonPagesConfig['collections']>;

function collectionSourceFromPath(filePath: string): string | null {
  const normalizedPath = filePath.replace(/\\/g, '/');
  const match = normalizedPath.match(/\/data\/collections\/([^/]+)\/[^/]+\.json$/i);
  return match?.[1]?.trim() || null;
}

export function getFileCollections(): CollectionDocuments {
  const glob = import.meta.glob<{ default: unknown }>('@/data/collections/**/*.json', { eager: true });
  const bySource = new Map<string, Record<string, unknown>>();
  const entries = Object.entries(glob).sort(([a], [b]) => a.localeCompare(b));

  for (const [path, mod] of entries) {
    const source = collectionSourceFromPath(path);
    const raw = mod?.default;
    if (!source) {
      console.warn(`[tenant-alpha:getFileCollections] Ignoring collection module with invalid path "${path}".`);
      continue;
    }
    if (raw == null || typeof raw !== 'object' || Array.isArray(raw)) {
      console.warn(`[tenant-alpha:getFileCollections] Ignoring invalid collection module at "${path}".`);
      continue;
    }
    if (bySource.has(source)) {
      console.warn(`[tenant-alpha:getFileCollections] Duplicate collection source "${source}" at "${path}". Keeping latest match.`);
    }
    bySource.set(source, raw as Record<string, unknown>);
  }

  const collections: CollectionDocuments = {};
  for (const source of Array.from(bySource.keys()).sort((a, b) => a.localeCompare(b))) {
    const collection = bySource.get(source);
    if (collection) collections[source] = collection;
  }
  return collections;
}

END_OF_FILE_CONTENT
echo "Creating src/lib/getFilePages.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/getFilePages.ts"
/**
 * Page registry loaded from nested JSON files under src/data/pages.
 * Add a JSON file in that directory tree to register a page; no manual list in App.tsx.
 */
import type { PageConfig } from '@/types';

function slugFromPath(filePath: string): string {
  const normalizedPath = filePath.replace(/\\/g, '/');
  const match = normalizedPath.match(/\/data\/pages\/(.+)\.json$/i);
  const rawSlug = match?.[1] ?? normalizedPath.split('/').pop()?.replace(/\.json$/i, '') ?? '';
  const canonical = rawSlug
    .split('/')
    .map((segment) => segment.trim())
    .filter(Boolean)
    .join('/');
  return canonical || 'home';
}

export function getFilePages(): Record<string, PageConfig> {
  const glob = import.meta.glob<{ default: unknown }>('@/data/pages/**/*.json', { eager: true });
  const bySlug = new Map<string, PageConfig>();
  const entries = Object.entries(glob).sort(([a], [b]) => a.localeCompare(b));
  for (const [path, mod] of entries) {
    const slug = slugFromPath(path);
    const raw = mod?.default;
    if (raw == null || typeof raw !== 'object') {
      console.warn(`[tenant-alpha:getFilePages] Ignoring invalid page module at "${path}".`);
      continue;
    }
    if (bySlug.has(slug)) {
      console.warn(`[tenant-alpha:getFilePages] Duplicate slug "${slug}" at "${path}". Keeping latest match.`);
    }
    bySlug.set(slug, raw as PageConfig);
  }
  const slugs = Array.from(bySlug.keys()).sort((a, b) =>
    a === 'home' ? -1 : b === 'home' ? 1 : a.localeCompare(b)
  );
  const record: Record<string, PageConfig> = {};
  for (const slug of slugs) {
    const config = bySlug.get(slug);
    if (config) record[slug] = config;
  }
  return record;
}

END_OF_FILE_CONTENT
echo "Creating src/lib/schemas.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/schemas.ts"
import { HeaderSchema } from '@/components/header';
import { FooterSchema } from '@/components/footer';
import { EditorialHeroSchema } from '@/components/editorial-hero';
import { PageHeroSchema } from '@/components/page-hero';
import { FeaturedProjectsSchema } from '@/components/featured-projects';
import { BlogRollupSchema } from '@/components/blog-rollup';
import { BioPanelSchema } from '@/components/bio-panel';
import { ContactCtaSchema } from '@/components/contact-cta';
import { TimelineSchema } from '@/components/timeline';
import { SkillsGridSchema } from '@/components/skills-grid';
import { PhilosophySchema } from '@/components/philosophy';
import { ContactFormSchema } from '@/components/contact-form';
import { ProjectDetailSchema } from '@/components/project-detail';
import { PostDetailSchema } from '@/components/post-detail';

export const SECTION_SCHEMAS = {
  header: HeaderSchema,
  footer: FooterSchema,
  'editorial-hero': EditorialHeroSchema,
  'page-hero': PageHeroSchema,
  'featured-projects': FeaturedProjectsSchema,
  'blog-rollup': BlogRollupSchema,
  'bio-panel': BioPanelSchema,
  'contact-cta': ContactCtaSchema,
  timeline: TimelineSchema,
  'skills-grid': SkillsGridSchema,
  philosophy: PhilosophySchema,
  'contact-form': ContactFormSchema,
  'project-detail': ProjectDetailSchema,
  'post-detail': PostDetailSchema,
} as const;

export const SECTION_SUBMISSION_SCHEMAS = {} as const;

export type SectionType = keyof typeof SECTION_SCHEMAS;

export {
  BaseSectionData,
  BaseArrayItem,
  BaseSectionSettingsSchema,
  CtaSchema,
  ImageSelectionSchema,
} from '@olonjs/core';
END_OF_FILE_CONTENT
mkdir -p "src/lib/spp"
echo "Creating src/lib/spp/cloudConfig.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/spp/cloudConfig.ts"
function normalizeApiBase(raw: string): string {
  return raw.trim().replace(/\/+$/, '');
}

export function buildApiCandidates(raw: string): string[] {
  const base = normalizeApiBase(raw);
  const withApi = /\/api\/v1$/i.test(base) ? base : `${base}/api/v1`;
  return Array.from(new Set([withApi, base].filter(Boolean)));
}

export function getSppCloudConfig(): {
  enabled: boolean;
  apiBases: string[];
  apiKey: string;
} {
  const apiUrl =
    import.meta.env.VITE_OLONJS_CLOUD_URL?.trim() ||
    import.meta.env.VITE_JSONPAGES_CLOUD_URL?.trim() ||
    '';
  const apiKey =
    import.meta.env.VITE_OLONJS_API_KEY?.trim() ||
    import.meta.env.VITE_JSONPAGES_API_KEY?.trim() ||
    '';
  const save2Repo = import.meta.env.VITE_SAVE2REPO === 'true';

  // SSG/bake: local resolved JSON only. Cloud slices are browser-runtime (SPP §3).
  if (import.meta.env.SSR || !apiUrl || !apiKey || save2Repo) {
    return { enabled: false, apiBases: [], apiKey: '' };
  }

  return {
    enabled: true,
    apiBases: buildApiCandidates(apiUrl),
    apiKey,
  };
}

END_OF_FILE_CONTENT
echo "Creating src/lib/spp/collectionRef.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/spp/collectionRef.ts"
import type { CollectionSliceDescriptor, CollectionSliceSort } from './types';

/** SPP §2.3 — sibling keys on a collection `$ref`; never collection entities. */
export const COLLECTION_REF_SIBLING_KEYS = new Set([
  '$ref',
  'limit',
  'pageSize',
  '$sliceSort',
  '$sliceFilter',
]);

export function isCollectionRef(value: unknown): value is Record<string, unknown> & { $ref: string } {
  return (
    typeof value === 'object' &&
    value !== null &&
    !Array.isArray(value) &&
    typeof (value as { $ref?: unknown }).$ref === 'string' &&
    (value as { $ref: string }).$ref.trim().length > 0
  );
}

export function isCollectionItem(value: unknown): value is Record<string, unknown> & { id: string } {
  return (
    typeof value === 'object' &&
    value !== null &&
    !Array.isArray(value) &&
    typeof (value as { id?: unknown }).id === 'string' &&
    (value as { id: string }).id.trim().length > 0
  );
}

function readSliceSort(value: unknown): CollectionSliceSort | undefined {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return undefined;
  const record = value as Record<string, unknown>;
  if (typeof record.field !== 'string' || !record.field.trim()) return undefined;
  if (record.direction !== 'asc' && record.direction !== 'desc') return undefined;
  return { field: record.field.trim(), direction: record.direction };
}

function readPositiveInt(value: unknown): number | undefined {
  if (typeof value !== 'number' || !Number.isFinite(value)) return undefined;
  const next = Math.floor(value);
  return next > 0 ? next : undefined;
}

/** Read SPP slice descriptor from an unresolved `$ref` or a resolved record polluted by ref siblings. */
export function readCollectionSliceDescriptor(
  value: unknown,
  fallback?: { limit?: number; pageSize?: number },
): CollectionSliceDescriptor {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return { limit: fallback?.limit ?? fallback?.pageSize };
  }

  const record = value as Record<string, unknown>;
  const limit =
    readPositiveInt(record.limit) ??
    readPositiveInt(record.pageSize) ??
    fallback?.limit ??
    fallback?.pageSize;

  const sort = readSliceSort(record.$sliceSort);
  const filter =
    record.$sliceFilter &&
    typeof record.$sliceFilter === 'object' &&
    !Array.isArray(record.$sliceFilter)
      ? (record.$sliceFilter as Record<string, string>)
      : undefined;

  return { limit, sort, filter };
}

/** Normalize any keyed collection payload; strips SPP ref siblings and non-entity entries. */
export function normalizeCollectionRecord<T extends Record<string, unknown> & { id: string }>(
  value: unknown,
  isItem: (candidate: unknown) => candidate is T = isCollectionItem as (candidate: unknown) => candidate is T,
): Record<string, T> | undefined {
  if (!value || typeof value !== 'object') return undefined;
  if (isCollectionRef(value)) return undefined;

  if (Array.isArray(value)) {
    const entries = value.filter(isItem).map((item) => [item.id, item] as const);
    return entries.length > 0 ? Object.fromEntries(entries) : undefined;
  }

  const entries = Object.entries(value as Record<string, unknown>)
    .filter(([key]) => !COLLECTION_REF_SIBLING_KEYS.has(key))
    .filter((entry): entry is [string, T] => isItem(entry[1]));

  return entries.length > 0 ? Object.fromEntries(entries) : undefined;
}

END_OF_FILE_CONTENT
echo "Creating src/lib/spp/collectionTotalQueue.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/spp/collectionTotalQueue.ts"
import { fetchCollectionTotal } from './collectionsClient';
import type { CollectionSliceSort } from './types';

type TotalCacheKey = string;

const totalCache = new Map<TotalCacheKey, number>();
const pendingResolvers = new Map<TotalCacheKey, Promise<number>>();

const queue: Array<() => Promise<void>> = [];
let activeWorkers = 0;

const MAX_CONCURRENT = 2;
const MAX_RETRIES = 2;
const RETRY_DELAY_MS = 400;

function cacheKey(collection: string, filter: Record<string, string>): TotalCacheKey {
  return `${collection}::${JSON.stringify(filter)}`;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function pumpQueue(): void {
  while (activeWorkers < MAX_CONCURRENT && queue.length > 0) {
    const job = queue.shift();
    if (!job) return;
    activeWorkers += 1;
    void job().finally(() => {
      activeWorkers -= 1;
      pumpQueue();
    });
  }
}

function enqueue(job: () => Promise<void>): void {
  queue.push(job);
  pumpQueue();
}

async function fetchWithRetry(
  collection: string,
  filter: Record<string, string>,
  sort?: CollectionSliceSort,
): Promise<number> {
  let lastError: unknown;
  for (let attempt = 0; attempt <= MAX_RETRIES; attempt += 1) {
    try {
      return await fetchCollectionTotal(collection, { filter, sort });
    } catch (error: unknown) {
      lastError = error;
      if (attempt < MAX_RETRIES) {
        await sleep(RETRY_DELAY_MS * (attempt + 1));
      }
    }
  }
  throw lastError instanceof Error ? lastError : new Error('Collection total fetch failed');
}

export function requestCollectionTotal(
  collection: string,
  filter: Record<string, string>,
  sort?: CollectionSliceSort,
): Promise<number> {
  const key = cacheKey(collection, filter);
  const cached = totalCache.get(key);
  if (cached != null) return Promise.resolve(cached);

  const pending = pendingResolvers.get(key);
  if (pending) return pending;

  const promise = new Promise<number>((resolve, reject) => {
    enqueue(async () => {
      try {
        const total = await fetchWithRetry(collection, filter, sort);
        totalCache.set(key, total);
        resolve(total);
      } catch (error: unknown) {
        pendingResolvers.delete(key);
        reject(error instanceof Error ? error : new Error('Collection total fetch failed'));
      }
    });
  });

  pendingResolvers.set(key, promise);
  return promise;
}

export function readCachedCollectionTotal(
  collection: string,
  filter: Record<string, string>,
): number | undefined {
  return totalCache.get(cacheKey(collection, filter));
}

END_OF_FILE_CONTENT
echo "Creating src/lib/spp/collectionsClient.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/spp/collectionsClient.ts"
import { getSppCloudConfig } from './cloudConfig';
import type { CollectionSliceResult, CollectionSliceSort } from './types';

type CollectionSliceResponse<T> = {
  ok: boolean;
  error?: string;
  code?: string;
  items?: Record<string, T>;
  pagination?: {
    total?: number;
    hasMore?: boolean;
    nextOffset?: number | null;
  };
};

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export async function fetchCollectionSlice<T extends Record<string, unknown> = Record<string, unknown>>(
  collectionName: string,
  options: {
    limit: number;
    offset: number;
    filter?: Record<string, string>;
    sort?: CollectionSliceSort;
    signal?: AbortSignal;
  },
): Promise<CollectionSliceResult<T>> {
  const cloud = getSppCloudConfig();
  if (!cloud.enabled) {
    throw new Error('SPP collections API is not configured');
  }

  const params = new URLSearchParams({
    limit: String(options.limit),
    offset: String(options.offset),
  });
  if (options.filter && Object.keys(options.filter).length > 0) {
    params.set('filter', JSON.stringify(options.filter));
  }
  if (options.sort) {
    params.set('sort', JSON.stringify(options.sort));
  }

  let lastError = 'Collection slice failed';

  for (const apiBase of cloud.apiBases) {
    try {
      const res = await fetch(`${apiBase}/collections/${encodeURIComponent(collectionName)}?${params}`, {
        method: 'GET',
        cache: 'no-store',
        headers: {
          Authorization: `Bearer ${cloud.apiKey}`,
        },
        signal: options.signal,
      });

      const body = (await res.json().catch(() => ({}))) as CollectionSliceResponse<T>;
      if (!res.ok || !body.ok) {
        lastError = body.error || body.code || `HTTP ${res.status}`;
        continue;
      }

      return {
        items: body.items ?? {},
        pagination: {
          total: body.pagination?.total ?? Object.keys(body.items ?? {}).length,
          hasMore: body.pagination?.hasMore ?? false,
          nextOffset: body.pagination?.nextOffset ?? null,
        },
      };
    } catch (error: unknown) {
      if (options.signal?.aborted) throw error;
      lastError = error instanceof Error ? error.message : lastError;
    }
    await sleep(120);
  }

  throw new Error(lastError);
}

/** Fetch server-side total for a filtered collection without loading the full dataset. */
export async function fetchCollectionTotal(
  collectionName: string,
  options?: {
    filter?: Record<string, string>;
    sort?: CollectionSliceSort;
    signal?: AbortSignal;
  },
): Promise<number> {
  const result = await fetchCollectionSlice(collectionName, {
    limit: 1,
    offset: 0,
    filter: options?.filter,
    sort: options?.sort,
    signal: options?.signal,
  });
  return result.pagination.total;
}

END_OF_FILE_CONTENT
echo "Creating src/lib/spp/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/spp/index.ts"
export { buildApiCandidates, getSppCloudConfig } from './cloudConfig';
export { fetchCollectionSlice, fetchCollectionTotal } from './collectionsClient';
export {
  readCachedCollectionTotal,
  requestCollectionTotal,
} from './collectionTotalQueue';
export { useLazyAuthorPostTotal } from './useLazyAuthorPostTotal';
export { useTagPostTotals } from './useTagPostTotals';
export {
  fetchRenderProjection,
  isAdminPath,
  normalizeRenderPath,
  patchHistoryNavigation,
  resolveRegistrySlugFromRender,
} from './renderClient';
export { useCollectionSlice } from './useCollectionSlice';
export {
  COLLECTION_REF_SIBLING_KEYS,
  isCollectionItem,
  isCollectionRef,
  normalizeCollectionRecord,
  readCollectionSliceDescriptor,
} from './collectionRef';
export type {
  CollectionItem,
  CollectionPagination,
  CollectionSliceDescriptor,
  CollectionSliceResult,
  CollectionSliceSort,
} from './types';
export type { RenderProjectionResponse } from './renderClient';

END_OF_FILE_CONTENT
echo "Creating src/lib/spp/lazyCollectionTotalQueue.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/spp/lazyCollectionTotalQueue.ts"
type QueueTask<T> = {
  id: string;
  signal: AbortSignal;
  execute: () => Promise<T>;
  onDone: (value: T) => void;
  onCancelled: () => void;
};

export class LazyFetchQueue {
  private readonly maxConcurrent: number;
  private active = 0;
  private readonly waiting: QueueTask<unknown>[] = [];
  private readonly removed = new Set<string>();

  constructor(maxConcurrent: number) {
    this.maxConcurrent = Math.max(1, maxConcurrent);
  }

  schedule<T>(task: QueueTask<T>) {
    if (this.removed.has(task.id)) return;
    this.waiting.push(task as QueueTask<unknown>);
    void this.pump();
  }

  remove(id: string) {
    this.removed.add(id);
    for (let index = this.waiting.length - 1; index >= 0; index -= 1) {
      if (this.waiting[index]?.id === id) {
        this.waiting.splice(index, 1);
      }
    }
  }

  clearRemoved(id: string) {
    this.removed.delete(id);
  }

  private async pump() {
    while (this.active < this.maxConcurrent && this.waiting.length > 0) {
      const task = this.waiting.shift();
      if (!task || this.removed.has(task.id) || task.signal.aborted) {
        continue;
      }

      this.active += 1;
      void this.runTask(task);
    }
  }

  private async runTask(task: QueueTask<unknown>) {
    try {
      const value = await task.execute();
      if (!task.signal.aborted && !this.removed.has(task.id)) {
        task.onDone(value);
      } else {
        task.onCancelled();
      }
    } catch {
      if (task.signal.aborted || this.removed.has(task.id)) {
        task.onCancelled();
      } else {
        task.onCancelled();
      }
    } finally {
      this.active = Math.max(0, this.active - 1);
      void this.pump();
    }
  }
}

export const authorPostTotalCache = new Map<string, number>();
export const authorPostTotalQueue = new LazyFetchQueue(6);

END_OF_FILE_CONTENT
echo "Creating src/lib/spp/renderClient.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/spp/renderClient.ts"
import type { MenuConfig, PageConfig, SiteConfig } from '@/types';

export type RenderProjectionResponse = {
  ok: boolean;
  error?: string;
  code?: string;
  correlationId?: string;
  route?: {
    path: string;
    template: string;
    params: Record<string, string>;
  };
  context?: {
    siteConfig: SiteConfig;
    menuConfig: MenuConfig;
  };
  page?: PageConfig;
  diagnostics?: {
    projectionMode: 'atomic' | 'legacy_fallback';
    unresolvedRefs: string[];
  };
};

export function normalizeRenderPath(pathname: string, basePath: string): string {
  const normalizedBase = basePath.replace(/\/+$/, '') || '';
  let path = pathname.trim() || '/';
  if (normalizedBase && normalizedBase !== '/' && path.startsWith(normalizedBase)) {
    path = path.slice(normalizedBase.length) || '/';
  }
  if (!path.startsWith('/')) path = `/${path}`;
  return path === '' ? '/' : path;
}

export function isAdminPath(pathname: string, basePath: string): boolean {
  const path = normalizeRenderPath(pathname, basePath);
  return path === '/admin' || path.startsWith('/admin/');
}

export function resolveRegistrySlugFromRender(page: PageConfig): string {
  const slug = typeof page.slug === 'string' ? page.slug.trim() : '';
  if (slug.includes('[')) return slug;
  if (slug) return slug;
  return 'home';
}

function isRetryableStatus(status: number): boolean {
  return status === 429 || status === 500 || status === 502 || status === 503 || status === 504;
}

async function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function backoffDelayMs(attempt: number): number {
  return 250 * Math.pow(2, attempt) + Math.floor(Math.random() * 120);
}

export async function fetchRenderProjection(
  apiBases: string[],
  apiKey: string,
  path: string,
  options?: { signal?: AbortSignal; maxRetryAttempts?: number },
): Promise<RenderProjectionResponse> {
  const maxRetryAttempts = options?.maxRetryAttempts ?? 2;
  const query = new URLSearchParams({ path });
  let lastFailure: RenderProjectionResponse | null = null;

  for (const apiBase of apiBases) {
    for (let attempt = 0; attempt <= maxRetryAttempts; attempt += 1) {
      try {
        const res = await fetch(`${apiBase}/render?${query.toString()}`, {
          method: 'GET',
          cache: 'no-store',
          headers: {
            Authorization: `Bearer ${apiKey}`,
          },
          signal: options?.signal,
        });

        const contentType = (res.headers.get('content-type') || '').toLowerCase();
        if (!contentType.includes('application/json')) {
          lastFailure = {
            ok: false,
            code: 'NON_JSON_RESPONSE',
            error: `Non-JSON response from ${apiBase}/render`,
          };
          break;
        }

        const parsed = (await res.json().catch(() => ({}))) as RenderProjectionResponse;
        if (!res.ok) {
          lastFailure = {
            ok: false,
            code: parsed.code || `HTTP_${res.status}`,
            error: parsed.error || `Render failed: ${res.status}`,
            correlationId: parsed.correlationId,
          };
          if (isRetryableStatus(res.status) && attempt < maxRetryAttempts) {
            await sleep(backoffDelayMs(attempt));
            continue;
          }
          break;
        }

        if (!parsed.ok || !parsed.page) {
          lastFailure = {
            ok: false,
            code: parsed.code || 'ERR_RENDER_PROJECTION_FAILED',
            error: parsed.error || 'Render payload missing page',
            correlationId: parsed.correlationId,
          };
          break;
        }

        return parsed;
      } catch (error: unknown) {
        if (options?.signal?.aborted) throw error;
        const message = error instanceof Error ? error.message : 'Network error';
        lastFailure = {
          ok: false,
          code: 'NETWORK_TRANSIENT',
          error: `${message} (${apiBase}/render)`,
        };
        if (attempt < maxRetryAttempts) {
          await sleep(backoffDelayMs(attempt));
          continue;
        }
      }
    }
    if (lastFailure?.ok === false && lastFailure.code !== 'NETWORK_TRANSIENT') {
      break;
    }
  }

  return (
    lastFailure ?? {
      ok: false,
      code: 'RENDER_ENDPOINT_UNREACHABLE',
      error: 'Render endpoint not reachable.',
    }
  );
}

export function patchHistoryNavigation(onNavigate: () => void): () => void {
  const notify = () => {
    window.queueMicrotask(onNavigate);
  };

  window.addEventListener('popstate', notify);
  const originalPushState = history.pushState.bind(history);
  const originalReplaceState = history.replaceState.bind(history);

  history.pushState = (...args: Parameters<History['pushState']>) => {
    originalPushState(...args);
    notify();
  };
  history.replaceState = (...args: Parameters<History['replaceState']>) => {
    originalReplaceState(...args);
    notify();
  };

  return () => {
    window.removeEventListener('popstate', notify);
    history.pushState = originalPushState;
    history.replaceState = originalReplaceState;
  };
}

END_OF_FILE_CONTENT
echo "Creating src/lib/spp/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/spp/types.ts"
export type CollectionSliceSort = {
  field: string;
  direction: 'asc' | 'desc';
};

export type CollectionPagination = {
  total: number;
  hasMore: boolean;
  nextOffset: number | null;
};

export type CollectionSliceResult<T extends Record<string, unknown> = Record<string, unknown>> = {
  items: Record<string, T>;
  pagination: CollectionPagination;
};

export type CollectionSliceDescriptor = {
  limit?: number;
  sort?: CollectionSliceSort;
  filter?: Record<string, string>;
};

export type CollectionItem = Record<string, unknown> & { id: string };

END_OF_FILE_CONTENT
echo "Creating src/lib/spp/useCollectionSlice.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/spp/useCollectionSlice.ts"
import { useCallback, useEffect, useRef, useState } from 'react';
import {
  isCollectionItem,
  isCollectionRef,
  normalizeCollectionRecord,
  readCollectionSliceDescriptor,
} from './collectionRef';
import { fetchCollectionSlice } from './collectionsClient';
import { getSppCloudConfig } from './cloudConfig';
import type { CollectionItem, CollectionPagination, CollectionSliceSort } from './types';

function initialPagination(
  loadedCount: number,
  pageSize: number,
  cloudEnabled: boolean,
  unresolvedRef: boolean,
): CollectionPagination {
  if (!cloudEnabled || pageSize <= 0) {
    return { total: 0, hasMore: false, nextOffset: null };
  }
  if (unresolvedRef || loadedCount === 0) {
    return { total: 0, hasMore: true, nextOffset: 0 };
  }
  if (loadedCount < pageSize) {
    return { total: 0, hasMore: true, nextOffset: loadedCount };
  }
  return {
    total: 0,
    hasMore: true,
    nextOffset: loadedCount,
  };
}

export function useCollectionSlice<T extends CollectionItem>(options: {
  collectionName: string;
  initialItems: unknown;
  pageSize: number;
  filter?: Record<string, string> | null;
  sort?: CollectionSliceSort;
  resetKey?: string | null;
  isItem?: (value: unknown) => value is T;
}) {
  const cloud = getSppCloudConfig();
  const isItem = options.isItem ?? (isCollectionItem as (value: unknown) => value is T);
  const descriptor = readCollectionSliceDescriptor(options.initialItems, { pageSize: options.pageSize });
  const sort = options.sort ?? descriptor.sort;
  const filterKey = options.filter ? JSON.stringify(options.filter) : '';
  const resetKey = options.resetKey ?? filterKey;

  const normalize = useCallback(
    (value: unknown) => normalizeCollectionRecord<T>(value, isItem) ?? {},
    [isItem],
  );

  const unresolvedRef = isCollectionRef(options.initialItems);

  const [mergedItems, setMergedItems] = useState<Record<string, T>>(() => normalize(options.initialItems));
  const [pagination, setPagination] = useState<CollectionPagination>(() => {
    const count = Object.keys(normalize(options.initialItems)).length;
    return initialPagination(count, options.pageSize, cloud.enabled, unresolvedRef);
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const inFlightRef = useRef(false);
  const mergedItemsRef = useRef(mergedItems);
  const paginationRef = useRef(pagination);
  mergedItemsRef.current = mergedItems;
  paginationRef.current = pagination;

  useEffect(() => {
    const base = normalize(options.initialItems);
    const count = Object.keys(base).length;
    mergedItemsRef.current = base;
    setMergedItems(base);
    const nextPagination = initialPagination(
      count,
      options.pageSize,
      cloud.enabled,
      isCollectionRef(options.initialItems),
    );
    paginationRef.current = nextPagination;
    setPagination(nextPagination);
    setError(null);
  }, [options.initialItems, options.pageSize, resetKey, cloud.enabled, normalize]);

  const loadMore = useCallback(async () => {
    if (!cloud.enabled || inFlightRef.current) return false;

    const loadedCount = Object.keys(mergedItemsRef.current).length;
    const currentPagination = paginationRef.current;
    if (!currentPagination.hasMore) return false;
    if (currentPagination.total > 0 && loadedCount >= currentPagination.total) {
      return false;
    }

    inFlightRef.current = true;
    setLoading(true);
    setError(null);

    try {
      const offset = currentPagination.nextOffset ?? loadedCount;

      const result = await fetchCollectionSlice<T>(options.collectionName, {
        limit: options.pageSize,
        offset,
        filter: options.filter ?? undefined,
        sort,
      });

      const nextItems = { ...mergedItemsRef.current, ...result.items };
      mergedItemsRef.current = nextItems;
      setMergedItems(nextItems);
      const mergedCount = Object.keys(nextItems).length;
      const total = result.pagination.total;
      const nextPagination: CollectionPagination = {
        total,
        hasMore: total > 0 ? mergedCount < total : result.pagination.hasMore,
        nextOffset: result.pagination.nextOffset ?? (Object.keys(result.items).length > 0 ? offset + Object.keys(result.items).length : null),
      };
      paginationRef.current = nextPagination;
      setPagination(nextPagination);
      return Object.keys(result.items).length > 0;
    } catch (fetchError: unknown) {
      setError(fetchError instanceof Error ? fetchError.message : 'Failed to load collection slice');
      return false;
    } finally {
      inFlightRef.current = false;
      setLoading(false);
    }
  }, [cloud.enabled, options.collectionName, options.filter, options.pageSize, sort]);

  useEffect(() => {
    if (!cloud.enabled) return;
    const loadedCount = Object.keys(mergedItemsRef.current).length;
    if (loadedCount >= options.pageSize) return;
    if (!paginationRef.current.hasMore) return;
    void loadMore();
  }, [cloud.enabled, options.pageSize, resetKey, loadMore]);

  useEffect(() => {
    if (!cloud.enabled) return;
    let cancelled = false;

    (async () => {
      if (paginationRef.current.total > 0) return;

      try {
        const result = await fetchCollectionSlice<T>(options.collectionName, {
          limit: 1,
          offset: 0,
          filter: options.filter ?? undefined,
          sort,
        });
        if (cancelled) return;

        const loadedCount = Object.keys(mergedItemsRef.current).length;
        const total = result.pagination.total;
        const nextPagination: CollectionPagination = {
          total,
          hasMore: loadedCount < total,
          nextOffset: loadedCount > 0 ? loadedCount : Object.keys(result.items).length,
        };
        paginationRef.current = nextPagination;
        setPagination(nextPagination);

        if (loadedCount === 0 && Object.keys(result.items).length > 0) {
          mergedItemsRef.current = result.items;
          setMergedItems(result.items);
        }
      } catch {
        // Total stays unknown until loadMore succeeds.
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [cloud.enabled, options.collectionName, options.filter, options.pageSize, sort, resetKey]);

  const ensureLoadedCount = useCallback(
    async (requiredCount: number) => {
      if (!cloud.enabled) return;
      for (let guard = 0; guard < 20; guard += 1) {
        const loadedCount = Object.keys(mergedItemsRef.current).length;
        const currentPagination = paginationRef.current;
        if (loadedCount >= requiredCount) return;
        if (currentPagination.total > 0 && loadedCount >= currentPagination.total) return;
        if (!currentPagination.hasMore) return;
        const loaded = await loadMore();
        if (!loaded) return;
      }
    },
    [cloud.enabled, loadMore],
  );

  return {
    cloudEnabled: cloud.enabled,
    sliceDescriptor: descriptor,
    mergedItems,
    pagination,
    loading,
    error,
    loadMore,
    ensureLoadedCount,
  };
}

END_OF_FILE_CONTENT
echo "Creating src/lib/spp/useLazyAuthorPostTotal.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/spp/useLazyAuthorPostTotal.ts"
import { useEffect, useRef, useState } from 'react';
import { fetchCollectionTotal } from './collectionsClient';
import { getSppCloudConfig } from './cloudConfig';
import { authorPostTotalCache, authorPostTotalQueue } from './lazyCollectionTotalQueue';

export function useLazyAuthorPostTotal(authorId: string) {
  const cloud = getSppCloudConfig();
  const elementRef = useRef<HTMLAnchorElement>(null);
  const [total, setTotal] = useState<number | null>(() => authorPostTotalCache.get(authorId) ?? null);
  const [loading, setLoading] = useState(false);
  const abortRef = useRef<AbortController | null>(null);

  useEffect(() => {
    setTotal(authorPostTotalCache.get(authorId) ?? null);
  }, [authorId]);

  useEffect(() => {
    if (!cloud.enabled) return;
    const node = elementRef.current;
    if (!node) return;

    const observer = new IntersectionObserver(
      ([entry]) => {
        if (!entry) return;

        if (!entry.isIntersecting) {
          authorPostTotalQueue.remove(authorId);
          abortRef.current?.abort();
          abortRef.current = null;
          if (!authorPostTotalCache.has(authorId)) {
            setLoading(false);
          }
          return;
        }

        authorPostTotalQueue.clearRemoved(authorId);

        if (authorPostTotalCache.has(authorId)) {
          setTotal(authorPostTotalCache.get(authorId)!);
          setLoading(false);
          return;
        }

        abortRef.current?.abort();
        const controller = new AbortController();
        abortRef.current = controller;
        setLoading(true);

        authorPostTotalQueue.schedule({
          id: authorId,
          signal: controller.signal,
          execute: () =>
            fetchCollectionTotal('posts', {
              filter: { 'author.id': authorId },
              signal: controller.signal,
            }),
          onDone: (value) => {
            authorPostTotalCache.set(authorId, value);
            setTotal(value);
            setLoading(false);
          },
          onCancelled: () => {
            if (!authorPostTotalCache.has(authorId)) {
              setLoading(false);
            }
          },
        });
      },
      { rootMargin: '120px 0px' },
    );

    observer.observe(node);
    return () => {
      observer.disconnect();
      authorPostTotalQueue.remove(authorId);
      abortRef.current?.abort();
      abortRef.current = null;
    };
  }, [authorId, cloud.enabled]);

  return { elementRef, total, loading, cloudEnabled: cloud.enabled };
}

END_OF_FILE_CONTENT
echo "Creating src/lib/spp/useTagPostTotals.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/spp/useTagPostTotals.ts"
import { useEffect, useState } from 'react';
import { getSppCloudConfig } from './cloudConfig';
import { readCachedCollectionTotal, requestCollectionTotal } from './collectionTotalQueue';

function tagFilter(slug: string): Record<string, string> {
  return { 'tag.slug': slug };
}

export function useTagPostTotals(tagSlugs: string[]) {
  const cloud = getSppCloudConfig();
  const tagSlugsKey = tagSlugs.join('|');
  const [totals, setTotals] = useState<Record<string, number>>(() => {
    const initial: Record<string, number> = {};
    for (const slug of tagSlugs) {
      const cached = readCachedCollectionTotal('posts', tagFilter(slug));
      if (cached != null) initial[slug] = cached;
    }
    return initial;
  });

  useEffect(() => {
    if (!cloud.enabled || tagSlugs.length === 0) return;
    let cancelled = false;

    for (const slug of tagSlugs) {
      const cached = readCachedCollectionTotal('posts', tagFilter(slug));
      if (cached != null) {
        setTotals((prev) => (prev[slug] === cached ? prev : { ...prev, [slug]: cached }));
        continue;
      }

      void requestCollectionTotal('posts', tagFilter(slug))
        .then((total) => {
          if (!cancelled) {
            setTotals((prev) => (prev[slug] === total ? prev : { ...prev, [slug]: total }));
          }
        })
        .catch(() => {
          // requestCollectionTotal already retried; a remount or slug change can retry.
        });
    }

    return () => {
      cancelled = true;
    };
  }, [tagSlugsKey, cloud.enabled, tagSlugs]);

  return totals;
}

END_OF_FILE_CONTENT
echo "Creating src/lib/sppCloudConfig.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/sppCloudConfig.ts"
export { buildApiCandidates, getSppCloudConfig } from '@/lib/spp';

END_OF_FILE_CONTENT
echo "Creating src/lib/sppCollectionsClient.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/sppCollectionsClient.ts"
import { readCollectionSliceDescriptor } from '@/lib/spp';

export function readCollectionRefLimit(value: unknown, fallback?: number): number | undefined {
  const { limit } = readCollectionSliceDescriptor(value, { limit: fallback, pageSize: fallback });
  return limit;
}

export { fetchCollectionSlice, readCollectionSliceDescriptor } from '@/lib/spp';
export type { CollectionPagination, CollectionSliceSort } from '@/lib/spp';

END_OF_FILE_CONTENT
echo "Creating src/lib/sppRenderClient.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/sppRenderClient.ts"
export * from './spp/renderClient';

END_OF_FILE_CONTENT
echo "Creating src/lib/tenantCss.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/tenantCss.ts"
function isObjectRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

export function buildThemeFontVarsCss(input: unknown): string {
  if (!isObjectRecord(input)) return '';
  const tokens = isObjectRecord(input.tokens) ? input.tokens : null;
  const typography = tokens && isObjectRecord(tokens.typography) ? tokens.typography : null;
  const fontFamily = typography && isObjectRecord(typography.fontFamily) ? typography.fontFamily : null;
  const primary = typeof fontFamily?.primary === 'string' ? fontFamily.primary : "'Instrument Sans', system-ui, sans-serif";
  const serif = typeof fontFamily?.serif === 'string' ? fontFamily.serif : "'Instrument Serif', Georgia, serif";
  const mono = typeof fontFamily?.mono === 'string' ? fontFamily.mono : "'JetBrains Mono', monospace";
  return `:root{--theme-font-primary:${primary};--theme-font-serif:${serif};--theme-font-mono:${mono};}`;
}

const REMOTE_CSS_LINK_ATTR = 'data-jp-tenant-remote-css';
const TENANT_SHELL_STYLE_ATTR = 'data-jp-tenant-shell-css';

function isRemoteStylesheetHref(value: string): boolean {
  return /^https?:\/\//i.test(value.trim());
}

export function extractLeadingRemoteCssImports(cssText: string): { hrefs: string[]; rest: string } {
  const hrefs = new Set<string>();
  const leadingTriviaPattern = /^(?:\s+|\/\*[\s\S]*?\*\/)*/;
  const importPattern =
    /^@import\s+url\(\s*(?:'([^']+)'|"([^"]+)"|([^'")\s][^)]*))\s*\)\s*([^;]*);/i;
  let rest = cssText;

  for (;;) {
    const trivia = rest.match(leadingTriviaPattern);
    if (trivia && trivia[0]) {
      rest = rest.slice(trivia[0].length);
    }

    const match = rest.match(importPattern);
    if (!match) break;

    const href = (match[1] ?? match[2] ?? match[3] ?? '').trim();
    const trailingDirectives = (match[4] ?? '').trim();

    if (!isRemoteStylesheetHref(href) || trailingDirectives.length > 0) {
      break;
    }

    hrefs.add(href);
    rest = rest.slice(match[0].length);
  }

  return { hrefs: Array.from(hrefs), rest };
}

export function setTenantPreviewReady(ready: boolean): void {
  if (typeof window !== 'undefined') {
    (window as Window & { __TENANT_PREVIEW_READY__?: boolean }).__TENANT_PREVIEW_READY__ = ready;
  }
  if (typeof document !== 'undefined' && document.body) {
    document.body.dataset.previewReady = ready ? '1' : '0';
  }
}

import { useEffect, useState } from 'react';

export function useInjectedTenantCss(css: string): void {
  useEffect(() => {
    if (typeof document === 'undefined' || !css.trim()) return;

    let style = document.querySelector(`style[${TENANT_SHELL_STYLE_ATTR}]`) as HTMLStyleElement | null;
    if (!style) {
      style = document.createElement('style');
      style.setAttribute(TENANT_SHELL_STYLE_ATTR, '1');
      document.head.appendChild(style);
    }
    style.textContent = css;
  }, [css]);
}

function ensureFontPreconnects(): void {
  if (typeof document === 'undefined') return;

  const targets = [
    { href: 'https://fonts.googleapis.com', crossOrigin: null },
    { href: 'https://fonts.gstatic.com', crossOrigin: 'anonymous' },
  ] as const;

  targets.forEach(({ href, crossOrigin }) => {
    const existing = Array.from(document.querySelectorAll('link[rel="preconnect"]')).find(
      (link) => (link as HTMLLinkElement).href === href,
    );
    if (existing) return;

    const link = document.createElement('link');
    link.rel = 'preconnect';
    link.href = href;
    if (crossOrigin) link.crossOrigin = crossOrigin;
    document.head.appendChild(link);
  });
}

export function ensureRemoteStylesheetLinks(hrefs: string[]): void {
  if (typeof document === 'undefined') return;

  ensureFontPreconnects();

  hrefs.forEach((href) => {
    const existing = Array.from(document.querySelectorAll('link[rel="stylesheet"]')).find(
      (link) => (link as HTMLLinkElement).href === href,
    ) as HTMLLinkElement | undefined;
    if (existing) return;

    const link = document.createElement('link');
    link.rel = 'stylesheet';
    link.href = href;
    link.setAttribute(REMOTE_CSS_LINK_ATTR, href);
    document.head.appendChild(link);
  });
}

export function waitForTenantFonts(hrefs: string[]): Promise<void> {
  if (typeof document === 'undefined') return Promise.resolve();

  ensureRemoteStylesheetLinks(hrefs);
  if (hrefs.length === 0 || !document.fonts?.ready) return Promise.resolve();

  return document.fonts.ready.then(() => undefined);
}

export function useTenantFontsReady(hrefs: string[]): boolean {
  const [ready, setReady] = useState(false);
  const hrefKey = hrefs.join('\0');

  useEffect(() => {
    let cancelled = false;
    setReady(false);

    void waitForTenantFonts(hrefs).then(() => {
      if (!cancelled) setReady(true);
    });

    return () => {
      cancelled = true;
    };
  }, [hrefKey, hrefs]);

  return ready;
}

export function useRemoteStylesheetLinks(hrefs: string[]): void {
  const hrefKey = hrefs.join('\0');

  useEffect(() => {
    ensureRemoteStylesheetLinks(hrefs);

    if (typeof document === 'undefined') return undefined;

    const createdLinks = Array.from(
      document.querySelectorAll(`link[${REMOTE_CSS_LINK_ATTR}]`),
    ) as HTMLLinkElement[];

    return () => {
      createdLinks.forEach((link) => {
        if (link.getAttribute(REMOTE_CSS_LINK_ATTR) !== link.href) return;
        link.parentNode?.removeChild(link);
      });
    };
  }, [hrefKey, hrefs]);
}

END_OF_FILE_CONTENT
echo "Creating src/lib/tenantEnv.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/tenantEnv.ts"
import { normalizeBasePath } from '@olonjs/core';

export const CLOUD_API_URL =
  import.meta.env.VITE_OLONJS_CLOUD_URL ?? import.meta.env.VITE_JSONPAGES_CLOUD_URL;
export const CLOUD_API_KEY =
  import.meta.env.VITE_OLONJS_API_KEY ?? import.meta.env.VITE_JSONPAGES_API_KEY;
export const SAVE2REPO_ENABLED = import.meta.env.VITE_SAVE2REPO === 'true';
export const APP_BASE_PATH = normalizeBasePath(import.meta.env.BASE_URL || '/');
export const TENANT_ID = 'alpha';

END_OF_FILE_CONTENT
echo "Creating src/lib/useAssetsManifest.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/useAssetsManifest.ts"
import { useCallback, useEffect, useMemo, useState } from 'react';
import type { LibraryImageEntry } from '@olonjs/core';
import { buildApiCandidates } from '@/lib/sppCloudConfig';
import { CLOUD_API_KEY, CLOUD_API_URL } from '@/lib/tenantEnv';

function normalizeApiBase(raw: string): string {
  return raw.trim().replace(/\/+$/, '');
}

export function useAssetsManifest(isCloudMode: boolean) {
  const [assetsManifest, setAssetsManifest] = useState<LibraryImageEntry[]>([]);
  const cloudApiCandidates = useMemo(
    () => (isCloudMode && CLOUD_API_URL ? buildApiCandidates(CLOUD_API_URL) : []),
    [isCloudMode],
  );

  const loadAssetsManifest = useCallback(async (): Promise<void> => {
    if (isCloudMode && CLOUD_API_URL && CLOUD_API_KEY) {
      const apiBases = cloudApiCandidates.length > 0 ? cloudApiCandidates : [normalizeApiBase(CLOUD_API_URL)];
      for (const apiBase of apiBases) {
        try {
          const res = await fetch(`${apiBase}/assets/list?limit=200`, {
            method: 'GET',
            headers: { Authorization: `Bearer ${CLOUD_API_KEY}` },
          });
          const body = (await res.json().catch(() => ({}))) as { items?: LibraryImageEntry[] };
          if (!res.ok) continue;
          const items = Array.isArray(body.items) ? body.items : [];
          setAssetsManifest(items);
          return;
        } catch {
          // try next candidate
        }
      }
      setAssetsManifest([]);
      return;
    }

    fetch('/api/list-assets')
      .then((r) => (r.ok ? r.json() : []))
      .then((list: LibraryImageEntry[]) => setAssetsManifest(Array.isArray(list) ? list : []))
      .catch(() => setAssetsManifest([]));
  }, [isCloudMode, cloudApiCandidates]);

  useEffect(() => {
    void loadAssetsManifest();
  }, [loadAssetsManifest]);

  return { assetsManifest, loadAssetsManifest, cloudApiCandidates };
}

END_OF_FILE_CONTENT
echo "Creating src/lib/useCloudSave.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/useCloudSave.ts"
import { useCallback, useEffect, useRef, useState } from 'react';
import type { DeployPhase, ProjectState, StepId } from '@olonjs/core';
import { DEPLOY_STEPS, startCloudSaveStream } from '@olonjs/core';
import { CLOUD_API_KEY, CLOUD_API_URL } from '@/lib/tenantEnv';

interface CloudSaveUiState {
  isOpen: boolean;
  phase: DeployPhase;
  currentStepId: StepId | null;
  doneSteps: StepId[];
  progress: number;
  errorMessage?: string;
  deployUrl?: string;
}

function getInitialCloudSaveUiState(): CloudSaveUiState {
  return {
    isOpen: false,
    phase: 'idle',
    currentStepId: null,
    doneSteps: [],
    progress: 0,
  };
}

function stepProgress(doneSteps: StepId[]): number {
  return Math.round((doneSteps.length / DEPLOY_STEPS.length) * 100);
}

export function useCloudSave() {
  const [cloudSaveUi, setCloudSaveUi] = useState<CloudSaveUiState>(getInitialCloudSaveUiState);
  const activeCloudSaveController = useRef<AbortController | null>(null);
  const pendingCloudSave = useRef<{ state: ProjectState; slug: string } | null>(null);

  useEffect(() => {
    return () => {
      activeCloudSaveController.current?.abort();
    };
  }, []);

  const runCloudSave = useCallback(
    async (payload: { state: ProjectState; slug: string }, rejectOnError: boolean): Promise<void> => {
      if (!CLOUD_API_URL || !CLOUD_API_KEY) {
        const noCloudError = new Error('Cloud mode is not configured.');
        if (rejectOnError) throw noCloudError;
        return;
      }

      pendingCloudSave.current = payload;
      activeCloudSaveController.current?.abort();
      const controller = new AbortController();
      activeCloudSaveController.current = controller;

      setCloudSaveUi({
        isOpen: true,
        phase: 'running',
        currentStepId: null,
        doneSteps: [],
        progress: 0,
      });

      try {
        await startCloudSaveStream({
          apiBaseUrl: CLOUD_API_URL,
          apiKey: CLOUD_API_KEY,
          path: `src/data/pages/${payload.slug}.json`,
          content: payload.state.page,
          message: `Content update for ${payload.slug} via Visual Editor`,
          signal: controller.signal,
          onStep: (event) => {
            setCloudSaveUi((prev) => {
              if (event.status === 'running') {
                return {
                  ...prev,
                  isOpen: true,
                  phase: 'running',
                  currentStepId: event.id,
                  errorMessage: undefined,
                };
              }

              if (prev.doneSteps.includes(event.id)) {
                return prev;
              }

              const nextDone = [...prev.doneSteps, event.id];
              return {
                ...prev,
                isOpen: true,
                phase: 'running',
                currentStepId: event.id,
                doneSteps: nextDone,
                progress: stepProgress(nextDone),
              };
            });
          },
          onDone: (event) => {
            const completed = DEPLOY_STEPS.map((step) => step.id);
            setCloudSaveUi({
              isOpen: true,
              phase: 'done',
              currentStepId: 'live',
              doneSteps: completed,
              progress: 100,
              deployUrl: event.deployUrl,
            });
          },
        });
      } catch (error: unknown) {
        const message = error instanceof Error ? error.message : 'Cloud save failed.';
        setCloudSaveUi((prev) => ({
          ...prev,
          isOpen: true,
          phase: 'error',
          errorMessage: message,
        }));
        if (rejectOnError) throw new Error(message);
      } finally {
        if (activeCloudSaveController.current === controller) {
          activeCloudSaveController.current = null;
        }
      }
    },
    [],
  );

  const closeCloudDrawer = useCallback(() => {
    setCloudSaveUi(getInitialCloudSaveUiState());
  }, []);

  const retryCloudSave = useCallback(() => {
    if (!pendingCloudSave.current) return;
    void runCloudSave(pendingCloudSave.current, false);
  }, [runCloudSave]);

  return { cloudSaveUi, runCloudSave, closeCloudDrawer, retryCloudSave };
}

END_OF_FILE_CONTENT
echo "Creating src/lib/useFormSubmit.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/useFormSubmit.ts"
import { useState, useCallback } from 'react';

export type SubmitStatus = 'idle' | 'submitting' | 'success' | 'error';

interface UseFormSubmitOptions {
  source: string;
  tenantId: string;
}

export function useFormSubmit({ source, tenantId }: UseFormSubmitOptions) {
  const [status, setStatus] = useState<SubmitStatus>('idle');
  const [message, setMessage] = useState<string>('');

  const submit = useCallback(async (
    formData: FormData, 
    recipientEmail: string, 
    pageSlug: string, 
    sectionId: string
  ) => {
    const cloudApiUrl = import.meta.env.VITE_JSONPAGES_CLOUD_URL as string | undefined;
    const cloudApiKey = import.meta.env.VITE_JSONPAGES_API_KEY as string | undefined;

    if (!cloudApiUrl || !cloudApiKey) {
      setStatus('error');
      setMessage('Configurazione API non disponibile. Riprova tra poco.');
      return false;
    }

    // Trasformiamo FormData in un oggetto piatto per il payload JSON
    const data: Record<string, any> = {};
    formData.forEach((value, key) => {
      data[key] = String(value).trim();
    });

    const payload = {
      ...data,
      recipientEmail,
      page: pageSlug,
      section: sectionId,
      tenant: tenantId,
      source: source,
      submittedAt: new Date().toISOString(),
    };

    // Idempotency Key per evitare doppi invii accidentali
    const idempotencyKey = `form-${sectionId}-${Date.now()}`;

    setStatus('submitting');
    setMessage('Invio in corso...');

    try {
      const apiBase = cloudApiUrl.replace(/\/$/, '');
      const response = await fetch(`${apiBase}/forms/submit`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${cloudApiKey}`,
          'Content-Type': 'application/json',
          'Idempotency-Key': idempotencyKey,
        },
        body: JSON.stringify(payload),
      });

      const body = (await response.json().catch(() => ({}))) as { error?: string; code?: string };

      if (!response.ok) {
        throw new Error(body.error || body.code || `Submit failed (${response.status})`);
      }

      setStatus('success');
      setMessage('Richiesta inviata con successo. Ti risponderemo al più presto.');
      return true;
    } catch (error: unknown) {
      const errorMsg = error instanceof Error ? error.message : 'Invio non riuscito. Riprova tra poco.';
      setStatus('error');
      setMessage(errorMsg);
      return false;
    }
  }, [source, tenantId]);

  const reset = useCallback(() => {
    setStatus('idle');
    setMessage('');
  }, []);

  return { submit, status, message, reset };
}
END_OF_FILE_CONTENT
echo "Creating src/lib/useOlonForms.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/useOlonForms.ts"
import { useCallback, useEffect, useState } from 'react';
import type { FormState } from '@olonjs/core';

const API_BASE =
  (import.meta.env.VITE_OLONJS_CLOUD_URL as string | undefined) ??
  (import.meta.env.VITE_JSONPAGES_CLOUD_URL as string | undefined);

const API_KEY =
  (import.meta.env.VITE_OLONJS_API_KEY as string | undefined) ??
  (import.meta.env.VITE_JSONPAGES_API_KEY as string | undefined);

interface UseOlonFormsOptions {
  /** Override the submit endpoint. Defaults to VITE_OLONJS_CLOUD_URL/forms/submit */
  endpoint?: string;
}

/**
 * Mount once in App.tsx. Scans the DOM for all <form data-olon-recipient="...">
 * elements and attaches submit handlers. Returns per-form states to be provided
 * via OlonFormsContext.Provider.
 *
 * Views consume state via useFormState(formId) — no direct coupling to this hook.
 */
export function useOlonForms(options?: UseOlonFormsOptions): { states: Record<string, FormState> } {
  const [states, setStates] = useState<Record<string, FormState>>({});

  const setFormState = useCallback((formId: string, state: FormState) => {
    setStates((prev) => ({ ...prev, [formId]: state }));
  }, []);

  useEffect(() => {
    const resolvedBase = options?.endpoint
      ? options.endpoint.replace(/\/$/, '')
      : API_BASE
        ? API_BASE.replace(/\/$/, '')
        : null;

    if (!resolvedBase || !API_KEY) {
      console.warn('[useOlonForms] Missing API endpoint or key — forms will not submit.');
      return;
    }

    const endpoint = resolvedBase.endsWith('/forms/submit')
      ? resolvedBase
      : `${resolvedBase}/forms/submit`;

    const forms = Array.from(
      document.querySelectorAll<HTMLFormElement>('form[data-olon-recipient]')
    );

    const controllers: AbortController[] = [];

    async function handleSubmit(form: HTMLFormElement, event: SubmitEvent) {
      event.preventDefault();

      const formId = form.id || form.dataset.olonRecipient || 'olon-form';
      const recipientEmail = form.dataset.olonRecipient ?? '';

      setFormState(formId, { status: 'submitting', message: 'Invio in corso...' });

      const raw: Record<string, string> = {};
      new FormData(form).forEach((value, key) => {
        raw[key] = String(value).trim();
      });

      const payload = {
        ...raw,
        recipientEmail,
        page: window.location.pathname,
        source: 'olon-form',
        submittedAt: new Date().toISOString(),
      };

      const controller = new AbortController();
      controllers.push(controller);

      try {
        const response = await fetch(endpoint, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${API_KEY}`,
            'Content-Type': 'application/json',
            'Idempotency-Key': `form-${formId}-${Date.now()}`,
          },
          body: JSON.stringify(payload),
          signal: controller.signal,
        });

        const body = (await response.json().catch(() => ({}))) as {
          error?: string;
          code?: string;
        };

        if (!response.ok) {
          throw new Error(body.error ?? body.code ?? `Submit failed (${response.status})`);
        }

        setFormState(formId, {
          status: 'success',
          message: 'Richiesta inviata con successo.',
        });
        form.reset();
      } catch (error: unknown) {
        if (error instanceof Error && error.name === 'AbortError') return;
        const message =
          error instanceof Error ? error.message : 'Invio non riuscito. Riprova.';
        setFormState(formId, { status: 'error', message });
      }
    }

    type Listener = { form: HTMLFormElement; handler: (e: Event) => void };
    const listeners: Listener[] = [];

    forms.forEach((form) => {
      const handler = (e: Event) => void handleSubmit(form, e as SubmitEvent);
      form.addEventListener('submit', handler);
      listeners.push({ form, handler });
    });

    return () => {
      controllers.forEach((c) => c.abort());
      listeners.forEach(({ form, handler }) => form.removeEventListener('submit', handler));
    };
  }, [options?.endpoint, setFormState]);

  return { states };
}

END_OF_FILE_CONTENT
echo "Creating src/lib/useTenantBootstrap.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/useTenantBootstrap.ts"
import { useEffect, useMemo, useRef, useState } from 'react';

import { logBootstrapEvent, toCloudLoadFailure } from '@/lib/cloud/bootstrapTelemetry';

import { cloudFingerprint, readCachedPages, writeCachedCloudContent } from '@/lib/cloud/cloudCache';

import type { CloudLoadFailure, ContentMode } from '@/lib/cloud/types';

import { getHydratedData } from '@/lib/draftStorage';

import {

  buildApiCandidates,

  fetchRenderProjection,

  isAdminPath,

  normalizeRenderPath,

  patchHistoryNavigation,

  resolveRegistrySlugFromRender,

  type RenderProjectionResponse,

} from '@/lib/spp';

import type { JsonPagesConfig } from '@olonjs/core';

import { APP_BASE_PATH, CLOUD_API_KEY, CLOUD_API_URL, SAVE2REPO_ENABLED } from '@/lib/tenantEnv';

import type { MenuConfig, PageConfig, SiteConfig, ThemeConfig } from '@/types';

import { loadPublishedStaticContent } from '@/lib/cloud/staticContent';



const EMPTY_COLLECTIONS = {} as NonNullable<JsonPagesConfig['collections']>;

const MAX_BOOTSTRAP_RETRIES = 2;



type UseTenantBootstrapOptions = {

  tenantId: string;

  filePages: Record<string, PageConfig>;

  fileSiteConfig: SiteConfig;

  menuConfigSeed: MenuConfig;

  themeConfigSeed: ThemeConfig;

};



function applyCachedBootstrap(params: {

  cachedPages: Record<string, PageConfig> | null;

  cachedSite: SiteConfig | null;

  cachedCollections?: JsonPagesConfig['collections'];

  setPages: (pages: Record<string, PageConfig>) => void;

  setSiteConfig: (site: SiteConfig) => void;

  setCollections: (collections: NonNullable<JsonPagesConfig['collections']>) => void;

}): boolean {

  const { cachedPages, cachedSite, cachedCollections, setPages, setSiteConfig, setCollections } = params;

  const hasPages = Boolean(cachedPages && Object.keys(cachedPages).length > 0);

  const hasSite = Boolean(cachedSite);

  if (!hasPages && !hasSite) return false;



  if (cachedPages && hasPages) setPages(cachedPages);

  if (cachedSite) setSiteConfig(cachedSite);

  if (cachedCollections) setCollections(cachedCollections);

  return true;

}



export function useTenantBootstrap({

  tenantId,

  filePages,

  fileSiteConfig,

  menuConfigSeed,

  themeConfigSeed,

}: UseTenantBootstrapOptions) {

  const isCloudMode = Boolean(CLOUD_API_URL && CLOUD_API_KEY);

  const isSave2RepoMode = isCloudMode && SAVE2REPO_ENABLED;

  const isHotSaveMode = isCloudMode && !isSave2RepoMode;

  const useRenderBootstrap = isHotSaveMode;



  const localInitialData = useMemo(

    () => (isCloudMode ? null : getHydratedData(tenantId, filePages, fileSiteConfig)),

    [isCloudMode, tenantId, filePages, fileSiteConfig],

  );

  const localInitialPages = useMemo(() => {

    if (!localInitialData) return {};

    return localInitialData.pages;

  }, [localInitialData]);



  const [pages, setPages] = useState<Record<string, PageConfig>>(localInitialPages);

  const [siteConfig, setSiteConfig] = useState<SiteConfig>(localInitialData?.siteConfig ?? fileSiteConfig);

  const [menuConfig, setMenuConfig] = useState<MenuConfig>(menuConfigSeed);

  const [themeConfig] = useState<ThemeConfig>(themeConfigSeed);

  const [collections, setCollections] = useState<NonNullable<JsonPagesConfig['collections']>>(EMPTY_COLLECTIONS);

  const [contentMode, setContentMode] = useState<ContentMode>('cloud');

  const [contentFallback, setContentFallback] = useState<CloudLoadFailure | null>(null);

  const [showTopProgress, setShowTopProgress] = useState(false);

  const [hasInitialCloudResolved, setHasInitialCloudResolved] = useState(!isCloudMode);

  const [bootstrapRunId, setBootstrapRunId] = useState(0);



  const contentLoadInFlight = useRef<Promise<void> | null>(null);

  const sppRenderInFlightRef = useRef<string | null>(null);

  const sppBootstrappedRef = useRef(false);



  const cloudApiCandidates = useMemo(

    () => (isCloudMode && CLOUD_API_URL ? buildApiCandidates(CLOUD_API_URL) : []),

    [isCloudMode],

  );



  const isTenantEmpty = Object.keys(pages).length === 0;



  const retryBootstrap = () => {

    contentLoadInFlight.current = null;

    setContentMode('cloud');

    setContentFallback(null);

    setHasInitialCloudResolved(false);

    setShowTopProgress(true);

    setBootstrapRunId((prev) => prev + 1);

  };



  useEffect(() => {

    if (!isCloudMode || !CLOUD_API_URL || !CLOUD_API_KEY) {

      setContentMode('cloud');

      setContentFallback(null);

      setShowTopProgress(false);

      setHasInitialCloudResolved(true);

      logBootstrapEvent('boot.local.ready', { mode: 'local' });

      return;

    }



    if (isSave2RepoMode) {

      if (contentLoadInFlight.current) return;



      setContentMode('cloud');

      setContentFallback(null);

      setShowTopProgress(true);

      setHasInitialCloudResolved(false);

      logBootstrapEvent('boot.start', { mode: 'save2repo-static', pageCount: Object.keys(filePages).length });



      let inFlight: Promise<void> | null = null;

      inFlight = loadPublishedStaticContent(Object.keys(filePages), APP_BASE_PATH)

        .then(({ pages: nextPages, siteConfig: nextSite }) => {

          setPages(nextPages);

          setSiteConfig(nextSite);

          setContentMode('cloud');

          setContentFallback(null);

          setHasInitialCloudResolved(true);

          logBootstrapEvent('boot.save2repo.success', {

            mode: 'save2repo-static',

            pageCount: Object.keys(nextPages).length,

          });

        })

        .catch((error: unknown) => {

          const failure = toCloudLoadFailure(error);

          setContentMode('error');

          setContentFallback(failure);

          setHasInitialCloudResolved(true);

          logBootstrapEvent('boot.save2repo.error', {

            mode: 'save2repo-static',

            reasonCode: failure.reasonCode,

            correlationId: failure.correlationId ?? null,

          });

        })

        .finally(() => {

          setShowTopProgress(false);

          if (contentLoadInFlight.current === inFlight) {

            contentLoadInFlight.current = null;

          }

        });

      contentLoadInFlight.current = inFlight;

      return () => {

        contentLoadInFlight.current = null;

      };

    }



    if (!useRenderBootstrap) return;

    if (contentLoadInFlight.current) return;



    if (isAdminPath(window.location.pathname, APP_BASE_PATH)) {

      setContentMode('cloud');

      setContentFallback(null);

      setShowTopProgress(false);

      setHasInitialCloudResolved(true);

      return;

    }



    const controller = new AbortController();

    const startedAt = Date.now();

    const primaryApiBase = cloudApiCandidates[0] ?? CLOUD_API_URL.trim().replace(/\/+$/, '');

    const fingerprint = cloudFingerprint(primaryApiBase, CLOUD_API_KEY);

    const { cached, cachedSite } = readCachedPages(fingerprint);

    sppBootstrappedRef.current = false;

    setContentMode('cloud');

    setContentFallback(null);

    setShowTopProgress(true);

    setHasInitialCloudResolved(false);

    logBootstrapEvent('boot.start', {

      mode: 'spp-render',

      apiCandidates: cloudApiCandidates.length,

    });



    const applyRenderPayload = (result: RenderProjectionResponse) => {

      if (!result.page) return;

      const registrySlug = resolveRegistrySlugFromRender(result.page);

      setPages((prev) => ({ ...prev, [registrySlug]: result.page! }));

      if (result.context?.siteConfig) setSiteConfig(result.context.siteConfig);

      if (result.context?.menuConfig) setMenuConfig(result.context.menuConfig);

      writeCachedCloudContent({

        keyFingerprint: fingerprint,

        savedAt: Date.now(),

        siteConfig: result.context?.siteConfig ?? cachedSite ?? null,

        pages: {

          ...(cached?.pages ?? {}),

          [registrySlug]: result.page,

        },

        collections: cached?.collections,

      });

    };



    const loadRenderPath = async (pathname: string, options?: { initial?: boolean }) => {

      if (controller.signal.aborted) return;

      if (isAdminPath(pathname, APP_BASE_PATH)) return;



      const renderPath = normalizeRenderPath(pathname, APP_BASE_PATH);

      const inFlightKey = renderPath;

      if (sppRenderInFlightRef.current === inFlightKey) return;

      sppRenderInFlightRef.current = inFlightKey;



      try {

        const result = await fetchRenderProjection(

          cloudApiCandidates,

          CLOUD_API_KEY,

          renderPath,

          { signal: controller.signal, maxRetryAttempts: MAX_BOOTSTRAP_RETRIES },

        );



        if (!result.ok) {

          if (options?.initial) {

            throw {

              reasonCode: result.code || 'RENDER_FAILED',

              message: result.error || 'Render projection failed',

              correlationId: result.correlationId,

            } satisfies CloudLoadFailure;

          }

          logBootstrapEvent('boot.spp_render.route_error', {

            path: renderPath,

            code: result.code ?? null,

          });

          return;

        }



        applyRenderPayload(result);

        if (options?.initial) {

          sppBootstrappedRef.current = true;

          setContentMode('cloud');

          setContentFallback(null);

          setHasInitialCloudResolved(true);

          logBootstrapEvent('boot.spp_render.success', {

            elapsedMs: Date.now() - startedAt,

            projectionMode: result.diagnostics?.projectionMode ?? null,

            correlationId: result.correlationId ?? null,

          });

        } else {

          logBootstrapEvent('boot.spp_render.route_success', {

            path: renderPath,

            correlationId: result.correlationId ?? null,

          });

        }

      } finally {

        if (sppRenderInFlightRef.current === inFlightKey) {

          sppRenderInFlightRef.current = null;

        }

      }

    };



    const bootstrap = async () => {

      try {

        await loadRenderPath(window.location.pathname, { initial: true });

      } catch (error: unknown) {

        if (controller.signal.aborted) return;

        const failure = toCloudLoadFailure(error);

        const { cachedPages, cachedSite } = readCachedPages(fingerprint);

        const hasCachedFallback = applyCachedBootstrap({

          cachedPages,

          cachedSite,

          cachedCollections: cached?.collections,

          setPages,

          setSiteConfig,

          setCollections,

        });

        if (hasCachedFallback) {

          setContentMode('cloud');

          setContentFallback({

            reasonCode: 'RENDER_FAILED',

            message: failure.message,

            correlationId: failure.correlationId,

          });

          setHasInitialCloudResolved(true);

        } else {

          setContentMode('error');

          setContentFallback(failure);

          setHasInitialCloudResolved(true);

        }

        logBootstrapEvent('boot.spp_render.error', {

          reasonCode: failure.reasonCode,

          correlationId: failure.correlationId ?? null,

        });

      } finally {

        setShowTopProgress(false);

      }

    };



    let inFlight: Promise<void> | null = null;

    inFlight = bootstrap().finally(() => {

      if (contentLoadInFlight.current === inFlight) {

        contentLoadInFlight.current = null;

      }

    });

    contentLoadInFlight.current = inFlight;



    const unpatchHistory = patchHistoryNavigation(() => {

      if (!sppBootstrappedRef.current) return;

      void loadRenderPath(window.location.pathname);

    });



    return () => {

      controller.abort();

      unpatchHistory();

      contentLoadInFlight.current = null;

    };

  }, [

    isCloudMode,

    isSave2RepoMode,

    useRenderBootstrap,

    cloudApiCandidates,

    filePages,

    bootstrapRunId,

  ]);



  const shouldRenderEngine = !isCloudMode || hasInitialCloudResolved;



  return {

    pages,

    siteConfig,

    menuConfig,

    themeConfig,

    enginePages: pages,

    collections,

    setPages,

    setSiteConfig,

    setCollections,

    cloudApiCandidates,

    isCloudMode,

    isSave2RepoMode,

    isHotSaveMode,

    contentMode,

    contentFallback,

    showTopProgress,

    hasInitialCloudResolved,

    shouldRenderEngine,

    isTenantEmpty,

    retryBootstrap,

  };

}



END_OF_FILE_CONTENT
echo "Creating src/lib/utils.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/utils.ts"
import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

END_OF_FILE_CONTENT
echo "Creating src/main.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/main.tsx"
import '@/types'; // TBP: load type augmentation from capsule-driven types
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
// ... resto del file

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);




END_OF_FILE_CONTENT
echo "Creating src/runtime.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/runtime.ts"
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

END_OF_FILE_CONTENT
echo "Creating src/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/types.ts"
import type { HeaderData, HeaderSettings } from '@/components/header';
import type { FooterData, FooterSettings } from '@/components/footer';
import type { EditorialHeroData, EditorialHeroSettings } from '@/components/editorial-hero';
import type { PageHeroData, PageHeroSettings } from '@/components/page-hero';
import type { FeaturedProjectsData, FeaturedProjectsSettings } from '@/components/featured-projects';
import type { BlogRollupData, BlogRollupSettings } from '@/components/blog-rollup';
import type { BioPanelData, BioPanelSettings } from '@/components/bio-panel';
import type { ContactCtaData, ContactCtaSettings } from '@/components/contact-cta';
import type { TimelineData, TimelineSettings } from '@/components/timeline';
import type { SkillsGridData, SkillsGridSettings } from '@/components/skills-grid';
import type { PhilosophyData, PhilosophySettings } from '@/components/philosophy';
import type { ContactFormData, ContactFormSettings } from '@/components/contact-form';
import type { ProjectDetailData, ProjectDetailSettings } from '@/components/project-detail';
import type { PostDetailData, PostDetailSettings } from '@/components/post-detail';

export type SectionComponentPropsMap = {
  'header': { data: HeaderData; settings: HeaderSettings };
  'footer': { data: FooterData; settings: FooterSettings };
  'editorial-hero': { data: EditorialHeroData; settings: EditorialHeroSettings };
  'page-hero': { data: PageHeroData; settings: PageHeroSettings };
  'featured-projects': { data: FeaturedProjectsData; settings: FeaturedProjectsSettings };
  'blog-rollup': { data: BlogRollupData; settings: BlogRollupSettings };
  'bio-panel': { data: BioPanelData; settings: BioPanelSettings };
  'contact-cta': { data: ContactCtaData; settings: ContactCtaSettings };
  'timeline': { data: TimelineData; settings: TimelineSettings };
  'skills-grid': { data: SkillsGridData; settings: SkillsGridSettings };
  'philosophy': { data: PhilosophyData; settings: PhilosophySettings };
  'contact-form': { data: ContactFormData; settings: ContactFormSettings };
  'project-detail': { data: ProjectDetailData; settings: ProjectDetailSettings };
  'post-detail': { data: PostDetailData; settings: PostDetailSettings };
};

declare module '@olonjs/core' {
  export interface SectionDataRegistry {
    'header': HeaderData;
    'footer': FooterData;
    'editorial-hero': EditorialHeroData;
    'page-hero': PageHeroData;
    'featured-projects': FeaturedProjectsData;
    'blog-rollup': BlogRollupData;
    'bio-panel': BioPanelData;
    'contact-cta': ContactCtaData;
    'timeline': TimelineData;
    'skills-grid': SkillsGridData;
    'philosophy': PhilosophyData;
    'contact-form': ContactFormData;
    'project-detail': ProjectDetailData;
    'post-detail': PostDetailData;
  }
  export interface SectionSettingsRegistry {
    'header': HeaderSettings;
    'footer': FooterSettings;
    'editorial-hero': EditorialHeroSettings;
    'page-hero': PageHeroSettings;
    'featured-projects': FeaturedProjectsSettings;
    'blog-rollup': BlogRollupSettings;
    'bio-panel': BioPanelSettings;
    'contact-cta': ContactCtaSettings;
    'timeline': TimelineSettings;
    'skills-grid': SkillsGridSettings;
    'philosophy': PhilosophySettings;
    'contact-form': ContactFormSettings;
    'project-detail': ProjectDetailSettings;
    'post-detail': PostDetailSettings;
  }
}

export * from '@olonjs/core';

END_OF_FILE_CONTENT
echo "Creating src/vercel.json..."
cat << 'END_OF_FILE_CONTENT' > "src/vercel.json"
{
  "rewrites": [
    {
      "source": "/robots.txt",
      "destination": "https://bat5elmxofxdroan.public.blob.vercel-storage.com/tenants/santa1/robots.txt"
    },
    {
      "source": "/sitemap.xml",
      "destination": "https://bat5elmxofxdroan.public.blob.vercel-storage.com/tenants/santa1/sitemap.xml"
    },
    {
      "source": "/llms.txt",
      "destination": "https://bat5elmxofxdroan.public.blob.vercel-storage.com/tenants/santa1/llms.txt"
    },
    {
      "source": "/.well-known/agent-card.json",
      "destination": "https://bat5elmxofxdroan.public.blob.vercel-storage.com/tenants/santa1/.well-known/agent-card.json"
    },
    {
      "source": "/mcp-manifest.json",
      "destination": "https://bat5elmxofxdroan.public.blob.vercel-storage.com/tenants/santa1/mcp-manifest.json"
    },
    {
      "source": "/mcp-manifests/:path*.json",
      "destination": "https://bat5elmxofxdroan.public.blob.vercel-storage.com/tenants/santa1/mcp-manifests/:path*.json"
    },
    {
      "source": "/schemas/:path*.json",
      "destination": "https://bat5elmxofxdroan.public.blob.vercel-storage.com/tenants/santa1/schemas/:path*.json"
    },
    {
      "source": "/:path*.json",
      "destination": "https://bat5elmxofxdroan.public.blob.vercel-storage.com/tenants/santa1/pages/:path*.json"
    },
    {
      "source": "/(.*)",
      "destination": "/index.html"
    }
  ],
  "headers": [
    {
      "source": "/assets/(.*)",
      "headers": [
        {
          "key": "Cache-Control",
          "value": "public, max-age=31536000, immutable"
        }
      ]
    }
  ]
}
END_OF_FILE_CONTENT
echo "Creating src/vite-env.d.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/vite-env.d.ts"
/// <reference types="vite/client" />

declare module '*?inline' {
  const content: string;
  export default content;
}



END_OF_FILE_CONTENT
