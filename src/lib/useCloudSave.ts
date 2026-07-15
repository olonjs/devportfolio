import { useCallback, useEffect, useRef, useState } from 'react';
import type { DeployPhase, ProjectState, StepId } from '@olonjs/core';
import { DEPLOY_STEPS, startCloudSaveStream } from '@olonjs/core';
import { APP_BASE_PATH, CLOUD_API_KEY, CLOUD_API_URL } from '@/lib/tenantEnv';

interface CloudSaveUiState {
  isOpen: boolean;
  phase: DeployPhase;
  currentStepId: StepId | null;
  doneSteps: StepId[];
  progress: number;
  errorMessage?: string;
  deployUrl?: string;
}

function getInitialCloudSaveUiState(): CloudSaveUiState {
  return {
    isOpen: false,
    phase: 'idle',
    currentStepId: null,
    doneSteps: [],
    progress: 0,
  };
}

function stepProgress(doneSteps: StepId[]): number {
  return Math.round((doneSteps.length / DEPLOY_STEPS.length) * 100);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function cloneJson<T>(value: T): T {
  return JSON.parse(JSON.stringify(value)) as T;
}

function normalizePathSegments(value: string): string {
  return value
    .split('/')
    .map((segment) => segment.trim())
    .filter(Boolean)
    .join('/');
}

function resolveAdminContentSlug(): string | null {
  if (typeof window === 'undefined') return null;

  const normalizedBase = APP_BASE_PATH.replace(/\/+$/, '');
  let path = window.location.pathname;
  if (normalizedBase && normalizedBase !== '/' && path.startsWith(normalizedBase)) {
    path = path.slice(normalizedBase.length) || '/';
  }

  const slug = normalizePathSegments(path.replace(/^\/admin\/?/, ''));
  return slug || null;
}

function resolveTemplateParamValue(templateSlug: string, concreteSlug: string, paramKey: string): string | null {
  const templateSegments = normalizePathSegments(templateSlug).split('/').filter(Boolean);
  const concreteSegments = normalizePathSegments(concreteSlug).split('/').filter(Boolean);
  if (templateSegments.length !== concreteSegments.length) return null;

  for (let index = 0; index < templateSegments.length; index += 1) {
    const templateSegment = templateSegments[index];
    const concreteSegment = concreteSegments[index];
    const paramMatch = templateSegment.match(/^\[([A-Za-z0-9_-]+)\]$/);
    if (paramMatch?.[1] === paramKey) return concreteSegment;
    if (!paramMatch && templateSegment !== concreteSegment) return null;
  }

  return null;
}

function hasCollectionCurrentRef(value: unknown): boolean {
  if (Array.isArray(value)) return value.some(hasCollectionCurrentRef);
  if (!isRecord(value)) return false;
  if (value.$ref === 'collection:current') return true;
  return Object.values(value).some(hasCollectionCurrentRef);
}

function replaceCollectionCurrentRefs(value: unknown, currentItem: unknown): unknown {
  if (Array.isArray(value)) return value.map((item) => replaceCollectionCurrentRefs(item, currentItem));
  if (!isRecord(value)) return value;
  if (value.$ref === 'collection:current') return cloneJson(currentItem);
  return Object.fromEntries(
    Object.entries(value).map(([key, entryValue]) => [key, replaceCollectionCurrentRefs(entryValue, currentItem)]),
  );
}

function buildSaveStreamPagePayload(state: ProjectState, fallbackSlug: string): { slug: string; page: ProjectState['page'] } {
  const page = state.page;
  const collection = page.collection;
  if (!collection || !hasCollectionCurrentRef(page)) {
    return { slug: fallbackSlug, page };
  }

  const concreteSlug = resolveAdminContentSlug();
  if (!concreteSlug) {
    throw new Error('Cannot resolve concrete admin route for collection page save.');
  }

  const paramValue = resolveTemplateParamValue(page.slug, concreteSlug, collection.paramKey);
  if (!paramValue) {
    throw new Error(`Cannot resolve collection param "${collection.paramKey}" from route "${concreteSlug}".`);
  }

  const collectionDocument = state.collections?.[collection.source];
  const currentItem = isRecord(collectionDocument) ? collectionDocument[paramValue] : undefined;
  if (!currentItem) {
    throw new Error(`Cannot resolve collection item "${collection.source}/${paramValue}" for save.`);
  }

  const resolvedPage = replaceCollectionCurrentRefs(page, currentItem) as ProjectState['page'];
  return {
    slug: concreteSlug,
    page: {
      ...resolvedPage,
      slug: concreteSlug,
    },
  };
}

export function useCloudSave() {
  const [cloudSaveUi, setCloudSaveUi] = useState<CloudSaveUiState>(getInitialCloudSaveUiState);
  const activeCloudSaveController = useRef<AbortController | null>(null);
  const pendingCloudSave = useRef<{ state: ProjectState; slug: string } | null>(null);

  useEffect(() => {
    return () => {
      activeCloudSaveController.current?.abort();
    };
  }, []);

  const runCloudSave = useCallback(
    async (payload: { state: ProjectState; slug: string }, rejectOnError: boolean): Promise<void> => {
      if (!CLOUD_API_URL || !CLOUD_API_KEY) {
        const noCloudError = new Error('Cloud mode is not configured.');
        if (rejectOnError) throw noCloudError;
        return;
      }

      pendingCloudSave.current = payload;
      activeCloudSaveController.current?.abort();
      const controller = new AbortController();
      activeCloudSaveController.current = controller;

      setCloudSaveUi({
        isOpen: true,
        phase: 'running',
        currentStepId: null,
        doneSteps: [],
        progress: 0,
      });

      try {
        const savePage = buildSaveStreamPagePayload(payload.state, payload.slug);
        await startCloudSaveStream({
          apiBaseUrl: CLOUD_API_URL,
          apiKey: CLOUD_API_KEY,
          path: `src/data/pages/${savePage.slug}.json`,
          content: savePage.page,
          additionalFiles: [
            { path: 'src/data/config/site.json', content: payload.state.site },
            { path: 'src/data/config/menu.json', content: payload.state.menu },
          ],
          changedScopes: ['page', 'site', 'menu'],
          message: `Content update for ${savePage.slug} via Visual Editor`,
          signal: controller.signal,
          onStep: (event) => {
            setCloudSaveUi((prev) => {
              if (event.status === 'running') {
                return {
                  ...prev,
                  isOpen: true,
                  phase: 'running',
                  currentStepId: event.id,
                  errorMessage: undefined,
                };
              }

              if (prev.doneSteps.includes(event.id)) {
                return prev;
              }

              const nextDone = [...prev.doneSteps, event.id];
              return {
                ...prev,
                isOpen: true,
                phase: 'running',
                currentStepId: event.id,
                doneSteps: nextDone,
                progress: stepProgress(nextDone),
              };
            });
          },
          onDone: (event) => {
            const completed = DEPLOY_STEPS.map((step) => step.id);
            setCloudSaveUi({
              isOpen: true,
              phase: 'done',
              currentStepId: 'live',
              doneSteps: completed,
              progress: 100,
              deployUrl: event.deployUrl,
            });
          },
        });
      } catch (error: unknown) {
        const message = error instanceof Error ? error.message : 'Cloud save failed.';
        setCloudSaveUi((prev) => ({
          ...prev,
          isOpen: true,
          phase: 'error',
          errorMessage: message,
        }));
        if (rejectOnError) throw new Error(message);
      } finally {
        if (activeCloudSaveController.current === controller) {
          activeCloudSaveController.current = null;
        }
      }
    },
    [],
  );

  const closeCloudDrawer = useCallback(() => {
    setCloudSaveUi(getInitialCloudSaveUiState());
  }, []);

  const retryCloudSave = useCallback(() => {
    if (!pendingCloudSave.current) return;
    void runCloudSave(pendingCloudSave.current, false);
  }, [runCloudSave]);

  return { cloudSaveUi, runCloudSave, closeCloudDrawer, retryCloudSave };
}

