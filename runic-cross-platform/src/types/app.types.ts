/**
 * @file app.types.ts
 * @description Application-wide type definitions for settings, themes, and UI state.
 * Contains types for app configuration, theme management, and navigation.
 */

/**
 * Application theme modes
 */
export type ThemeMode = 'light' | 'dark' | 'auto';

/**
 * Alert/notification severity levels
 */
export type AlertSeverity = 'info' | 'success' | 'warning' | 'error';

/**
 * Sync status for data synchronization
 */
export type SyncStatus = 'idle' | 'syncing' | 'success' | 'error';

/**
 * Alert/banner message configuration
 */
export interface Alert {
  /** Unique alert ID */
  id: string;
  /** Alert message */
  message: string;
  /** Severity level */
  severity: AlertSeverity;
  /** Timestamp when alert was created */
  timestamp: number;
  /** Auto-dismiss duration in ms (0 = no auto-dismiss) */
  duration?: number;
  /** Action button text */
  actionText?: string;
  /** Action callback */
  onAction?: () => void;
}

/**
 * Application settings and preferences
 */
export interface AppSettings {
  /** Theme configuration */
  theme: {
    /** Current theme mode */
    mode: ThemeMode;
    /** Use Material You on Android */
    useMaterialYou: boolean;
    /** Custom accent color (hex) */
    accentColor?: string;
  };

  /** Notification settings */
  notifications: {
    /** Enable all notifications */
    enabled: boolean;
    /** Show quota warnings */
    quotaWarnings: boolean;
    /** Show sync errors */
    syncErrors: boolean;
    /** Show daily summaries */
    dailySummaries: boolean;
    /** Quiet hours start (24h format) */
    quietHoursStart?: number;
    /** Quiet hours end (24h format) */
    quietHoursEnd?: number;
  };

  /** Data and sync settings */
  sync: {
    /** Auto-sync enabled */
    autoSync: boolean;
    /** Sync interval in minutes */
    syncInterval: number;
    /** Sync on app launch */
    syncOnLaunch: boolean;
    /** Offline mode enabled */
    offlineMode: boolean;
    /** Cache duration in hours */
    cacheDuration: number;
  };

  /** Display settings */
  display: {
    /** Show system tray icon (Windows) */
    showTrayIcon: boolean;
    /** Minimize to tray instead of closing */
    minimizeToTray: boolean;
    /** Currency display format */
    currencyFormat: 'symbol' | 'code';
    /** Number format locale */
    locale: string;
    /** Show cents in cost display */
    showCents: boolean;
  };

  /** Privacy settings */
  privacy: {
    /** Enable analytics */
    analytics: boolean;
    /** Enable crash reporting */
    crashReporting: boolean;
    /** Encrypt stored credentials */
    encryptCredentials: boolean;
  };
}

/**
 * Navigation route parameters
 */
export type RootStackParamList = {
  Home: undefined;
  ProviderDetail: { providerId: string };
  Settings: undefined;
  AddProvider: undefined;
  EditProvider: { providerId: string };
  UsageHistory: { providerId?: string };
  About: undefined;
};

/**
 * Bottom tab navigation parameters
 */
export type BottomTabParamList = {
  Dashboard: undefined;
  Providers: undefined;
  History: undefined;
  Settings: undefined;
};

/**
 * Platform-specific capabilities
 */
export interface PlatformCapabilities {
  /** System tray support */
  systemTray: boolean;
  /** Material You theming */
  materialYou: boolean;
  /** Background sync */
  backgroundSync: boolean;
  /** Push notifications */
  pushNotifications: boolean;
  /** Biometric authentication */
  biometrics: boolean;
}

/**
 * App state for persistence
 */
export interface AppState {
  /** Last active timestamp */
  lastActive: number;
  /** App version */
  version: string;
  /** First launch flag */
  isFirstLaunch: boolean;
  /** Onboarding completed */
  onboardingCompleted: boolean;
  /** Active alerts */
  alerts: Alert[];
  /** Current sync status */
  syncStatus: SyncStatus;
  /** Last sync timestamp */
  lastSyncTime: number;
  /** Last sync error */
  lastSyncError?: string;
}
