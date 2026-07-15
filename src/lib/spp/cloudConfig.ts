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

