/**
 * @file useProviderStore.ts
 * @description Zustand store for managing provider data and state.
 * Handles provider configuration, usage data, and sync operations.
 */

import { create } from 'zustand';
import { syncService, SyncResult } from '../services/SyncService';
import { storeData, getData, STORAGE_KEYS } from '../utils/storage';
import {
  createConcurrencyLimit,
  debounce,
  RequestOptimizationConfig,
} from '../utils/requestOptimizer';
import type { Provider, ProviderId, ProviderConfig } from '../types';

/**
 * Provider store state
 */
interface ProviderState {
  /** Map of providers by ID */
  providers: Partial<Record<ProviderId, Provider>>;
  /** Loading state */
  isLoading: boolean;
  /** Error message */
  error: string | null;
  /** Last sync timestamp */
  lastSyncTime: number;
  /** Currently syncing provider IDs */
  syncingProviders: Set<ProviderId>;
}

/**
 * Provider store actions
 */
interface ProviderActions {
  /** Initializes store and loads persisted data */
  initialize: () => Promise<void>;
  /** Adds or updates a provider */
  setProvider: (provider: Provider) => Promise<void>;
  /** Removes a provider */
  removeProvider: (id: ProviderId) => Promise<void>;
  /** Updates provider configuration */
  updateProviderConfig: (id: ProviderId, config: Partial<ProviderConfig>) => Promise<void>;
  /** Syncs a single provider */
  syncProvider: (id: ProviderId, force?: boolean) => Promise<SyncResult>;
  /** Syncs all enabled providers */
  syncAllProviders: (force?: boolean) => Promise<SyncResult[]>;
  /** Gets a provider by ID */
  getProvider: (id: ProviderId) => Provider | undefined;
  /** Gets all enabled providers */
  getEnabledProviders: () => Provider[];
  /** Clears error state */
  clearError: () => void;
}

/**
 * Default provider template for initialization
 * @deprecated Not currently used - reserved for future provider initialization
 */
// const createDefaultProvider = (id: ProviderId): Partial<Provider> => ({
//   id,
//   enabled: false,
//   status: 'inactive',
//   lastSyncTime: 0,
//   usage: {
//     totalTokens: 0,
//     totalCost: 0,
//     requestCount: 0,
//     averageTokensPerRequest: 0,
//     dataPoints: [],
//   },
//   billing: {
//     cycle: 'monthly',
//     quotaLimit: 0,
//     quotaUsed: 0,
//     quotaRemaining: 0,
//     currency: 'USD',
//     cycleStartDate: Date.now(),
//     cycleEndDate: Date.now() + 30 * 24 * 60 * 60 * 1000,
//     estimatedCost: 0,
//   },
// });

// Performance: Create concurrency limiter for API requests (max 3 concurrent)
const concurrencyLimit = createConcurrencyLimit(
  RequestOptimizationConfig.MAX_CONCURRENT_REQUESTS
);

/**
 * Provider store with Zustand.
 * Manages all provider-related state and operations.
 * Performance optimized with request debouncing and concurrency control.
 */
