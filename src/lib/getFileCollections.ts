import type { JsonPagesConfig } from '@/types';

type CollectionDocuments = NonNullable<JsonPagesConfig['collections']>;

function collectionSourceFromPath(filePath: string): string | null {
  const normalizedPath = filePath.replace(/\\/g, '/');
  const match = normalizedPath.match(/\/data\/collections\/([^/]+)\/[^/]+\.json$/i);
  return match?.[1]?.trim() || null;
}

export function getFileCollections(): CollectionDocuments {
  const glob = import.meta.glob<{ default: unknown }>('@/data/collections/**/*.json', { eager: true });
  const bySource = new Map<string, Record<string, unknown>>();
  const entries = Object.entries(glob).sort(([a], [b]) => a.localeCompare(b));

  for (const [path, mod] of entries) {
    const source = collectionSourceFromPath(path);
    const raw = mod?.default;
    if (!source) {
      console.warn(`[tenant-alpha:getFileCollections] Ignoring collection module with invalid path "${path}".`);
      continue;
    }
    if (raw == null || typeof raw !== 'object' || Array.isArray(raw)) {
      console.warn(`[tenant-alpha:getFileCollections] Ignoring invalid collection module at "${path}".`);
      continue;
    }
    if (bySource.has(source)) {
      console.warn(`[tenant-alpha:getFileCollections] Duplicate collection source "${source}" at "${path}". Keeping latest match.`);
    }
    bySource.set(source, raw as Record<string, unknown>);
  }

  const collections: CollectionDocuments = {};
  for (const source of Array.from(bySource.keys()).sort((a, b) => a.localeCompare(b))) {
    const collection = bySource.get(source);
    if (collection) collections[source] = collection;
  }
  return collections;
}

