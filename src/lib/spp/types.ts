export type CollectionSliceSort = {
  field: string;
  direction: 'asc' | 'desc';
};

export type CollectionPagination = {
  total: number;
  hasMore: boolean;
  nextOffset: number | null;
};

export type CollectionSliceResult<T extends Record<string, unknown> = Record<string, unknown>> = {
  items: Record<string, T>;
  pagination: CollectionPagination;
};

export type CollectionSliceDescriptor = {
  limit?: number;
  sort?: CollectionSliceSort;
  filter?: Record<string, string>;
};

export type CollectionItem = Record<string, unknown> & { id: string };