export const useProviderStore = create<ProviderState & ProviderActions>(
  (set, get) => ({
    // Initial state
    providers: {},
    isLoading: false,
    error: null,
    lastSyncTime: 0,
    syncingProviders: new Set(),

    /**
     * Initializes the store by loading persisted data.
     */
    initialize: async () => {
      set({ isLoading: true, error: null });

      try {
        // Load providers from storage
        const storedProviders = await getData<Record<ProviderId, Provider>>(
          STORAGE_KEYS.PROVIDERS
        );

        if (storedProviders) {
          set({ providers: storedProviders, isLoading: false });
        } else {
          // Initialize with empty state
          set({ providers: {}, isLoading: false });
        }
      } catch (error) {
        console.error('Failed to initialize provider store:', error);
        set({
          error: 'Failed to load providers',
          isLoading: false,
        });
      }
    },

    /**
     * Adds or updates a provider in the store.
     */
    setProvider: async (provider: Provider) => {
      try {
        const { providers } = get();
        const updated = { ...providers, [provider.id]: provider };

        // Persist to storage
        await storeData(STORAGE_KEYS.PROVIDERS, updated);

        set({ providers: updated });
      } catch (error) {
        console.error('Failed to set provider:', error);
        set({ error: 'Failed to save provider' });
      }
    },

    /**
     * Removes a provider from the store.
     */
    removeProvider: async (id: ProviderId) => {
      try {
        const { providers } = get();
        const { [id]: removed, ...remaining } = providers;

        // Persist to storage
        await storeData(STORAGE_KEYS.PROVIDERS, remaining);

        set({ providers: remaining });
      } catch (error) {
        console.error('Failed to remove provider:', error);
        set({ error: 'Failed to remove provider' });
      }
    },

    /**
     * Updates provider configuration.
     */
    updateProviderConfig: async (
      id: ProviderId,
      config: Partial<ProviderConfig>
    ) => {
      const { providers, setProvider } = get();
      const provider = providers[id];

      if (!provider) {
        set({ error: `Provider ${id} not found` });
        return;
      }

      const updated: Provider = {
        ...provider,
        enabled: config.enabled ?? provider.enabled,
      };

      // Only set apiToken if it's explicitly provided
      if (config.apiToken !== undefined) {
        updated.apiToken = config.apiToken;
      }

      await setProvider(updated);
    },

    /**
     * Syncs a single provider's data.
     */
    syncProvider: async (id: ProviderId, force = false) => {
      const { providers, syncingProviders } = get();
      const provider = providers[id];

      if (!provider) {
        return {
          providerId: id,
          success: false,
          error: 'Provider not found',
          timestamp: Date.now(),
        };
      }

      // Mark as syncing
      set({ syncingProviders: new Set([...syncingProviders, id]) });

      try {
        const result = await syncService.syncProvider(provider, { force });

        // Update provider with new data
        if (result.success && result.usage && result.billing) {
          const updated: Provider = {
            ...provider,
            usage: result.usage,
            billing: result.billing,
            lastSyncTime: result.timestamp,
            status: 'active',
          };

          // Remove lastError if sync was successful
          delete updated.lastError;

          await get().setProvider(updated);
        } else if (result.error) {
          // Update with error
          const updated: Provider = {
            ...provider,
            status: 'error',
            lastError: result.error,
          };

          await get().setProvider(updated);
        }

        return result;
      } finally {
        // Remove from syncing set
        const newSyncing = new Set(get().syncingProviders);
        newSyncing.delete(id);
        set({ syncingProviders: newSyncing, lastSyncTime: Date.now() });
      }
    },

    /**
     * Syncs all enabled providers.
     * Performance optimized with concurrency limiting (max 3 concurrent requests).
     */
    syncAllProviders: async (force = false) => {
      const providers = get().getEnabledProviders();

      if (providers.length === 0) {
        return [];
      }

      // Performance: Use concurrency limiter to prevent API spam
      const syncPromises = providers.map((provider) =>
        concurrencyLimit(() => get().syncProvider(provider.id, force))
      );

      set({ isLoading: true });

      try {
        // Performance: Execute with concurrency limit (max 3 concurrent)
        const results = await Promise.all(syncPromises);
        return results;
      } finally {
        set({ isLoading: false, lastSyncTime: Date.now() });
      }
    },

    /**
     * Gets a provider by ID.
     */
    getProvider: (id: ProviderId) => {
      return get().providers[id];
    },

    /**
     * Gets all enabled providers.
     */
    getEnabledProviders: () => {
      const { providers } = get();
      return Object.values(providers).filter((p) => p.enabled);
    },

    /**
     * Clears error state.
     */
    clearError: () => {
      set({ error: null });
    },
  })
);

export default useProviderStore;
