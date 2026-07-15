import { useEffect, useRef, useState } from 'react';
import { fetchCollectionTotal } from './collectionsClient';
import { getSppCloudConfig } from './cloudConfig';
import { authorPostTotalCache, authorPostTotalQueue } from './lazyCollectionTotalQueue';

export function useLazyAuthorPostTotal(authorId: string) {
  const cloud = getSppCloudConfig();
  const elementRef = useRef<HTMLAnchorElement>(null);
  const [total, setTotal] = useState<number | null>(() => authorPostTotalCache.get(authorId) ?? null);
  const [loading, setLoading] = useState(false);
  const abortRef = useRef<AbortController | null>(null);

  useEffect(() => {
    setTotal(authorPostTotalCache.get(authorId) ?? null);
  }, [authorId]);

  useEffect(() => {
    if (!cloud.enabled) return;
    const node = elementRef.current;
    if (!node) return;

    const observer = new IntersectionObserver(
      ([entry]) => {
        if (!entry) return;

        if (!entry.isIntersecting) {
          authorPostTotalQueue.remove(authorId);
          abortRef.current?.abort();
          abortRef.current = null;
          if (!authorPostTotalCache.has(authorId)) {
            setLoading(false);
          }
          return;
        }

        authorPostTotalQueue.clearRemoved(authorId);

        if (authorPostTotalCache.has(authorId)) {
          setTotal(authorPostTotalCache.get(authorId)!);
          setLoading(false);
          return;
        }

        abortRef.current?.abort();
        const controller = new AbortController();
        abortRef.current = controller;
        setLoading(true);

        authorPostTotalQueue.schedule({
          id: authorId,
          signal: controller.signal,
          execute: () =>
            fetchCollectionTotal('posts', {
              filter: { 'author.id': authorId },
              signal: controller.signal,
            }),
          onDone: (value) => {
            authorPostTotalCache.set(authorId, value);
            setTotal(value);
            setLoading(false);
          },
          onCancelled: () => {
            if (!authorPostTotalCache.has(authorId)) {
              setLoading(false);
            }
          },
        });
      },
      { rootMargin: '120px 0px' },
    );

    observer.observe(node);
    return () => {
      observer.disconnect();
      authorPostTotalQueue.remove(authorId);
      abortRef.current?.abort();
      abortRef.current = null;
    };
  }, [authorId, cloud.enabled]);

  return { elementRef, total, loading, cloudEnabled: cloud.enabled };
}

