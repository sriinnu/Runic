/**
 * @file HomeScreen.tsx
 * @description Main dashboard screen displaying provider overview and usage summary.
 * Shows all active providers and aggregated statistics.
 */

import React, { useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  RefreshControl,
  TouchableOpacity,
} from 'react-native';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useTheme } from '../hooks';
import { useProviderStore, useAppStore } from '../stores';
import { ProviderCard, AlertBanner, LoadingSpinner } from '../components';
import { formatCurrency } from '../utils/formatters';
import type { RootStackParamList } from '../types';

type NavigationProp = NativeStackNavigationProp<RootStackParamList, 'Home'>;

/**
 * Home screen component displaying dashboard with provider cards.
 * Shows aggregated usage statistics and quick actions.
 *
 * @example
 * <HomeScreen />
 */
export function HomeScreen() {
  const theme = useTheme();
  const navigation = useNavigation<NavigationProp>();

  // Store hooks
  const {
    isLoading,
    syncAllProviders,
    getEnabledProviders,
    initialize: initializeProviders,
  } = useProviderStore();

  const {
    alerts,
    removeAlert,
    initialize: initializeApp,
  } = useAppStore();

  // Initialize stores on mount
  useEffect(() => {
    initializeApp();
    initializeProviders();
  }, []);

  // Pull to refresh handler
  const [refreshing, setRefreshing] = React.useState(false);

  const handleRefresh = useCallback(async () => {
    setRefreshing(true);
    try {
      await syncAllProviders(true);
    } finally {
      setRefreshing(false);
    }
  }, [syncAllProviders]);

  // Get enabled providers
  const enabledProviders = getEnabledProviders();

  // Calculate aggregated statistics
  const aggregatedStats = React.useMemo(() => {
    const totalCost = enabledProviders.reduce(
      (sum, p) => sum + p.usage.totalCost,
      0
    );
    const totalTokens = enabledProviders.reduce(
      (sum, p) => sum + p.usage.totalTokens,
      0
    );
    const totalRequests = enabledProviders.reduce(
      (sum, p) => sum + p.usage.requestCount,
      0
    );

    return { totalCost, totalTokens, totalRequests };
  }, [enabledProviders]);

  // Handle provider card press
  const handleProviderPress = useCallback(
    (providerId: string) => {
      navigation.navigate('ProviderDetail', { providerId });
    },
    [navigation]
  );

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
        <Text
          style={[
            styles.title,
            theme.typography.headlineMedium,
            { color: theme.colors.onSurface },
          ]}
        >
          Dashboard
        </Text>

        {/* Summary cards */}
        <View style={styles.summaryCards}>
          <SummaryCard
            label="Total Cost"
            value={formatCurrency(aggregatedStats.totalCost)}
          />
          <SummaryCard
            label="Tokens"
            value={aggregatedStats.totalTokens.toLocaleString()}
          />
          <SummaryCard
            label="Requests"
            value={aggregatedStats.totalRequests.toLocaleString()}
          />
        </View>
      </View>

      {/* Alerts */}
      {alerts.map((alert) => (
        <AlertBanner
          key={alert.id}
          alert={alert}
          onDismiss={() => removeAlert(alert.id)}
        />
      ))}

      {/* Provider list */}
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
        {isLoading && !refreshing ? (
          <View style={styles.loadingContainer}>
            <LoadingSpinner size={48} />
            <Text
              style={[
                styles.loadingText,
                theme.typography.bodyMedium,
                { color: theme.colors.onSurfaceVariant },
              ]}
            >
              Loading providers...
            </Text>
          </View>
        ) : enabledProviders.length === 0 ? (
          <View style={styles.emptyContainer}>
            <Text
              style={[
                styles.emptyTitle,
                theme.typography.titleLarge,
                { color: theme.colors.onSurface },
              ]}
            >
              No Providers Added
            </Text>
            <Text
              style={[
                styles.emptyText,
                theme.typography.bodyMedium,
                { color: theme.colors.onSurfaceVariant },
              ]}
            >
              Add a provider to start tracking usage
            </Text>
            <TouchableOpacity
              style={[
                styles.addButton,
                { backgroundColor: theme.colors.primary },
              ]}
              onPress={() => navigation.navigate('Settings')}
            >
              <Text
                style={[
                  styles.addButtonText,
                  theme.typography.labelLarge,
                  { color: theme.colors.onPrimary },
                ]}
              >
                Go to Settings
              </Text>
            </TouchableOpacity>
          </View>
        ) : (
          enabledProviders.map((provider) => (
            <ProviderCard
              key={provider.id}
              provider={provider}
              onPress={() => handleProviderPress(provider.id)}
              style={styles.providerCard}
            />
          ))
        )}
      </ScrollView>
    </View>
  );
}

/**
 * Summary card component for aggregated stats.
 */
function SummaryCard({ label, value }: { label: string; value: string }) {
  const theme = useTheme();

  return (
    <View
      style={[
        styles.summaryCard,
        { backgroundColor: theme.colors.surfaceVariant },
      ]}
    >
      <Text
        style={[
          styles.summaryLabel,
          theme.typography.labelSmall,
          { color: theme.colors.onSurfaceVariant },
        ]}
      >
        {label}
      </Text>
      <Text
        style={[
          styles.summaryValue,
          theme.typography.titleMedium,
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
  title: {
    marginBottom: 16,
  },
  summaryCards: {
    flexDirection: 'row',
    gap: 12,
  },
  summaryCard: {
    flex: 1,
    padding: 12,
    borderRadius: 8,
  },
  summaryLabel: {
    marginBottom: 4,
  },
  summaryValue: {},
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    padding: 16,
  },
  loadingContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 48,
  },
  loadingText: {
    marginTop: 16,
  },
  emptyContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 64,
  },
  emptyTitle: {
    marginBottom: 8,
  },
  emptyText: {
    marginBottom: 24,
    textAlign: 'center',
  },
  addButton: {
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 20,
  },
  addButtonText: {},
  providerCard: {
    marginBottom: 16,
  },
});

export default HomeScreen;
