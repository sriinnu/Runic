/**
 * @file ProviderDetailScreen.tsx
 * @description Detailed view of a single provider showing usage charts and statistics.
 * Displays historical data and billing information.
 */

import React, { useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  RefreshControl,
} from 'react-native';
import { useRoute, useNavigation } from '@react-navigation/native';
import type { RouteProp } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useTheme } from '../hooks';
import { useProviderStore } from '../stores';
import { UsageChart, LoadingSpinner } from '../components';
import { formatCurrency, formatRelativeTime, formatPercentage } from '../utils/formatters';
import type { RootStackParamList } from '../types';

type RouteProps = RouteProp<RootStackParamList, 'ProviderDetail'>;
type NavigationProp = NativeStackNavigationProp<RootStackParamList, 'ProviderDetail'>;

/**
 * Provider detail screen showing comprehensive usage data.
 * Includes charts, billing info, and sync controls.
 *
 * @example
 * navigation.navigate('ProviderDetail', { providerId: 'openai' });
 */
export function ProviderDetailScreen() {
  const theme = useTheme();
  const route = useRoute<RouteProps>();
  const navigation = useNavigation<NavigationProp>();

  const { providerId } = route.params;

  // Store hooks
  const { getProvider, syncProvider } = useProviderStore();

  const provider = getProvider(providerId as any);

  // Refresh handler
  const [refreshing, setRefreshing] = React.useState(false);

  const handleRefresh = useCallback(async () => {
    if (!provider) return;

    setRefreshing(true);
    try {
      await syncProvider(provider.id, true);
    } finally {
      setRefreshing(false);
    }
  }, [provider, syncProvider]);

  // Navigate to edit screen
  const handleEdit = useCallback(() => {
    navigation.navigate('EditProvider', { providerId });
  }, [navigation, providerId]);

  // Show loading if provider not found
  if (!provider) {
    return (
      <View style={[styles.container, { backgroundColor: theme.colors.background }]}>
        <View style={styles.loadingContainer}>
          <LoadingSpinner size={48} />
          <Text
            style={[
              styles.loadingText,
              theme.typography.bodyMedium,
              { color: theme.colors.onSurfaceVariant },
            ]}
          >
            Loading provider...
          </Text>
        </View>
      </View>
    );
  }

  // Calculate quota percentage
  const quotaPercentage =
    provider.billing.quotaLimit > 0
      ? (provider.billing.quotaUsed / provider.billing.quotaLimit) * 100
      : 0;

  return (
    <View style={[styles.container, { backgroundColor: theme.colors.background }]}>
      {/* Header */}
      <View
        style={[
          styles.header,
          { backgroundColor: theme.colors.surface },
          theme.elevation.level1,
        ]}
      >
        <View style={styles.headerTop}>
          <TouchableOpacity onPress={() => navigation.goBack()}>
            <Text style={[styles.backButton, { color: theme.colors.primary }]}>
              ← Back
            </Text>
          </TouchableOpacity>

          <TouchableOpacity onPress={handleEdit}>
            <Text style={[styles.editButton, { color: theme.colors.primary }]}>
              Edit
            </Text>
          </TouchableOpacity>
        </View>

        <Text
          style={[
            styles.title,
            theme.typography.headlineMedium,
            { color: theme.colors.onSurface },
          ]}
        >
          {provider.name}
        </Text>

        <Text
          style={[
            styles.description,
            theme.typography.bodyMedium,
            { color: theme.colors.onSurfaceVariant },
          ]}
        >
          {provider.description}
        </Text>
      </View>

      <ScrollView
        style={styles.scrollView}
        contentContainerStyle={styles.scrollContent}
        refreshControl={
          <RefreshControl
            refreshing={refreshing}
            onRefresh={handleRefresh}
            tintColor={theme.colors.primary}
            colors={[theme.colors.primary]}
          />
        }
      >
        {/* Billing Section */}
        <View
          style={[
            styles.section,
            { backgroundColor: theme.colors.surface },
            theme.elevation.level1,
          ]}
        >
          <Text
            style={[
              styles.sectionTitle,
              theme.typography.titleMedium,
              { color: theme.colors.onSurface },
            ]}
          >
            Billing & Quota
          </Text>

          <View style={styles.infoGrid}>
            <InfoItem
              label="Current Cycle"
              value={formatCurrency(
                provider.billing.estimatedCost,
                provider.billing.currency
              )}
            />
            <InfoItem
              label="Quota Used"
              value={formatPercentage(quotaPercentage)}
            />
            <InfoItem
              label="Quota Remaining"
              value={provider.billing.quotaRemaining.toLocaleString()}
            />
            <InfoItem
              label="Billing Cycle"
              value={provider.billing.cycle}
            />
          </View>
        </View>

        {/* Usage Statistics */}
        <View
          style={[
            styles.section,
            { backgroundColor: theme.colors.surface },
            theme.elevation.level1,
          ]}
        >
          <Text
            style={[
              styles.sectionTitle,
              theme.typography.titleMedium,
              { color: theme.colors.onSurface },
            ]}
          >
            Usage Statistics
          </Text>

          <View style={styles.infoGrid}>
            <InfoItem
              label="Total Tokens"
              value={provider.usage.totalTokens.toLocaleString()}
            />
            <InfoItem
              label="Total Cost"
              value={formatCurrency(provider.usage.totalCost)}
            />
            <InfoItem
              label="Requests"
              value={provider.usage.requestCount.toLocaleString()}
            />
            <InfoItem
              label="Avg Tokens/Request"
              value={Math.round(provider.usage.averageTokensPerRequest).toLocaleString()}
            />
          </View>
        </View>

        {/* Charts */}
        <View
          style={[
            styles.section,
            { backgroundColor: theme.colors.surface },
            theme.elevation.level1,
          ]}
        >
          <UsageChart
            dataPoints={provider.usage.dataPoints}
            title="Token Usage (Last 7 Days)"
            showCost={false}
          />
        </View>

        <View
          style={[
            styles.section,
            { backgroundColor: theme.colors.surface },
            theme.elevation.level1,
          ]}
        >
          <UsageChart
            dataPoints={provider.usage.dataPoints}
            title="Cost (Last 7 Days)"
            showCost={true}
          />
        </View>

        {/* Sync Info */}
        <View
          style={[
            styles.section,
            { backgroundColor: theme.colors.surface },
            theme.elevation.level1,
          ]}
        >
          <Text
            style={[
              styles.sectionTitle,
              theme.typography.titleMedium,
              { color: theme.colors.onSurface },
            ]}
          >
            Sync Information
          </Text>

          <Text
            style={[
              styles.syncTime,
              theme.typography.bodyMedium,
              { color: theme.colors.onSurfaceVariant },
            ]}
          >
            Last synced {formatRelativeTime(provider.lastSyncTime)}
          </Text>

          {provider.lastError && (
            <Text
              style={[
                styles.errorText,
                theme.typography.bodySmall,
                { color: theme.colors.error },
              ]}
            >
              Error: {provider.lastError}
            </Text>
          )}
        </View>
      </ScrollView>
    </View>
  );
}

