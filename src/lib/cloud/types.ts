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

