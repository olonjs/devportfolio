import type { CloudLoadFailure } from '@/lib/cloud/types';

export function logBootstrapEvent(event: string, details: Record<string, unknown>) {
  console.info('[boot]', { event, at: new Date().toISOString(), ...details });
}

function isObjectRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

export function isCloudLoadFailure(value: unknown): value is CloudLoadFailure {
  return (
    isObjectRecord(value) &&
    typeof value.reasonCode === 'string' &&
    typeof value.message === 'string'
  );
}

export function toCloudLoadFailure(value: unknown): CloudLoadFailure {
  if (isCloudLoadFailure(value)) return value;
  if (value instanceof Error) {
    return { reasonCode: 'CLOUD_LOAD_FAILED', message: value.message };
  }
  return { reasonCode: 'CLOUD_LOAD_FAILED', message: 'Cloud content unavailable.' };
}

