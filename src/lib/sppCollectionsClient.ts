import { readCollectionSliceDescriptor } from '@/lib/spp';

export function readCollectionRefLimit(value: unknown, fallback?: number): number | undefined {
  const { limit } = readCollectionSliceDescriptor(value, { limit: fallback, pageSize: fallback });
  return limit;
}

export { fetchCollectionSlice, readCollectionSliceDescriptor } from '@/lib/spp';
export type { CollectionPagination, CollectionSliceSort } from '@/lib/spp';

