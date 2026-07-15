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

