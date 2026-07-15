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

