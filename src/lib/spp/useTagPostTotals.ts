import { useEffect, useState } from 'react';
import { getSppCloudConfig } from './cloudConfig';
import { readCachedCollectionTotal, requestCollectionTotal } from './collectionTotalQueue';

function tagFilter(slug: string): Record<string, string> {
  return { 'tag.slug': slug };
}

export function useTagPostTotals(tagSlugs: string[]) {
  const cloud = getSppCloudConfig();
  const tagSlugsKey = tagSlugs.join('|');
  const [totals, setTotals] = useState<Record<string, number>>(() => {
    const initial: Record<string, number> = {};
    for (const slug of tagSlugs) {
      const cached = readCachedCollectionTotal('posts', tagFilter(slug));
      if (cached != null) initial[slug] = cached;
    }
    return initial;
  });

  useEffect(() => {
    if (!cloud.enabled || tagSlugs.length === 0) return;
    let cancelled = false;

    for (const slug of tagSlugs) {
      const cached = readCachedCollectionTotal('posts', tagFilter(slug));
      if (cached != null) {
        setTotals((prev) => (prev[slug] === cached ? prev : { ...prev, [slug]: cached }));
        continue;
      }

      void requestCollectionTotal('posts', tagFilter(slug))
        .then((total) => {
          if (!cancelled) {
            setTotals((prev) => (prev[slug] === total ? prev : { ...prev, [slug]: total }));
          }
        })
        .catch(() => {
          // requestCollectionTotal already retried; a remount or slug change can retry.
        });
    }

    return () => {
      cancelled = true;
    };
  }, [tagSlugsKey, cloud.enabled, tagSlugs]);

  return totals;
}

