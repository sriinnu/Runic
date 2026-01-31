/**
 * @file SyncService.ts
 * @description Service for synchronizing provider data from remote APIs.
 * Handles periodic sync, offline caching, and error recovery.
 */

import { createProviderClient, ApiError } from './ApiClient';
import { cacheData, getCachedData } from '../utils/storage';
import type { Provider, UsageStats, ProviderBilling } from '../types';

/**
 * Sync result for a single provider
 */
export interface SyncResult {
  providerId: string;
  success: boolean;
  error?: string;
  usage?: UsageStats;
  billing?: ProviderBilling;
  timestamp: number;
}

/**
 * Sync options configuration
 */
export interface SyncOptions {
  /** Force sync even if cache is valid */
  force?: boolean;
  /** Use cached data if available */
  useCache?: boolean;
  /** Cache duration in minutes */
  cacheDuration?: number;
}

/**
 * Service for synchronizing provider usage data.
 * Handles API requests, caching, and offline support.
 */
class SyncService {
  private isSyncing = false;
  private syncQueue: Set<string> = new Set();

  /**
   * Synchronizes data for a single provider.
   *
   * @param provider - Provider configuration
   * @param options - Sync options
   * @returns Promise with sync result
   *
   * @example
   * const result = await syncService.syncProvider(provider, { force: true });
   */
  async syncProvider(
    provider: Provider,
    options: SyncOptions = {}
  ): Promise<SyncResult> {
    const { force = false, useCache = true, cacheDuration = 15 } = options;

    // Check if already syncing this provider
    if (this.syncQueue.has(provider.id)) {
      return {
        providerId: provider.id,
        success: false,
        error: 'Sync already in progress',
        timestamp: Date.now(),
      };
    }

    // Try to use cached data first if allowed
    if (!force && useCache) {
      const cachedResult = await this.getCachedResult(provider.id);
      if (cachedResult) {
        return cachedResult;
      }
    }

    // Mark as syncing
    this.syncQueue.add(provider.id);

    try {
      const result = await this.fetchProviderData(provider);

      // Cache the result
      await cacheData(`sync_result_${provider.id}`, result, cacheDuration);

      return result;
    } catch (error) {
      return this.handleSyncError(provider.id, error);
    } finally {
      // Remove from sync queue
      this.syncQueue.delete(provider.id);
    }
  }

  /**
   * Synchronizes data for multiple providers in parallel.
   *
   * @param providers - Array of provider configurations
   * @param options - Sync options
   * @returns Promise with array of sync results
   *
   * @example
   * const results = await syncService.syncProviders(providers);
   */
  async syncProviders(
    providers: Provider[],
    options: SyncOptions = {}
  ): Promise<SyncResult[]> {
    this.isSyncing = true;

    try {
      // Sync all providers in parallel
      const syncPromises = providers
        .filter((p) => p.enabled && p.apiToken)
        .map((provider) => this.syncProvider(provider, options));

      return await Promise.all(syncPromises);
    } finally {
      this.isSyncing = false;
    }
  }

  /**
   * Fetches fresh data from provider API.
   *
   * @param provider - Provider configuration
   * @returns Promise with sync result
   */
  private async fetchProviderData(provider: Provider): Promise<SyncResult> {
    const client = createProviderClient(provider);

    try {
      // Fetch usage and billing data based on provider type
      const [usage, billing] = await Promise.all([
        this.fetchUsageData(provider, client),
        this.fetchBillingData(provider, client),
      ]);

      return {
        providerId: provider.id,
        success: true,
        usage,
        billing,
        timestamp: Date.now(),
      };
    } catch (error) {
      throw error;
    }
  }

  /**
   * Fetches usage data for a specific provider.
   * Different providers have different API endpoints and response formats.
   *
   * @param provider - Provider configuration
   * @param client - Configured API client
   * @returns Promise with usage statistics
   */
  private async fetchUsageData(
    provider: Provider,
    client: any
  ): Promise<UsageStats> {
    // Provider-specific endpoint mapping
    const endpoints: Record<string, string> = {
      openai: '/usage',
      anthropic: '/v1/usage',
      google: '/v1/usage',
      minimax: '/usage/query',
      groq: '/openai/v1/usage',
    };

    const endpoint = endpoints[provider.id] || '/usage';

    try {
      const response = await client.get(endpoint);
      return this.parseUsageResponse(provider.id, response);
    } catch (error) {
      console.error(`Failed to fetch usage for ${provider.id}:`, error);
      throw error;
    }
  }

  /**
   * Fetches billing data for a specific provider.
   *
   * @param provider - Provider configuration
   * @param _client - Configured API client (unused - reserved for future use)
   * @returns Promise with billing information
   */
  private async fetchBillingData(
    provider: Provider,
    _client: any
  ): Promise<ProviderBilling> {
    // Most providers include billing in usage response
    // This is a placeholder for provider-specific logic
    return provider.billing;
  }

  /**
   * Parses usage response based on provider format.
   *
   * @param _providerId - Provider identifier (unused - reserved for provider-specific parsing)
   * @param response - Raw API response
   * @returns Normalized usage statistics
   */
  private parseUsageResponse(_providerId: string, response: any): UsageStats {
    // Each provider has different response format
    // This is a simplified parser - production code would have
    // provider-specific parsers
    return {
      totalTokens: response.total_tokens || response.tokens || 0,
      totalCost: response.total_cost || response.cost || 0,
      requestCount: response.request_count || response.requests || 0,
      averageTokensPerRequest: 0,
      dataPoints: response.data_points || [],
    };
  }

  /**
   * Retrieves cached sync result if valid.
   *
   * @param providerId - Provider identifier
   * @returns Cached sync result or null
   */
  private async getCachedResult(
    providerId: string
  ): Promise<SyncResult | null> {
    return await getCachedData<SyncResult>(`sync_result_${providerId}`);
  }

  /**
   * Handles sync errors and creates error result.
   *
   * @param providerId - Provider identifier
   * @param error - Error object
   * @returns Sync result with error information
   */
  private handleSyncError(providerId: string, error: unknown): SyncResult {
    let errorMessage = 'Unknown error occurred';

    if (error instanceof ApiError) {
      errorMessage = error.message;
    } else if (error instanceof Error) {
      errorMessage = error.message;
    }

    console.error(`Sync failed for ${providerId}:`, errorMessage);

    return {
      providerId,
      success: false,
      error: errorMessage,
      timestamp: Date.now(),
    };
  }

  /**
   * Checks if a sync operation is currently in progress.
   *
   * @returns True if syncing, false otherwise
   */
  isSyncInProgress(): boolean {
    return this.isSyncing;
  }

  /**
   * Cancels all pending sync operations.
   */
  cancelAllSyncs(): void {
    this.syncQueue.clear();
    this.isSyncing = false;
  }
}

// Export singleton instance
export const syncService = new SyncService();
export default syncService;
