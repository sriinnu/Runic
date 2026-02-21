/**
 * @file requestOptimizer.ts
 * @description Utilities for optimizing API requests with debouncing and concurrency control.
 * Performance optimized to reduce network overhead and prevent API spam.
 */

/**
 * Performance: Debounce utility to delay function execution
 * Prevents rapid-fire API calls by waiting for a quiet period.
 *
 * @param fn Function to debounce
 * @param delay Delay in milliseconds (default: 1000ms)
 * @returns Debounced function
 *
 * @example
 * const debouncedSync = debounce(() => syncProvider(), 1000);
 * debouncedSync(); // Will only execute after 1s of no calls
 */
export function debounce<T extends (...args: any[]) => any>(
  fn: T,
  delay: number = 1000
): (...args: Parameters<T>) => void {
  let timeoutId: NodeJS.Timeout | null = null;

  return function debounced(...args: Parameters<T>) {
    if (timeoutId) {
      clearTimeout(timeoutId);
    }

    timeoutId = setTimeout(() => {
      fn(...args);
      timeoutId = null;
    }, delay);
  };
}

/**
 * Performance: Creates a concurrency-limited promise executor
 * Limits the number of simultaneous API requests to prevent overwhelming the server.
 *
 * @param limit Maximum number of concurrent operations (default: 3)
 * @returns Function that executes promises with concurrency limit
 *
 * @example
 * const limit = createConcurrencyLimit(3);
 * const results = await Promise.all(
 *   providers.map(p => limit(() => syncProvider(p)))
 * );
 */
export function createConcurrencyLimit(limit: number = 3) {
  const queue: Array<() => void> = [];
  let activeCount = 0;

  function next() {
    if (queue.length > 0 && activeCount < limit) {
      const task = queue.shift();
      if (task) {
        activeCount++;
        task();
      }
    }
  }

  return async function limitedExecutor<T>(
    fn: () => Promise<T>
  ): Promise<T> {
    return new Promise<T>((resolve, reject) => {
      const task = async () => {
        try {
          const result = await fn();
          resolve(result);
        } catch (error) {
          reject(error);
        } finally {
          activeCount--;
          next();
        }
      };

      queue.push(task);
      next();
    });
  };
}

/**
 * Performance: Throttle utility to limit function execution rate
 * Ensures function is called at most once per time period.
 *
 * @param fn Function to throttle
 * @param interval Minimum interval between calls in milliseconds
 * @returns Throttled function
 *
 * @example
 * const throttledSync = throttle(() => syncProvider(), 5000);
 * throttledSync(); // Will execute immediately
 * throttledSync(); // Will be ignored if called within 5s
 */
export function throttle<T extends (...args: any[]) => any>(
  fn: T,
  interval: number
): (...args: Parameters<T>) => void {
  let lastCallTime = 0;
  let scheduledCall: NodeJS.Timeout | null = null;

  return function throttled(...args: Parameters<T>) {
    const now = Date.now();
    const timeSinceLastCall = now - lastCallTime;

    if (timeSinceLastCall >= interval) {
      // Execute immediately
      lastCallTime = now;
      fn(...args);
    } else if (!scheduledCall) {
      // Schedule for later
      const timeUntilNext = interval - timeSinceLastCall;
      scheduledCall = setTimeout(() => {
        lastCallTime = Date.now();
        fn(...args);
        scheduledCall = null;
      }, timeUntilNext);
    }
  };
}

/**
 * Performance: Cache wrapper for expensive operations
 * Caches results with TTL to avoid redundant computations.
 *
 * @param fn Function to cache
 * @param ttl Time to live in milliseconds (default: 5 minutes)
 * @returns Cached function
 *
 * @example
 * const cachedFetch = cacheWithTTL(
 *   (id) => fetchProviderData(id),
 *   5 * 60 * 1000
 * );
 */
export function cacheWithTTL<T extends (...args: any[]) => Promise<any>>(
  fn: T,
  ttl: number = 5 * 60 * 1000
): T {
  const cache = new Map<string, { value: any; expiry: number }>();

  return (async (...args: Parameters<T>) => {
    const key = JSON.stringify(args);
    const cached = cache.get(key);

    if (cached && Date.now() < cached.expiry) {
      return cached.value;
    }

    const result = await fn(...args);
    cache.set(key, {
      value: result,
      expiry: Date.now() + ttl,
    });

    return result;
  }) as T;
}

/**
 * Performance: Batch multiple requests into a single operation
 * Collects requests over a time window and executes them together.
 *
 * @param fn Batch execution function
 * @param delay Delay to wait for batching (default: 100ms)
 * @returns Batched function
 *
 * @example
 * const batchedSync = createBatcher(
 *   (ids) => syncMultipleProviders(ids),
 *   100
 * );
 * batchedSync('provider1'); // Waits 100ms
 * batchedSync('provider2'); // Both execute together
 */
export function createBatcher<TInput, TOutput>(
  fn: (items: TInput[]) => Promise<TOutput[]>,
  delay: number = 100
): (item: TInput) => Promise<TOutput> {
  let batch: TInput[] = [];
  let timeoutId: NodeJS.Timeout | null = null;
  const pending: Array<{
    item: TInput;
    resolve: (value: TOutput) => void;
    reject: (error: any) => void;
  }> = [];

  async function executeBatch() {
    if (batch.length === 0) return;

    const currentBatch = [...batch];
    const currentPending = [...pending];

    batch = [];
    pending.length = 0;
    timeoutId = null;

    try {
      const results = await fn(currentBatch);
      currentPending.forEach((p, index) => {
        p.resolve(results[index]);
      });
    } catch (error) {
      currentPending.forEach((p) => {
        p.reject(error);
      });
    }
  }

  return function batched(item: TInput): Promise<TOutput> {
    return new Promise((resolve, reject) => {
      batch.push(item);
      pending.push({ item, resolve, reject });

      if (timeoutId) {
        clearTimeout(timeoutId);
      }

      timeoutId = setTimeout(executeBatch, delay);
    });
  };
}

/**
 * Performance constants for request optimization
 */
export const RequestOptimizationConfig = {
  /** Default debounce delay for sync operations */
  SYNC_DEBOUNCE_DELAY: 1000,

  /** Maximum concurrent API requests */
  MAX_CONCURRENT_REQUESTS: 3,

  /** Throttle interval for rapid updates */
  THROTTLE_INTERVAL: 5000,

  /** Cache TTL for provider data */
  CACHE_TTL: 5 * 60 * 1000, // 5 minutes

  /** Batch delay for grouped operations */
  BATCH_DELAY: 100,
};
