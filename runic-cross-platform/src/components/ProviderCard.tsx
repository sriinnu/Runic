/**
 * @file ProviderCard.tsx
 * @description Card component displaying provider information and usage statistics.
 * Shows provider name, logo, quota usage, and current status.
 */

import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ViewStyle,
  ActivityIndicator,
  Animated,
} from 'react-native';
import { useTheme } from '../hooks';
import { formatCurrency, formatPercentage } from '../utils/formatters';
import type { Theme } from '../theme';
import type { Provider } from '../types';

/**
 * Props for ProviderCard component
 */
interface ProviderCardProps {
  /** Provider data to display */
  provider: Provider;
  /** Callback when card is pressed */
  onPress?: () => void;
  /** Optional custom styles */
  style?: ViewStyle;
  /** Whether the card is refreshing data */
  isRefreshing?: boolean;
}

/**
 * Displays a provider's information in a card format.
 * Shows status, quota usage, and cost information.
 * Supports loading states with smooth transitions.
 * Performance optimized with React.memo and custom comparison.
 *
 * @example
 * <ProviderCard
 *   provider={providerData}
 *   onPress={() => navigation.navigate('ProviderDetail', { id })}
 *   isRefreshing={true}
 * />
 */
export const ProviderCard = React.memo(
  function ProviderCard({ provider, onPress, style, isRefreshing = false }: ProviderCardProps) {
    const theme = useTheme();
    const styles = createStyles(theme);

    // Fade in animation when data loads
    const [fadeAnim] = useState(new Animated.Value(0));

    useEffect(() => {
      Animated.timing(fadeAnim, {
        toValue: 1,
        duration: 300,
        useNativeDriver: true,
      }).start();
    }, [provider.id]);

    // Calculate quota percentage
    const quotaPercentage =
      provider.billing.quotaLimit > 0
        ? (provider.billing.quotaUsed / provider.billing.quotaLimit) * 100
        : 0;

    // Determine status color
    const statusColor = getStatusColor(provider.status, theme.colors);

    // Determine quota color based on usage
    const quotaColor = getQuotaColor(quotaPercentage, theme.colors);

    // Build comprehensive accessibility label
    const accessibilityLabel = [
      provider.name,
      `Status: ${provider.status}`,
      `Quota usage: ${formatPercentage(quotaPercentage)}`,
      provider.lastError ? `Error: ${provider.lastError}` : null,
    ]
      .filter(Boolean)
      .join(', ');

    return (
      <Animated.View style={{ opacity: fadeAnim }}>
        <TouchableOpacity
          style={[
            styles.container,
            {
              backgroundColor: theme.colors.surface,
              borderColor: theme.colors.outline,
            },
            theme.elevation.level2,
            style,
          ]}
          onPress={onPress}
          activeOpacity={0.7}
          disabled={isRefreshing}
          accessibilityRole="button"
          accessibilityLabel={accessibilityLabel}
          accessibilityHint="View detailed provider information and manage settings"
          accessibilityState={{ disabled: isRefreshing }}
        >
          {/* Loading indicator overlay */}
          {isRefreshing && (
            <View
              style={styles.loadingOverlay}
              accessibilityLabel="Loading provider data"
              accessibilityLiveRegion="polite"
            >
              <ActivityIndicator size="small" color={theme.colors.primary} />
            </View>
          )}

          {/* Header with logo and name */}
          <View style={styles.header} accessibilityRole="header">
            <View
              style={[
                styles.iconContainer,
                { backgroundColor: provider.brandColor + '20' },
              ]}
              accessible={false}
              importantForAccessibility="no"
            >
              <Text style={[styles.iconText, { color: provider.brandColor }]}>
                {provider.name.charAt(0)}
              </Text>
            </View>

            <View style={styles.headerText}>
              <Text
                style={[
                  styles.providerName,
                  theme.typography.titleMedium,
                  { color: theme.colors.onSurface },
                ]}
                accessibilityRole="header"
                accessibilityLabel={`Provider: ${provider.name}`}
              >
                {provider.name}
              </Text>
              <View style={styles.statusContainer}>
                <View
                  style={[styles.statusDot, { backgroundColor: statusColor }]}
                  accessible={false}
                  importantForAccessibility="no"
                />
                <Text
                  style={[
                    styles.statusText,
                    theme.typography.bodySmall,
                    { color: theme.colors.onSurfaceVariant },
                  ]}
                  accessibilityLabel={`Status: ${provider.status}`}
                >
                  {provider.status}
                </Text>
              </View>
            </View>
          </View>

          {/* Quota bar */}
          <View
            style={styles.quotaSection}
            accessible={true}
            accessibilityRole="progressbar"
            accessibilityLabel={`Quota usage: ${formatPercentage(quotaPercentage)}`}
            accessibilityValue={{ min: 0, max: 100, now: quotaPercentage }}
          >
            <View style={styles.quotaHeader}>
              <Text
                style={[
                  styles.quotaLabel,
                  theme.typography.labelSmall,
                  { color: theme.colors.onSurfaceVariant },
                ]}
                accessible={false}
              >
                Quota Usage
              </Text>
              <Text
                style={[
                  styles.quotaValue,
                  theme.typography.labelMedium,
                  { color: quotaColor },
                ]}
                accessible={false}
              >
                {formatPercentage(quotaPercentage)}
              </Text>
            </View>

            {/* Progress bar */}
            <View
              style={[
                styles.progressBar,
                { backgroundColor: theme.colors.surfaceVariant },
              ]}
              accessible={false}
              importantForAccessibility="no"
            >
              <View
                style={[
                  styles.progressFill,
                  {
                    width: `${Math.min(quotaPercentage, 100)}%`,
                    backgroundColor: quotaColor,
                  },
                ]}
              />
            </View>
          </View>

          {/* Cost information */}
          <View style={styles.footer}>
            <View
              style={styles.costItem}
              accessible={true}
              accessibilityLabel={`This cycle cost: ${formatCurrency(
                provider.billing.estimatedCost,
                provider.billing.currency
              )}`}
            >
              <Text
                style={[
                  styles.costLabel,
                  theme.typography.labelSmall,
                  { color: theme.colors.onSurfaceVariant },
                ]}
                accessible={false}
              >
                This Cycle
              </Text>
              <Text
                style={[
                  styles.costValue,
                  theme.typography.titleSmall,
                  { color: theme.colors.onSurface },
                ]}
                accessible={false}
              >
                {formatCurrency(
                  provider.billing.estimatedCost,
                  provider.billing.currency
                )}
              </Text>
            </View>

            <View
              style={styles.costItem}
              accessible={true}
              accessibilityLabel={`Total tokens: ${provider.usage.totalTokens.toLocaleString()}`}
            >
              <Text
                style={[
                  styles.costLabel,
                  theme.typography.labelSmall,
                  { color: theme.colors.onSurfaceVariant },
                ]}
                accessible={false}
              >
                Total Tokens
              </Text>
              <Text
                style={[
                  styles.costValue,
                  theme.typography.titleSmall,
                  { color: theme.colors.onSurface },
                ]}
                accessible={false}
              >
                {provider.usage.totalTokens.toLocaleString()}
              </Text>
            </View>
          </View>

          {/* Error message if present */}
          {provider.lastError && (
            <View
              style={[
                styles.errorBanner,
                { backgroundColor: theme.colors.errorContainer },
              ]}
              accessible={true}
              accessibilityRole="alert"
              accessibilityLabel={`Error: ${provider.lastError}`}
              accessibilityLiveRegion="polite"
            >
              <Text
                style={[
                  styles.errorText,
                  theme.typography.bodySmall,
                  { color: theme.colors.onErrorContainer },
                ]}
                numberOfLines={1}
                accessible={false}
              >
                {provider.lastError}
              </Text>
            </View>
          )}
        </TouchableOpacity>
      </Animated.View>
    );
  },
  // Performance: Custom comparison function to prevent unnecessary re-renders
  (prevProps, nextProps) => {
    // Only re-render if these specific properties change
    return (
      prevProps.provider.id === nextProps.provider.id &&
      prevProps.provider.status === nextProps.provider.status &&
      prevProps.provider.billing.quotaUsed === nextProps.provider.billing.quotaUsed &&
      prevProps.provider.billing.quotaLimit === nextProps.provider.billing.quotaLimit &&
      prevProps.provider.billing.estimatedCost === nextProps.provider.billing.estimatedCost &&
      prevProps.provider.usage.totalTokens === nextProps.provider.usage.totalTokens &&
      prevProps.provider.lastError === nextProps.provider.lastError &&
      prevProps.isRefreshing === nextProps.isRefreshing
    );
  }
);

