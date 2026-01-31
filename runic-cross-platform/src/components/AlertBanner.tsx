/**
 * @file AlertBanner.tsx
 * @description Banner component for displaying alerts and notifications.
 * Supports different severity levels with appropriate styling.
 */

import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Animated,
} from 'react-native';
import { useTheme } from '../hooks';
import type { Alert, AlertSeverity } from '../types';

/**
 * Props for AlertBanner component
 */
interface AlertBannerProps {
  /** Alert data to display */
  alert: Alert;
  /** Callback when banner is dismissed */
  onDismiss?: () => void;
}

/**
 * Displays an alert banner with icon, message, and optional action.
 * Automatically styled based on severity level.
 *
 * @example
 * <AlertBanner
 *   alert={{
 *     id: '1',
 *     message: 'Quota exceeded',
 *     severity: 'error',
 *     timestamp: Date.now(),
 *   }}
 *   onDismiss={() => removeAlert('1')}
 * />
 */
export function AlertBanner({ alert, onDismiss }: AlertBannerProps) {
  const theme = useTheme();
  const fadeAnim = React.useRef(new Animated.Value(0)).current;

  // Fade in on mount
  React.useEffect(() => {
    Animated.timing(fadeAnim, {
      toValue: 1,
      duration: 300,
      useNativeDriver: true,
    }).start();
  }, []);

  // Get colors based on severity
  const colors = getSeverityColors(alert.severity, theme.colors);

  // Handle dismiss with fade out
  const handleDismiss = () => {
    Animated.timing(fadeAnim, {
      toValue: 0,
      duration: 200,
      useNativeDriver: true,
    }).start(() => {
      onDismiss?.();
    });
  };

  return (
    <Animated.View
      style={[
        styles.container,
        {
          backgroundColor: colors.background,
          borderLeftColor: colors.border,
          opacity: fadeAnim,
        },
        theme.elevation.level1,
      ]}
    >
      {/* Icon */}
      <View style={[styles.iconContainer, { backgroundColor: colors.icon }]}>
        <Text style={styles.iconText}>{getSeverityIcon(alert.severity)}</Text>
      </View>

      {/* Content */}
      <View style={styles.content}>
        <Text
          style={[
            styles.message,
            theme.typography.bodyMedium,
            { color: colors.text },
          ]}
        >
          {alert.message}
        </Text>

        {/* Action button */}
        {alert.actionText && alert.onAction && (
          <TouchableOpacity
            style={styles.actionButton}
            onPress={alert.onAction}
            activeOpacity={0.7}
          >
            <Text
              style={[
                styles.actionText,
                theme.typography.labelMedium,
                { color: theme.colors.primary },
              ]}
            >
              {alert.actionText}
            </Text>
          </TouchableOpacity>
        )}
      </View>

      {/* Dismiss button */}
      <TouchableOpacity
        style={styles.dismissButton}
        onPress={handleDismiss}
        hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
      >
        <Text style={[styles.dismissText, { color: colors.text }]}>✕</Text>
      </TouchableOpacity>
    </Animated.View>
  );
}

/**
 * Gets icon emoji based on severity.
 */
function getSeverityIcon(severity: AlertSeverity): string {
  switch (severity) {
    case 'error':
      return '⚠️';
    case 'warning':
      return '⚡';
    case 'success':
      return '✓';
    case 'info':
    default:
      return 'ℹ️';
  }
}

/**
 * Gets color scheme based on severity.
 */
function getSeverityColors(severity: AlertSeverity, themeColors: any) {
  switch (severity) {
    case 'error':
      return {
        background: themeColors.errorContainer,
        text: themeColors.onErrorContainer,
        border: themeColors.error,
        icon: themeColors.error + '40',
      };
    case 'warning':
      return {
        background: '#FFF3E0',
        text: '#E65100',
        border: '#FF9800',
        icon: '#FF980040',
      };
    case 'success':
      return {
        background: '#E8F5E9',
        text: '#1B5E20',
        border: '#4CAF50',
        icon: '#4CAF5040',
      };
    case 'info':
    default:
      return {
        background: themeColors.primaryContainer,
        text: themeColors.onPrimaryContainer,
        border: themeColors.primary,
        icon: themeColors.primary + '40',
      };
  }
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 12,
    borderRadius: 8,
    borderLeftWidth: 4,
    marginHorizontal: 16,
    marginVertical: 8,
  },
  iconContainer: {
    width: 32,
    height: 32,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 12,
  },
  iconText: {
    fontSize: 16,
  },
  content: {
    flex: 1,
  },
  message: {
    marginBottom: 4,
  },
  actionButton: {
    marginTop: 8,
    paddingVertical: 4,
    alignSelf: 'flex-start',
  },
  actionText: {
    textTransform: 'uppercase',
  },
  dismissButton: {
    padding: 4,
    marginLeft: 8,
  },
  dismissText: {
    fontSize: 18,
    fontWeight: '600',
  },
});

export default AlertBanner;
