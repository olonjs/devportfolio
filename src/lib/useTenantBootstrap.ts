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

  const useRenderBootstrap = isHotSaveMode || isSave2RepoMode;



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

  const [themeConfig, setThemeConfig] = useState<ThemeConfig>(themeConfigSeed);

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

          // Keep parametric registry templates from DNA so Studio / router still see them.
          setPages((prev) => ({ ...filePages, ...prev, ...nextPages }));

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

    setMenuConfig,

    setThemeConfig,

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