/**
 * Gets status color based on provider status.
 */
function getStatusColor(status: string, colors: any): string {
  switch (status) {
    case 'active':
      return '#00C853';
    case 'error':
      return colors.error;
    case 'limited':
      return '#FFB300';
    default:
      return colors.onSurfaceVariant;
  }
}

/**
 * Gets quota color based on usage percentage.
 */
function getQuotaColor(percentage: number, colors: any): string {
  if (percentage >= 90) {
    return colors.error;
  } else if (percentage >= 75) {
    return '#FFB300';
  } else {
    return colors.primary;
  }
}

// Create styles with theme
function createStyles(theme: Theme) {
  return StyleSheet.create({
    container: {
      borderRadius: theme.borderRadius.md,
      padding: theme.spacing.md,
      borderWidth: 1,
    },
    loadingOverlay: {
      position: 'absolute',
      top: 0,
      right: 0,
      padding: theme.spacing.md,
      zIndex: 1,
    },
    header: {
      flexDirection: 'row',
      alignItems: 'center',
      marginBottom: theme.spacing.md,
    },
    iconContainer: {
      width: theme.spacing.xxl,
      height: theme.spacing.xxl,
      borderRadius: theme.spacing.lg,
      alignItems: 'center',
      justifyContent: 'center',
      marginRight: theme.spacing.md,
    },
    iconText: {
      fontSize: 24,
      fontWeight: '600',
    },
    headerText: {
      flex: 1,
    },
    providerName: {
      marginBottom: theme.spacing.xs,
    },
    statusContainer: {
      flexDirection: 'row',
      alignItems: 'center',
    },
    statusDot: {
      width: theme.spacing.sm,
      height: theme.spacing.sm,
      borderRadius: theme.spacing.xs,
      marginRight: theme.spacing.sm,
    },
    statusText: {
      textTransform: 'capitalize',
    },
    quotaSection: {
      marginBottom: theme.spacing.md,
    },
    quotaHeader: {
      flexDirection: 'row',
      justifyContent: 'space-between',
      marginBottom: theme.spacing.sm,
    },
    quotaLabel: {},
    quotaValue: {},
    progressBar: {
      height: theme.spacing.sm,
      borderRadius: theme.borderRadius.xs,
      overflow: 'hidden',
    },
    progressFill: {
      height: '100%',
      borderRadius: theme.borderRadius.xs,
    },
    footer: {
      flexDirection: 'row',
      justifyContent: 'space-between',
    },
    costItem: {
      flex: 1,
    },
    costLabel: {
      marginBottom: theme.spacing.xs,
    },
    costValue: {},
    errorBanner: {
      marginTop: theme.spacing.md,
      padding: theme.spacing.sm,
      borderRadius: theme.borderRadius.sm,
    },
    errorText: {},
  });
}

export default ProviderCard;
