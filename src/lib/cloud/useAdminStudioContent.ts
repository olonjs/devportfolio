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

