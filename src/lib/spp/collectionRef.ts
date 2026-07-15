import type { CollectionSliceDescriptor, CollectionSliceSort } from './types';

/** SPP §2.3 — sibling keys on a collection `$ref`; never collection entities. */
export const COLLECTION_REF_SIBLING_KEYS = new Set([
  '$ref',
  'limit',
  'pageSize',
  '$sliceSort',
  '$sliceFilter',
]);

export function isCollectionRef(value: unknown): value is Record<string, unknown> & { $ref: string } {
  return (
    typeof value === 'object' &&
    value !== null &&
    !Array.isArray(value) &&
    typeof (value as { $ref?: unknown }).$ref === 'string' &&
    (value as { $ref: string }).$ref.trim().length > 0
  );
}

export function isCollectionItem(value: unknown): value is Record<string, unknown> & { id: string } {
  return (
    typeof value === 'object' &&
    value !== null &&
    !Array.isArray(value) &&
    typeof (value as { id?: unknown }).id === 'string' &&
    (value as { id: string }).id.trim().length > 0
  );
}

function readSliceSort(value: unknown): CollectionSliceSort | undefined {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return undefined;
  const record = value as Record<string, unknown>;
  if (typeof record.field !== 'string' || !record.field.trim()) return undefined;
  if (record.direction !== 'asc' && record.direction !== 'desc') return undefined;
  return { field: record.field.trim(), direction: record.direction };
}

function readPositiveInt(value: unknown): number | undefined {
  if (typeof value !== 'number' || !Number.isFinite(value)) return undefined;
  const next = Math.floor(value);
  return next > 0 ? next : undefined;
}

/** Read SPP slice descriptor from an unresolved `$ref` or a resolved record polluted by ref siblings. */
export function readCollectionSliceDescriptor(
  value: unknown,
  fallback?: { limit?: number; pageSize?: number },
): CollectionSliceDescriptor {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return { limit: fallback?.limit ?? fallback?.pageSize };
  }

  const record = value as Record<string, unknown>;
  const limit =
    readPositiveInt(record.limit) ??
    readPositiveInt(record.pageSize) ??
    fallback?.limit ??
    fallback?.pageSize;

  const sort = readSliceSort(record.$sliceSort);
  const filter =
    record.$sliceFilter &&
    typeof record.$sliceFilter === 'object' &&
    !Array.isArray(record.$sliceFilter)
      ? (record.$sliceFilter as Record<string, string>)
      : undefined;

  return { limit, sort, filter };
}

/** Normalize any keyed collection payload; strips SPP ref siblings and non-entity entries. */
export function normalizeCollectionRecord<T extends Record<string, unknown> & { id: string }>(
  value: unknown,
  isItem: (candidate: unknown) => candidate is T = isCollectionItem as (candidate: unknown) => candidate is T,
): Record<string, T> | undefined {
  if (!value || typeof value !== 'object') return undefined;
  if (isCollectionRef(value)) return undefined;

  if (Array.isArray(value)) {
    const entries = value.filter(isItem).map((item) => [item.id, item] as const);
    return entries.length > 0 ? Object.fromEntries(entries) : undefined;
  }

  const entries = Object.entries(value as Record<string, unknown>)
    .filter(([key]) => !COLLECTION_REF_SIBLING_KEYS.has(key))
    .filter((entry): entry is [string, T] => isItem(entry[1]));

  return entries.length > 0 ? Object.fromEntries(entries) : undefined;
}

