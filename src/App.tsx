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
import { hydrateLocalProjectState } from '@/lib/hydrateLocalProjectState';

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
    enabled: bootstrap.isCloudMode,
    apiCandidates: bootstrap.cloudApiCandidates,
    apiKey: CLOUD_API_KEY,
    setPages: bootstrap.setPages,
    setSiteConfig: bootstrap.setSiteConfig,
    setMenuConfig: bootstrap.setMenuConfig,
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

  const engineCollections =
    bootstrap.isHotSaveMode || Object.keys(bootstrap.collections).length > 0
      ? bootstrap.collections
      : fileCollections;
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
        hydrateLocalProjectState({
          state,
          slug,
          setPages: bootstrap.setPages,
          setSiteConfig: bootstrap.setSiteConfig,
          setMenuConfig: bootstrap.setMenuConfig,
          setThemeConfig: bootstrap.setThemeConfig,
          setCollections: bootstrap.setCollections,
        });
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

