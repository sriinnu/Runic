/**
 * @file NotificationChannelManager.java
 * @description Manages notification channels for Android 8.0+.
 * Creates and configures channels for different notification types.
 */

package com.runic;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;
import android.os.Build;

/**
 * Utility class for managing Android notification channels.
 * Required for Android 8.0 (API 26) and above.
 */
public class NotificationChannelManager {

    // Channel IDs
    public static final String CHANNEL_DEFAULT = "runic-default";
    public static final String CHANNEL_ALERTS = "runic-alerts";
    public static final String CHANNEL_SYNC = "runic-sync";

    /**
     * Creates all notification channels required by the app.
     * Should be called when the application starts.
     *
     * @param context Application context
     */
    public static void createNotificationChannels(Context context) {
        // Only needed for Android O and above
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return;
        }

        NotificationManager manager =
            (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);

        if (manager == null) {
            return;
        }

        // Default notifications channel
        NotificationChannel defaultChannel = new NotificationChannel(
            CHANNEL_DEFAULT,
            "General Notifications",
            NotificationManager.IMPORTANCE_DEFAULT
        );
        defaultChannel.setDescription("General notifications from Runic");
        defaultChannel.enableVibration(true);
        defaultChannel.setShowBadge(true);
        manager.createNotificationChannel(defaultChannel);

        // High-priority alerts channel
        NotificationChannel alertsChannel = new NotificationChannel(
            CHANNEL_ALERTS,
            "Important Alerts",
            NotificationManager.IMPORTANCE_HIGH
        );
        alertsChannel.setDescription("Important alerts and warnings");
        alertsChannel.enableVibration(true);
        alertsChannel.enableLights(true);
        alertsChannel.setShowBadge(true);
        manager.createNotificationChannel(alertsChannel);

        // Sync status channel (low priority)
        NotificationChannel syncChannel = new NotificationChannel(
            CHANNEL_SYNC,
            "Sync Status",
            NotificationManager.IMPORTANCE_LOW
        );
        syncChannel.setDescription("Background sync notifications");
        syncChannel.enableVibration(false);
        syncChannel.setShowBadge(false);
        manager.createNotificationChannel(syncChannel);
    }

    /**
     * Deletes all notification channels.
     * Used when resetting app settings.
     *
     * @param context Application context
     */
    public static void deleteAllChannels(Context context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return;
        }

        NotificationManager manager =
            (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);

        if (manager != null) {
            manager.deleteNotificationChannel(CHANNEL_DEFAULT);
            manager.deleteNotificationChannel(CHANNEL_ALERTS);
            manager.deleteNotificationChannel(CHANNEL_SYNC);
        }
    }
}
