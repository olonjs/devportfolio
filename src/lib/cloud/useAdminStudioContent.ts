import { useEffect, useRef } from 'react';
import type { Dispatch, SetStateAction } from 'react';
import type { JsonPagesConfig } from '@olonjs/core';
import { applyLegacyCloudPayload, fetchAdminCloudRenderPayload } from '@/lib/cloud/cloudContentClient';
import { cloudFingerprint, writeCachedCloudContent } from '@/lib/cloud/cloudCache';
import { isAdminPath, patchHistoryNavigation } from '@/lib/spp';
import { APP_BASE_PATH } from '@/lib/tenantEnv';
import type { MenuConfig, PageConfig, SiteConfig } from '@/types';

const MAX_RETRIES = 2;

type UseAdminStudioContentOptions = {
  enabled: boolean;
  apiCandidates: string[];
  apiKey: string;
  setPages: Dispatch<SetStateAction<Record<string, PageConfig>>>;
  setSiteConfig: Dispatch<SetStateAction<SiteConfig>>;
  setMenuConfig?: Dispatch<SetStateAction<MenuConfig>>;
  setCollections: Dispatch<SetStateAction<NonNullable<JsonPagesConfig['collections']>>>;
};

/** Studio `/admin` sync via SPP `/render` — never mixed into visitor bootstrap. */
export function useAdminStudioContent({
  enabled,
  apiCandidates,
  apiKey,
  setPages,
  setSiteConfig,
  setMenuConfig,
  setCollections,
}: UseAdminStudioContentOptions) {
  const lastSyncedPathRef = useRef<string | null>(null);
  const inFlightRef = useRef<Promise<void> | null>(null);

  useEffect(() => {
    if (!enabled || apiCandidates.length === 0 || !apiKey.trim()) return;

    const syncIfAdmin = () => {
      if (!isAdminPath(window.location.pathname, APP_BASE_PATH)) return;
      const currentPath = window.location.pathname;
      if (lastSyncedPathRef.current === currentPath || inFlightRef.current) return;

      const controller = new AbortController();
      const fingerprint = cloudFingerprint(apiCandidates[0]!, apiKey);
      lastSyncedPathRef.current = currentPath;

      inFlightRef.current = fetchAdminCloudRenderPayload(
        apiCandidates,
        apiKey,
        currentPath,
        controller.signal,
        MAX_RETRIES,
      )
        .then((payload) => {
          const { remotePages, remoteSite } = applyLegacyCloudPayload(payload, {
            setPages,
            setSiteConfig,
          });
          if (payload.menuConfig && setMenuConfig) {
            setMenuConfig(payload.menuConfig as MenuConfig);
          }
          writeCachedCloudContent({
            keyFingerprint: fingerprint,
            savedAt: Date.now(),
            siteConfig: remoteSite ?? null,
            pages: (remotePages ?? {}) as Record<string, unknown>,
          });
        })
        .catch((error: unknown) => {
          if (import.meta.env.DEV) {
            console.warn('[admin-studio] render sync failed', error);
          }
          lastSyncedPathRef.current = null;
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
  }, [enabled, apiCandidates, apiKey, setPages, setSiteConfig, setMenuConfig, setCollections]);
}
