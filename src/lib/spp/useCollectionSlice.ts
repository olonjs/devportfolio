import { useCallback, useEffect, useRef, useState } from 'react';
import {
  isCollectionItem,
  isCollectionRef,
  normalizeCollectionRecord,
  readCollectionSliceDescriptor,
} from './collectionRef';
import { fetchCollectionSlice } from './collectionsClient';
import { getSppCloudConfig } from './cloudConfig';
import type { CollectionItem, CollectionPagination, CollectionSliceSort } from './types';

function initialPagination(
  loadedCount: number,
  pageSize: number,
  cloudEnabled: boolean,
  unresolvedRef: boolean,
): CollectionPagination {
  if (!cloudEnabled || pageSize <= 0) {
    return { total: 0, hasMore: false, nextOffset: null };
  }
  if (unresolvedRef || loadedCount === 0) {
    return { total: 0, hasMore: true, nextOffset: 0 };
  }
  if (loadedCount < pageSize) {
    return { total: 0, hasMore: true, nextOffset: loadedCount };
  }
  return {
    total: 0,
    hasMore: true,
    nextOffset: loadedCount,
  };
}

export function useCollectionSlice<T extends CollectionItem>(options: {
  collectionName: string;
  initialItems: unknown;
  pageSize: number;
  filter?: Record<string, string> | null;
  sort?: CollectionSliceSort;
  resetKey?: string | null;
  isItem?: (value: unknown) => value is T;
}) {
  const cloud = getSppCloudConfig();
  const isItem = options.isItem ?? (isCollectionItem as (value: unknown) => value is T);
  const descriptor = readCollectionSliceDescriptor(options.initialItems, { pageSize: options.pageSize });
  const sort = options.sort ?? descriptor.sort;
  const filterKey = options.filter ? JSON.stringify(options.filter) : '';
  const resetKey = options.resetKey ?? filterKey;

  const normalize = useCallback(
    (value: unknown) => normalizeCollectionRecord<T>(value, isItem) ?? {},
    [isItem],
  );

  const unresolvedRef = isCollectionRef(options.initialItems);

  const [mergedItems, setMergedItems] = useState<Record<string, T>>(() => normalize(options.initialItems));
  const [pagination, setPagination] = useState<CollectionPagination>(() => {
    const count = Object.keys(normalize(options.initialItems)).length;
    return initialPagination(count, options.pageSize, cloud.enabled, unresolvedRef);
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const inFlightRef = useRef(false);
  const mergedItemsRef = useRef(mergedItems);
  const paginationRef = useRef(pagination);
  mergedItemsRef.current = mergedItems;
  paginationRef.current = pagination;

  useEffect(() => {
    const base = normalize(options.initialItems);
    const count = Object.keys(base).length;
    mergedItemsRef.current = base;
    setMergedItems(base);
    const nextPagination = initialPagination(
      count,
      options.pageSize,
      cloud.enabled,
      isCollectionRef(options.initialItems),
    );
    paginationRef.current = nextPagination;
    setPagination(nextPagination);
    setError(null);
  }, [options.initialItems, options.pageSize, resetKey, cloud.enabled, normalize]);

  const loadMore = useCallback(async () => {
    if (!cloud.enabled || inFlightRef.current) return false;

    const loadedCount = Object.keys(mergedItemsRef.current).length;
    const currentPagination = paginationRef.current;
    if (!currentPagination.hasMore) return false;
    if (currentPagination.total > 0 && loadedCount >= currentPagination.total) {
      return false;
    }

    inFlightRef.current = true;
    setLoading(true);
    setError(null);

    try {
      const offset = currentPagination.nextOffset ?? loadedCount;

      const result = await fetchCollectionSlice<T>(options.collectionName, {
        limit: options.pageSize,
        offset,
        filter: options.filter ?? undefined,
        sort,
      });

      const nextItems = { ...mergedItemsRef.current, ...result.items };
      mergedItemsRef.current = nextItems;
      setMergedItems(nextItems);
      const mergedCount = Object.keys(nextItems).length;
      const total = result.pagination.total;
      const nextPagination: CollectionPagination = {
        total,
        hasMore: total > 0 ? mergedCount < total : result.pagination.hasMore,
        nextOffset: result.pagination.nextOffset ?? (Object.keys(result.items).length > 0 ? offset + Object.keys(result.items).length : null),
      };
      paginationRef.current = nextPagination;
      setPagination(nextPagination);
      return Object.keys(result.items).length > 0;
    } catch (fetchError: unknown) {
      setError(fetchError instanceof Error ? fetchError.message : 'Failed to load collection slice');
      return false;
    } finally {
      inFlightRef.current = false;
      setLoading(false);
    }
  }, [cloud.enabled, options.collectionName, options.filter, options.pageSize, sort]);

  useEffect(() => {
    if (!cloud.enabled) return;
    const loadedCount = Object.keys(mergedItemsRef.current).length;
    if (loadedCount >= options.pageSize) return;
    if (!paginationRef.current.hasMore) return;
    void loadMore();
  }, [cloud.enabled, options.pageSize, resetKey, loadMore]);

  useEffect(() => {
    if (!cloud.enabled) return;
    let cancelled = false;

    (async () => {
      if (paginationRef.current.total > 0) return;

      try {
        const result = await fetchCollectionSlice<T>(options.collectionName, {
          limit: 1,
          offset: 0,
          filter: options.filter ?? undefined,
          sort,
        });
        if (cancelled) return;

        const loadedCount = Object.keys(mergedItemsRef.current).length;
        const total = result.pagination.total;
        const nextPagination: CollectionPagination = {
          total,
          hasMore: loadedCount < total,
          nextOffset: loadedCount > 0 ? loadedCount : Object.keys(result.items).length,
        };
        paginationRef.current = nextPagination;
        setPagination(nextPagination);

        if (loadedCount === 0 && Object.keys(result.items).length > 0) {
          mergedItemsRef.current = result.items;
          setMergedItems(result.items);
        }
      } catch {
        // Total stays unknown until loadMore succeeds.
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [cloud.enabled, options.collectionName, options.filter, options.pageSize, sort, resetKey]);

  const ensureLoadedCount = useCallback(
    async (requiredCount: number) => {
      if (!cloud.enabled) return;
      for (let guard = 0; guard < 20; guard += 1) {
        const loadedCount = Object.keys(mergedItemsRef.current).length;
        const currentPagination = paginationRef.current;
        if (loadedCount >= requiredCount) return;
        if (currentPagination.total > 0 && loadedCount >= currentPagination.total) return;
        if (!currentPagination.hasMore) return;
        const loaded = await loadMore();
        if (!loaded) return;
      }
    },
    [cloud.enabled, loadMore],
  );

  return {
    cloudEnabled: cloud.enabled,
    sliceDescriptor: descriptor,
    mergedItems,
    pagination,
    loading,
    error,
    loadMore,
    ensureLoadedCount,
  };
}

