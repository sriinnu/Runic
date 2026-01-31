/**
 * @file NotificationService.ts
 * @description Cross-platform notification service for toast and push notifications.
 * Handles platform-specific notification APIs for Windows and Android.
 */

import { Platform } from 'react-native';
import PushNotification from 'react-native-push-notification';
import type { AlertSeverity } from '../types';

/**
 * Notification configuration
 */
export interface NotificationConfig {
  /** Notification title */
  title: string;
  /** Notification message */
  message: string;
  /** Severity level (affects icon and color) */
  severity?: AlertSeverity;
  /** Auto-dismiss duration in seconds (0 = no auto-dismiss) */
  duration?: number;
  /** Callback when notification is tapped */
  onPress?: () => void;
  /** Custom data to pass with notification */
  data?: Record<string, unknown>;
}

/**
 * Service for managing notifications across platforms.
 * Provides unified API for both local and push notifications.
 */
class NotificationService {
  private initialized = false;

  /**
   * Initializes the notification service.
   * Must be called before using any notification methods.
   *
   * @example
   * notificationService.initialize();
   */
  initialize(): void {
    if (this.initialized) {
      return;
    }

    // Configure push notifications
    PushNotification.configure({
      // Called when notification is opened
      onNotification: (notification) => {
        console.log('[Notification] Opened:', notification);
        // Handle notification tap
        if (notification.data?.onPress) {
          notification.data.onPress();
        }
      },

      // Android-specific permissions
      permissions: {
        alert: true,
        badge: true,
        sound: true,
      },

      // Request permissions on iOS (not needed for Android/Windows)
      requestPermissions: Platform.OS === 'ios',

      // Channel configuration for Android
      popInitialNotification: true,
    });

    // Create notification channel for Android
    if (Platform.OS === 'android') {
      this.createAndroidChannels();
    }

    this.initialized = true;
  }

  /**
   * Creates notification channels for Android.
   * Required for Android 8.0+ (API 26+).
   */
  private createAndroidChannels(): void {
    PushNotification.createChannel(
      {
        channelId: 'runic-default',
        channelName: 'Runic Notifications',
        channelDescription: 'General notifications from Runic',
        playSound: true,
        soundName: 'default',
        importance: 4, // High importance
        vibrate: true,
      },
      (created) => console.log(`Channel created: ${created}`)
    );

    PushNotification.createChannel(
      {
        channelId: 'runic-alerts',
        channelName: 'Runic Alerts',
        channelDescription: 'Important alerts and warnings',
        playSound: true,
        soundName: 'default',
        importance: 5, // Max importance
        vibrate: true,
      },
      (created) => console.log(`Alert channel created: ${created}`)
    );
  }

  /**
   * Shows a local notification.
   *
   * @param config - Notification configuration
   *
   * @example
   * notificationService.showNotification({
   *   title: 'Quota Warning',
   *   message: 'You have used 90% of your quota',
   *   severity: 'warning',
   * });
   */
  showNotification(config: NotificationConfig): void {
    if (!this.initialized) {
      console.warn('NotificationService not initialized');
      return;
    }

    const {
      title,
      message,
      severity = 'info',
      duration = 4,
      onPress,
      data = {},
    } = config;

    // Select channel based on severity
    const channelId =
      severity === 'error' || severity === 'warning'
        ? 'runic-alerts'
        : 'runic-default';

    PushNotification.localNotification({
      channelId,
      title,
      message,
      playSound: severity === 'error' || severity === 'warning',
      soundName: 'default',
      importance: 'high',
      priority: 'high',
      vibrate: true,
      vibration: 300,
      autoCancel: true,
      largeIcon: 'ic_launcher',
      smallIcon: 'ic_notification',
      timeoutAfter: duration > 0 ? duration * 1000 : null,
      userInfo: {
        ...data,
        onPress,
      },
    });
  }

  /**
   * Shows a quota warning notification.
   *
   * @param providerName - Name of the provider
   * @param percentage - Percentage of quota used
   *
   * @example
   * notificationService.showQuotaWarning('OpenAI', 90);
   */
  showQuotaWarning(providerName: string, percentage: number): void {
    this.showNotification({
      title: 'Quota Warning',
      message: `${providerName} has used ${percentage}% of quota`,
      severity: percentage >= 95 ? 'error' : 'warning',
      duration: 0, // Don't auto-dismiss
    });
  }

  /**
   * Shows a sync error notification.
   *
   * @param providerName - Name of the provider
   * @param errorMessage - Error message
   *
   * @example
   * notificationService.showSyncError('Anthropic', 'Invalid API token');
   */
  showSyncError(providerName: string, errorMessage: string): void {
    this.showNotification({
      title: 'Sync Failed',
      message: `Failed to sync ${providerName}: ${errorMessage}`,
      severity: 'error',
      duration: 6,
    });
  }

  /**
   * Shows a daily summary notification.
   *
   * @param totalCost - Total cost for the day
   * @param totalTokens - Total tokens used
   *
   * @example
   * notificationService.showDailySummary(12.50, 150000);
   */
  showDailySummary(totalCost: number, totalTokens: number): void {
    this.showNotification({
      title: 'Daily Summary',
      message: `Today: $${totalCost.toFixed(2)} | ${totalTokens.toLocaleString()} tokens`,
      severity: 'info',
      duration: 8,
    });
  }

  /**
   * Cancels all pending notifications.
   */
  cancelAllNotifications(): void {
    PushNotification.cancelAllLocalNotifications();
  }

  /**
   * Checks if notifications are enabled.
   *
   * @returns Promise that resolves to true if enabled
   */
  async checkPermissions(): Promise<boolean> {
    return new Promise((resolve) => {
      PushNotification.checkPermissions((permissions) => {
        resolve(permissions.alert === 1);
      });
    });
  }

  /**
   * Requests notification permissions (primarily for iOS).
   *
   * @returns Promise that resolves to true if granted
   */
  async requestPermissions(): Promise<boolean> {
    return new Promise((resolve) => {
      PushNotification.requestPermissions().then((permissions) => {
        resolve(permissions.alert === 1);
      });
    });
  }

  /**
   * Shows a system tray notification (Windows only).
   * NOTE: System tray functionality is not yet implemented.
   * Falls back to regular notifications on all platforms.
   *
   * @param config - Notification configuration
   */
  showTrayNotification(config: NotificationConfig): void {
    // Fallback to regular notification on all platforms
    // System tray functionality requires a Windows-specific implementation
    this.showNotification(config);
    console.log('[Tray] Fallback to regular notification:', config.title);
  }
}

// Export singleton instance
export const notificationService = new NotificationService();
export default notificationService;