/**
 * Info item component for displaying label-value pairs.
 */
function InfoItem({ label, value }: { label: string; value: string }) {
  const theme = useTheme();

  return (
    <View style={styles.infoItem}>
      <Text
        style={[
          styles.infoLabel,
          theme.typography.labelSmall,
          { color: theme.colors.onSurfaceVariant },
        ]}
      >
        {label}
      </Text>
      <Text
        style={[
          styles.infoValue,
          theme.typography.titleSmall,
          { color: theme.colors.onSurface },
        ]}
      >
        {value}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    padding: 16,
    paddingTop: 48,
  },
  headerTop: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 16,
  },
  backButton: {
    fontSize: 16,
  },
  editButton: {
    fontSize: 16,
  },
  title: {
    marginBottom: 8,
  },
  description: {},
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    padding: 16,
  },
  loadingContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  loadingText: {
    marginTop: 16,
  },
  section: {
    padding: 16,
    borderRadius: 12,
    marginBottom: 16,
  },
  sectionTitle: {
    marginBottom: 16,
  },
  infoGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 16,
  },
  infoItem: {
    width: '45%',
  },
  infoLabel: {
    marginBottom: 4,
  },
  infoValue: {},
  syncTime: {
    marginBottom: 8,
  },
  errorText: {
    marginTop: 8,
  },
});

export default ProviderDetailScreen;
