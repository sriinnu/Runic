/**
 * Type definitions for react-native-push-notification
 * Generated to satisfy TypeScript strict mode
 */

declare module 'react-native-push-notification' {
  export interface PushNotificationPermissions {
    alert?: number;
    badge?: number;
    sound?: number;
  }

  export interface PushNotificationOptions {
    onNotification?: (notification: PushNotification) => void;
    onRegister?: (token: { os: string; token: string }) => void;
    permissions?: {
      alert?: boolean;
      badge?: boolean;
      sound?: boolean;
    };
    requestPermissions?: boolean;
    popInitialNotification?: boolean;
  }

  export interface PushNotification {
    foreground?: boolean;
    userInteraction?: boolean;
    message: string | object;
    data?: Record<string, any>;
    badge?: number;
    alert?: object;
    sound?: string;
    finish?: (fetchResult: string) => void;
  }

  export interface ChannelObject {
    channelId: string;
    channelName: string;
    channelDescription?: string;
    playSound?: boolean;
    soundName?: string;
    importance?: number;
    vibrate?: boolean;
  }

  export interface LocalNotification {
    channelId?: string;
    title?: string;
    message: string;
    playSound?: boolean;
    soundName?: string;
    importance?: string;
    priority?: string;
    vibrate?: boolean;
    vibration?: number;
    autoCancel?: boolean;
    largeIcon?: string;
    smallIcon?: string;
    timeoutAfter?: number | null;
    userInfo?: Record<string, any>;
  }

  export interface PushNotificationStatic {
    configure(options: PushNotificationOptions): void;
    localNotification(notification: LocalNotification): void;
    cancelAllLocalNotifications(): void;
    checkPermissions(callback: (permissions: PushNotificationPermissions) => void): void;
    requestPermissions(): Promise<PushNotificationPermissions>;
    createChannel(
      channel: ChannelObject,
      callback?: (created: boolean) => void
    ): void;
  }

  const PushNotification: PushNotificationStatic;
  export default PushNotification;
}
