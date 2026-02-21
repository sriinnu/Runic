/**
 * @file retry.ts
 * @description Retry utilities with exponential backoff for failed operations.
 */

import { ApiError } from '../services/ApiClient';
import type { ErrorMessage } from './ErrorMessages';

/**
 * Retry strategy configuration
 */
export interface RetryOptions {
  /** Maximum number of retry attempts (default: 3) */
  maxAttempts?: number;
  /** Base delay in milliseconds (default: 1000) */
  baseDelay?: number;
  /** Maximum delay in milliseconds (default: 8000) */
  maxDelay?: number;
  /** Whether to add jitter to prevent thundering herd (default: true) */
  useJitter?: boolean;
  /** Optional callback invoked before each retry */
  onRetry?: (attempt: number, delay: number) => void;
  /** Optional predicate to determine if error should be retried */
  shouldRetry?: (error: Error) => boolean;
}

/**
 * Default retry options
 */
const DEFAULT_OPTIONS: Required<Omit<RetryOptions, 'onRetry' | 'shouldRetry'>> = {
  maxAttempts: 3,
  baseDelay: 1000,
  maxDelay: 8000,
  useJitter: true,
};

/**
 * Calculates delay for a given attempt using exponential backoff
 */
function calculateDelay(
  attempt: number,
  baseDelay: number,
  maxDelay: number,
  useJitter: boolean
): number {
  // Exponential backoff: baseDelay * 2^attempt
  const exponentialDelay = baseDelay * Math.pow(2, attempt);

  // Cap at maxDelay
  let delay = Math.min(exponentialDelay, maxDelay);

  // Add jitter (random 0-50% of delay)
  if (useJitter) {
    const jitter = Math.random() * (delay * 0.5);
    delay += jitter;
  }

  return delay;
}

/**
 * Sleeps for specified milliseconds
 */
function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Determines if an error is retryable
 */
function isRetryable(error: Error): boolean {
  // Check if it's an ApiError with a structured error message
  if (error instanceof ApiError) {
    return error.isRetryable;
  }

  // Check for network-related errors
  if (error.message.includes('network') || error.message.includes('timeout')) {
    return true;
  }

  // Default to non-retryable
  return false;
}

/**
 * Executes an async operation with retry logic
 *
 * @param operation - Async function to execute
 * @param options - Retry configuration
 * @returns Promise with operation result
 * @throws Last error if all retries exhausted
 *
 * @example
 * const data = await retryWithBackoff(
 *   () => fetchProviderData(provider),
 *   {
 *     maxAttempts: 3,
 *     onRetry: (attempt, delay) => {
 *       console.log(`Retry attempt ${attempt} after ${delay}ms`);
 *     }
 *   }
 * );
 */
export async function retryWithBackoff<T>(
  operation: () => Promise<T>,
  options: RetryOptions = {}
): Promise<T> {
  const {
    maxAttempts = DEFAULT_OPTIONS.maxAttempts,
    baseDelay = DEFAULT_OPTIONS.baseDelay,
    maxDelay = DEFAULT_OPTIONS.maxDelay,
    useJitter = DEFAULT_OPTIONS.useJitter,
    onRetry,
    shouldRetry = isRetryable,
  } = options;

  let lastError: Error | undefined;

  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      return await operation();
    } catch (error) {
      lastError = error as Error;

      // Check if we should retry this error
      const retryable = shouldRetry(lastError);

      // Don't retry if not retryable or if this was the last attempt
      if (!retryable || attempt >= maxAttempts - 1) {
        throw lastError;
      }

      // Calculate delay and wait
      const delay = calculateDelay(attempt, baseDelay, maxDelay, useJitter);

      // Notify about retry
      onRetry?.(attempt + 1, delay);

      // Wait before retrying
      await sleep(delay);
    }
  }

  // Should never reach here, but just in case
  throw lastError || new Error('Retry failed: maximum attempts exceeded');
}

/**
 * Preset retry strategies
 */
export const RetryStrategy = {
  /** Default strategy: 3 attempts, 1s base, 8s max */
  default: (): RetryOptions => ({
    maxAttempts: 3,
    baseDelay: 1000,
    maxDelay: 8000,
  }),

  /** Aggressive strategy: 5 attempts, 2s base, 16s max */
  aggressive: (): RetryOptions => ({
    maxAttempts: 5,
    baseDelay: 2000,
    maxDelay: 16000,
  }),

  /** Fast strategy: 3 attempts, 0.5s base, 4s max */
  fast: (): RetryOptions => ({
    maxAttempts: 3,
    baseDelay: 500,
    maxDelay: 4000,
  }),

  /** Minimal strategy: 2 attempts, 0.5s base, 1s max */
  minimal: (): RetryOptions => ({
    maxAttempts: 2,
    baseDelay: 500,
    maxDelay: 1000,
  }),
};

/**
 * Hook-friendly retry wrapper
 * Returns a function that wraps an operation with retry logic
 *
 * @example
 * const syncWithRetry = useRetry(RetryStrategy.default());
 * await syncWithRetry(() => syncProvider(provider));
 */
export function createRetryWrapper(options: RetryOptions = {}) {
  return async <T>(operation: () => Promise<T>): Promise<T> => {
    return retryWithBackoff(operation, options);
  };
}
