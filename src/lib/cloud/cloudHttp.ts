export function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export function isRetryableStatus(status: number): boolean {
  return status === 429 || status === 500 || status === 502 || status === 503 || status === 504;
}

export function backoffDelayMs(attempt: number): number {
  return 250 * Math.pow(2, attempt) + Math.floor(Math.random() * 120);
}

