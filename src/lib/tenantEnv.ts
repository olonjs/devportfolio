import { normalizeBasePath } from '@olonjs/core';

export const CLOUD_API_URL =
  import.meta.env.VITE_OLONJS_CLOUD_URL ?? import.meta.env.VITE_JSONPAGES_CLOUD_URL;
export const CLOUD_API_KEY =
  import.meta.env.VITE_OLONJS_API_KEY ?? import.meta.env.VITE_JSONPAGES_API_KEY;
export const SAVE2REPO_ENABLED = import.meta.env.VITE_SAVE2REPO === 'true';
export const APP_BASE_PATH = normalizeBasePath(import.meta.env.BASE_URL || '/');
export const TENANT_ID = 'alpha';

