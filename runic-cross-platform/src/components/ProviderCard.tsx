/**
 * @file ProviderCard.tsx
 * @description Card component displaying provider information and usage statistics.
 * Shows provider name, logo, quota usage, and current status.
 */

import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ViewStyle,
} from 'react-native';
import { useTheme } from '../hooks';
import { formatCurrency, formatPercentage } from '../utils/formatters';
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
}

/**
 * Displays a provider's information in a card format.
 * Shows status, quota usage, and cost information.
 *
 * @example
 * <ProviderCard
 *   provider={providerData}
 *   onPress={() => navigation.navigate('ProviderDetail', { id })}
 * />
 */
export function ProviderCard({ provider, onPress, style }: ProviderCardProps) {
  const theme = useTheme();

  // Calculate quota percentage
  const quotaPercentage =
    provider.billing.quotaLimit > 0
      ? (provider.billing.quotaUsed / provider.billing.quotaLimit) * 100
      : 0;

  // Determine status color
  const statusColor = getStatusColor(provider.status, theme.colors);

  // Determine quota color based on usage
  const quotaColor = getQuotaColor(quotaPercentage, theme.colors);

  return (
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
    >
      {/* Header with logo and name */}
      <View style={styles.header}>
        <View
          style={[
            styles.iconContainer,
            { backgroundColor: provider.brandColor + '20' },
          ]}
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
          >
            {provider.name}
          </Text>
          <View style={styles.statusContainer}>
            <View style={[styles.statusDot, { backgroundColor: statusColor }]} />
            <Text
              style={[
                styles.statusText,
                theme.typography.bodySmall,
                { color: theme.colors.onSurfaceVariant },
              ]}
            >
              {provider.status}
            </Text>
          </View>
        </View>
      </View>

      {/* Quota bar */}
      <View style={styles.quotaSection}>
        <View style={styles.quotaHeader}>
          <Text
            style={[
              styles.quotaLabel,
              theme.typography.labelSmall,
              { color: theme.colors.onSurfaceVariant },
            ]}
          >
            Quota Usage
          </Text>
          <Text
            style={[
              styles.quotaValue,
              theme.typography.labelMedium,
              { color: quotaColor },
            ]}
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
        <View style={styles.costItem}>
          <Text
            style={[
              styles.costLabel,
              theme.typography.labelSmall,
              { color: theme.colors.onSurfaceVariant },
            ]}
          >
            This Cycle
          </Text>
          <Text
            style={[
              styles.costValue,
              theme.typography.titleSmall,
              { color: theme.colors.onSurface },
            ]}
          >
            {formatCurrency(
              provider.billing.estimatedCost,
              provider.billing.currency
            )}
          </Text>
        </View>

        <View style={styles.costItem}>
          <Text
            style={[
              styles.costLabel,
              theme.typography.labelSmall,
              { color: theme.colors.onSurfaceVariant },
            ]}
          >
            Total Tokens
          </Text>
          <Text
            style={[
              styles.costValue,
              theme.typography.titleSmall,
              { color: theme.colors.onSurface },
            ]}
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
        >
          <Text
            style={[
              styles.errorText,
              theme.typography.bodySmall,
              { color: theme.colors.onErrorContainer },
            ]}
            numberOfLines={1}
          >
            {provider.lastError}
          </Text>
        </View>
      )}
    </TouchableOpacity>
  );
}

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

const styles = StyleSheet.create({
  container: {
    borderRadius: 12,
    padding: 16,
    borderWidth: 1,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 16,
  },
  iconContainer: {
    width: 48,
    height: 48,
    borderRadius: 24,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 12,
  },
  iconText: {
    fontSize: 24,
    fontWeight: '600',
  },
  headerText: {
    flex: 1,
  },
  providerName: {
    marginBottom: 4,
  },
  statusContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  statusDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    marginRight: 6,
  },
  statusText: {
    textTransform: 'capitalize',
  },
  quotaSection: {
    marginBottom: 16,
  },
  quotaHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 8,
  },
  quotaLabel: {},
  quotaValue: {},
  progressBar: {
    height: 6,
    borderRadius: 3,
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    borderRadius: 3,
  },
  footer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  costItem: {
    flex: 1,
  },
  costLabel: {
    marginBottom: 4,
  },
  costValue: {},
  errorBanner: {
    marginTop: 12,
    padding: 8,
    borderRadius: 6,
  },
  errorText: {},
});

export default ProviderCard;
