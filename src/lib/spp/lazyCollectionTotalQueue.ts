type QueueTask<T> = {
  id: string;
  signal: AbortSignal;
  execute: () => Promise<T>;
  onDone: (value: T) => void;
  onCancelled: () => void;
};

export class LazyFetchQueue {
  private readonly maxConcurrent: number;
  private active = 0;
  private readonly waiting: QueueTask<unknown>[] = [];
  private readonly removed = new Set<string>();

  constructor(maxConcurrent: number) {
    this.maxConcurrent = Math.max(1, maxConcurrent);
  }

  schedule<T>(task: QueueTask<T>) {
    if (this.removed.has(task.id)) return;
    this.waiting.push(task as QueueTask<unknown>);
    void this.pump();
  }

  remove(id: string) {
    this.removed.add(id);
    for (let index = this.waiting.length - 1; index >= 0; index -= 1) {
      if (this.waiting[index]?.id === id) {
        this.waiting.splice(index, 1);
      }
    }
  }

  clearRemoved(id: string) {
    this.removed.delete(id);
  }

  private async pump() {
    while (this.active < this.maxConcurrent && this.waiting.length > 0) {
      const task = this.waiting.shift();
      if (!task || this.removed.has(task.id) || task.signal.aborted) {
        continue;
      }

      this.active += 1;
      void this.runTask(task);
    }
  }

  private async runTask(task: QueueTask<unknown>) {
    try {
      const value = await task.execute();
      if (!task.signal.aborted && !this.removed.has(task.id)) {
        task.onDone(value);
      } else {
        task.onCancelled();
      }
    } catch {
      if (task.signal.aborted || this.removed.has(task.id)) {
        task.onCancelled();
      } else {
        task.onCancelled();
      }
    } finally {
      this.active = Math.max(0, this.active - 1);
      void this.pump();
    }
  }
}

export const authorPostTotalCache = new Map<string, number>();
export const authorPostTotalQueue = new LazyFetchQueue(6);

