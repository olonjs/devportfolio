import { withBasePath } from '@olonjs/core';
import { backoffDelayMs, isRetryableStatus, sleep } from '@/lib/cloud/cloudHttp';

const MAX_UPLOAD_SIZE_BYTES = 5 * 1024 * 1024;
const ASSET_UPLOAD_MAX_RETRIES = 2;
const ASSET_UPLOAD_TIMEOUT_MS = 20_000;
const ALLOWED_IMAGE_MIME_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/avif']);

function resolveImageMimeType(file: File): string {
  if (file.type.startsWith('image/')) return file.type;
  const ext = file.name.split('.').pop()?.toLowerCase();
  const byExt: Record<string, string> = {
    jpg: 'image/jpeg',
    jpeg: 'image/jpeg',
    png: 'image/png',
    webp: 'image/webp',
    gif: 'image/gif',
    avif: 'image/avif',
  };
  return ext ? (byExt[ext] ?? '') : '';
}

export function normalizeUploadedAssetUrl(rawUrl: string, basePath: string): string {
  const trimmed = rawUrl.trim();
  if (!trimmed) return trimmed;
  if (/^(?:https?:)?\/\//i.test(trimmed) || /^data:/i.test(trimmed)) return trimmed;
  const normalizedPath = trimmed.startsWith('/') ? trimmed : `/${trimmed}`;
  return withBasePath(normalizedPath, basePath);
}

async function normalizeImageForRendering(file: File): Promise<File> {
  if (typeof window === 'undefined') return file;
  const mimeType = resolveImageMimeType(file);
  if (!mimeType.startsWith('image/')) return file;

  const objectUrl = URL.createObjectURL(file);
  try {
    const imageEl = await new Promise<HTMLImageElement>((resolve, reject) => {
      const img = new Image();
      img.decoding = 'async';
      img.onload = () => resolve(img);
      img.onerror = () => reject(new Error('Image decode failed before upload.'));
      img.src = objectUrl;
    });

    const width = imageEl.naturalWidth;
    const height = imageEl.naturalHeight;
    if (!width || !height) throw new Error('Image decode failed before upload.');

    const canvas = document.createElement('canvas');
    canvas.width = width;
    canvas.height = height;
    const ctx = canvas.getContext('2d');
    if (!ctx) throw new Error('Canvas context unavailable.');
    ctx.drawImage(imageEl, 0, 0);

    const blob =
      await new Promise<Blob | null>((resolve) => canvas.toBlob((value) => resolve(value), 'image/webp', 0.92))
      ?? await new Promise<Blob | null>((resolve) => canvas.toBlob((value) => resolve(value), 'image/jpeg', 0.92));

    if (!blob) throw new Error('Image re-encode failed.');
    const baseName = file.name.replace(/\.[^.]+$/, '') || `image-${Date.now()}`;
    const ext = blob.type === 'image/webp' ? 'webp' : 'jpg';
    return new File([blob], `${baseName}.${ext}`, {
      type: blob.type,
      lastModified: Date.now(),
    });
  } finally {
    URL.revokeObjectURL(objectUrl);
  }
}

export async function uploadTenantAsset(
  file: File,
  options: {
    basePath: string;
    isCloudMode: boolean;
    cloudApiUrl?: string;
    cloudApiKey?: string;
    apiBases: string[];
    onUploaded?: () => Promise<void>;
  }
): Promise<string> {
  const preparedFile = await normalizeImageForRendering(file);
  const mimeType = resolveImageMimeType(preparedFile);
  if (!mimeType) throw new Error('Invalid file type.');
  if (!ALLOWED_IMAGE_MIME_TYPES.has(mimeType)) {
    throw new Error('Unsupported image format. Allowed: jpeg, png, webp, gif, avif.');
  }
  if (preparedFile.size > MAX_UPLOAD_SIZE_BYTES) {
    throw new Error(`File too large. Max ${MAX_UPLOAD_SIZE_BYTES / 1024 / 1024}MB.`);
  }

  if (options.isCloudMode && options.cloudApiUrl && options.cloudApiKey) {
    let lastError: Error | null = null;
    for (const apiBase of options.apiBases) {
      for (let attempt = 0; attempt <= ASSET_UPLOAD_MAX_RETRIES; attempt += 1) {
        try {
          const formData = new FormData();
          formData.append('file', preparedFile);
          formData.append('filename', preparedFile.name);
          const controller = new AbortController();
          const timeout = window.setTimeout(() => controller.abort(), ASSET_UPLOAD_TIMEOUT_MS);
          const res = await fetch(`${apiBase}/assets/upload`, {
            method: 'POST',
            headers: {
              Authorization: `Bearer ${options.cloudApiKey}`,
              'X-Correlation-Id': crypto.randomUUID(),
            },
            body: formData,
            signal: controller.signal,
          }).finally(() => window.clearTimeout(timeout));
          const body = (await res.json().catch(() => ({}))) as { url?: string; error?: string; code?: string };
          if (res.ok && typeof body.url === 'string') {
            await options.onUploaded?.().catch(() => undefined);
            return normalizeUploadedAssetUrl(body.url, options.basePath);
          }
          lastError = new Error(body.error || body.code || `Cloud upload failed: ${res.status}`);
          if (isRetryableStatus(res.status) && attempt < ASSET_UPLOAD_MAX_RETRIES) {
            await sleep(backoffDelayMs(attempt));
            continue;
          }
          break;
        } catch (error: unknown) {
          const message = error instanceof Error ? error.message : 'Cloud upload failed.';
          lastError = new Error(message);
          if (attempt < ASSET_UPLOAD_MAX_RETRIES) {
            await sleep(backoffDelayMs(attempt));
            continue;
          }
          break;
        }
      }
    }
    throw lastError ?? new Error('Cloud upload failed.');
  }

  const base64 = await new Promise<string>((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve((reader.result as string).split(',')[1] ?? '');
    reader.onerror = () => reject(reader.error);
    reader.readAsDataURL(preparedFile);
  });

  const res = await fetch('/api/upload-asset', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ filename: preparedFile.name, mimeType, data: base64 }),
  });
  const body = (await res.json().catch(() => ({}))) as { url?: string; error?: string };
  if (!res.ok) throw new Error(body.error || `Upload failed: ${res.status}`);
  if (typeof body.url !== 'string' || !body.url.trim()) {
    throw new Error('Invalid server response: missing url');
  }
  await options.onUploaded?.().catch(() => undefined);
  return normalizeUploadedAssetUrl(body.url, options.basePath);
}

