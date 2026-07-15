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

