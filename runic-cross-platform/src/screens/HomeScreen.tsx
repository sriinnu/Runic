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
  FlatList,
  RefreshControl,
  TouchableOpacity,
  ListRenderItemInfo,
} from 'react-native';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useTheme } from '../hooks';
import { useProviderStore, useAppStore } from '../stores';
import { ProviderCard, AlertBanner, LoadingSpinner, SkeletonCard } from '../components';
import { formatCurrency } from '../utils/formatters';
import type { RootStackParamList } from '../types';

type NavigationProp = NativeStackNavigationProp<RootStackParamList, 'Home'>;

// Performance: Constant item height for FlatList optimization
const PROVIDER_CARD_HEIGHT = 220;
const PROVIDER_CARD_MARGIN = 16;
const ITEM_HEIGHT = PROVIDER_CARD_HEIGHT + PROVIDER_CARD_MARGIN;

/**
 * Home screen component displaying dashboard with provider cards.
 * Shows aggregated usage statistics and quick actions.
 * Performance optimized with FlatList virtualization.
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

  // Performance: FlatList render item (memoized)
  const renderProviderCard = useCallback(
    ({ item }: ListRenderItemInfo<typeof enabledProviders[number]>) => (
      <ProviderCard
        key={item.id}
        provider={item}
        onPress={() => handleProviderPress(item.id)}
        style={styles.providerCard}
        isRefreshing={refreshing}
      />
    ),
    [handleProviderPress, refreshing]
  );

  // Performance: FlatList key extractor
  const keyExtractor = useCallback(
    (item: typeof enabledProviders[number]) => item.id,
    []
  );

  // Performance: FlatList getItemLayout for instant scrolling
  const getItemLayout = useCallback(
    (_: any, index: number) => ({
      length: ITEM_HEIGHT,
      offset: ITEM_HEIGHT * index,
      index,
    }),
    []
  );

  // Performance: Empty list component
  const renderEmptyComponent = useCallback(() => (
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
  ), [theme, navigation]);

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

      {/* Provider list - Performance optimized with FlatList */}
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
          {/* Show skeleton cards while loading */}
          <View style={styles.skeletonContainer}>
            {[1, 2, 3].map((i) => (
              <SkeletonCard key={i} style={styles.providerCard} />
            ))}
          </View>
        </View>
      ) : (
        <FlatList
          data={enabledProviders}
          renderItem={renderProviderCard}
          keyExtractor={keyExtractor}
          getItemLayout={getItemLayout}
          contentContainerStyle={styles.scrollContent}
          refreshControl={
            <RefreshControl
              refreshing={refreshing}
              onRefresh={handleRefresh}
              tintColor={theme.colors.primary}
              colors={[theme.colors.primary]}
            />
          }
          ListEmptyComponent={renderEmptyComponent}
          // Performance: Memory optimization
          windowSize={5}
          maxToRenderPerBatch={5}
          initialNumToRender={8}
          removeClippedSubviews={true}
          // Performance: Update optimization
          updateCellsBatchingPeriod={50}
        />
      )}
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
    marginBottom: 24,
  },
  skeletonContainer: {
    width: '100%',
    paddingHorizontal: 16,
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
