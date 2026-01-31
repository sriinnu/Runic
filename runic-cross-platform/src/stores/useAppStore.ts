/**
 * @file useAppStore.ts
 * @description Zustand store for managing application-wide state.
 * Handles settings, theme, alerts, and sync status.
 */

import { create } from 'zustand';
import { storeData, getData, STORAGE_KEYS } from '../utils/storage';
import type {
  AppSettings,
  AppState,
  Alert,
  ThemeMode,
  SyncStatus,
} from '../types';

/**
 * Default application settings
 */
const DEFAULT_SETTINGS: AppSettings = {
  theme: {
    mode: 'auto',
    useMaterialYou: true,
  },
  notifications: {
    enabled: true,
    quotaWarnings: true,
    syncErrors: true,
    dailySummaries: true,
  },
  sync: {
    autoSync: true,
    syncInterval: 15,
    syncOnLaunch: true,
    offlineMode: false,
    cacheDuration: 60,
  },
  display: {
    showTrayIcon: true,
    minimizeToTray: true,
    currencyFormat: 'symbol',
    locale: 'en-US',
    showCents: true,
  },
  privacy: {
    analytics: false,
    crashReporting: true,
    encryptCredentials: true,
  },
};

/**
 * Default app state
 */
const DEFAULT_APP_STATE: AppState = {
  lastActive: Date.now(),
  version: '1.0.0',
  isFirstLaunch: true,
  onboardingCompleted: false,
  alerts: [],
  syncStatus: 'idle',
  lastSyncTime: 0,
};

/**
 * App store state
 */
interface AppStoreState {
  /** Application settings */
  settings: AppSettings;
  /** Application state */
  appState: AppState;
  /** Active alerts */
  alerts: Alert[];
  /** Current sync status */
  syncStatus: SyncStatus;
  /** Loading state */
  isLoading: boolean;
}

/**
 * App store actions
 */
interface AppStoreActions {
  /** Initializes store and loads persisted data */
  initialize: () => Promise<void>;
  /** Updates settings */
  updateSettings: (settings: Partial<AppSettings>) => Promise<void>;
  /** Updates theme mode */
  setThemeMode: (mode: ThemeMode) => Promise<void>;
  /** Adds an alert */
  addAlert: (alert: Omit<Alert, 'id' | 'timestamp'>) => void;
  /** Removes an alert */
  removeAlert: (id: string) => void;
  /** Clears all alerts */
  clearAlerts: () => void;
  /** Updates sync status */
  setSyncStatus: (status: SyncStatus, error?: string) => void;
  /** Updates last sync time */
  setLastSyncTime: (timestamp: number) => void;
  /** Marks onboarding as completed */
  completeOnboarding: () => Promise<void>;
  /** Resets all settings to defaults */
  resetSettings: () => Promise<void>;
}

/**
 * App store with Zustand.
 * Manages all application-wide state and settings.
 */
export const useAppStore = create<AppStoreState & AppStoreActions>(
  (set, get) => ({
    // Initial state
    settings: DEFAULT_SETTINGS,
    appState: DEFAULT_APP_STATE,
    alerts: [],
    syncStatus: 'idle',
    isLoading: false,

    /**
     * Initializes the store by loading persisted data.
     */
    initialize: async () => {
      set({ isLoading: true });

      try {
        // Load settings
        const storedSettings = await getData<AppSettings>(
          STORAGE_KEYS.SETTINGS
        );
        if (storedSettings) {
          set({ settings: { ...DEFAULT_SETTINGS, ...storedSettings } });
        }

        // Load app state
        const storedState = await getData<AppState>(STORAGE_KEYS.APP_STATE);
        if (storedState) {
          set({
            appState: { ...DEFAULT_APP_STATE, ...storedState },
            alerts: storedState.alerts || [],
            syncStatus: storedState.syncStatus || 'idle',
          });
        }

        set({ isLoading: false });
      } catch (error) {
        console.error('Failed to initialize app store:', error);
        set({ isLoading: false });
      }
    },

    /**
     * Updates application settings.
     */
    updateSettings: async (updates: Partial<AppSettings>) => {
      try {
        const { settings } = get();
        const newSettings = {
          ...settings,
          ...updates,
          // Deep merge nested objects
          theme: { ...settings.theme, ...updates.theme },
          notifications: { ...settings.notifications, ...updates.notifications },
          sync: { ...settings.sync, ...updates.sync },
          display: { ...settings.display, ...updates.display },
          privacy: { ...settings.privacy, ...updates.privacy },
        };

        // Persist to storage
        await storeData(STORAGE_KEYS.SETTINGS, newSettings);

        set({ settings: newSettings });
      } catch (error) {
        console.error('Failed to update settings:', error);
      }
    },

    /**
     * Updates theme mode.
     */
    setThemeMode: async (mode: ThemeMode) => {
      await get().updateSettings({
        theme: { ...get().settings.theme, mode },
      });
    },

    /**
     * Adds a new alert to the queue.
     */
    addAlert: (alert: Omit<Alert, 'id' | 'timestamp'>) => {
      const newAlert: Alert = {
        ...alert,
        id: `alert_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
        timestamp: Date.now(),
      };

      const { alerts } = get();
      set({ alerts: [...alerts, newAlert] });

      // Auto-dismiss if duration is set
      if (alert.duration && alert.duration > 0) {
        setTimeout(() => {
          get().removeAlert(newAlert.id);
        }, alert.duration);
      }
    },

    /**
     * Removes an alert by ID.
     */
    removeAlert: (id: string) => {
      const { alerts } = get();
      set({ alerts: alerts.filter((a) => a.id !== id) });
    },

    /**
     * Clears all alerts.
     */
    clearAlerts: () => {
      set({ alerts: [] });
    },

    /**
     * Updates sync status.
     */
    setSyncStatus: (status: SyncStatus, error?: string) => {
      const { appState } = get();
      const newState: AppState = {
        ...appState,
        syncStatus: status,
      };

      if (error !== undefined) {
        newState.lastSyncError = error;
      }

      set({
        syncStatus: status,
        appState: newState,
      });
    },

    /**
     * Updates last sync time.
     */
    setLastSyncTime: (timestamp: number) => {
      const { appState } = get();
      set({
        appState: { ...appState, lastSyncTime: timestamp },
      });
    },

    /**
     * Marks onboarding as completed.
     */
    completeOnboarding: async () => {
      try {
        const { appState } = get();
        const newState = {
          ...appState,
          onboardingCompleted: true,
          isFirstLaunch: false,
        };

        await storeData(STORAGE_KEYS.APP_STATE, newState);
        set({ appState: newState });
      } catch (error) {
        console.error('Failed to complete onboarding:', error);
      }
    },

    /**
     * Resets all settings to defaults.
     */
    resetSettings: async () => {
      try {
        await storeData(STORAGE_KEYS.SETTINGS, DEFAULT_SETTINGS);
        set({ settings: DEFAULT_SETTINGS });
      } catch (error) {
        console.error('Failed to reset settings:', error);
      }
    },
  })
);

export default useAppStore;
