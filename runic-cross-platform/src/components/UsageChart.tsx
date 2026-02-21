/**
 * @file UsageChart.tsx
 * @description Line chart component for displaying usage data over time.
 * Uses react-native-chart-kit for rendering.
 */

import React, { useMemo } from 'react';
import { View, Text, StyleSheet, Dimensions } from 'react-native';
import { LineChart } from 'react-native-chart-kit';
import { useTheme } from '../hooks';
import { formatLargeNumber, formatCurrency } from '../utils/formatters';
import type { Theme } from '../theme';
import type { UsageDataPoint } from '../types';

const SCREEN_WIDTH = Dimensions.get('window').width;

/**
 * Props for UsageChart component
 */
interface UsageChartProps {
  /** Array of usage data points */
  dataPoints: UsageDataPoint[];
  /** Chart title */
  title?: string;
  /** Show cost instead of tokens */
  showCost?: boolean;
  /** Chart height */
  height?: number;
}

/**
 * Displays usage or cost data as a line chart.
 * Automatically formats labels and handles empty data.
 * Performance optimized with useMemo for all calculations.
 *
 * @example
 * <UsageChart
 *   dataPoints={provider.usage.dataPoints}
 *   title="Token Usage"
 *   showCost={false}
 * />
 */
export const UsageChart = React.memo(
  function UsageChart({
    dataPoints,
    title = 'Usage',
    showCost = false,
    height = 220,
  }: UsageChartProps) {
    const theme = useTheme();
    const styles = useMemo(() => createStyles(theme), [theme]);

    // Performance: Prepare chart data with useMemo to avoid recalculation
    const chartData = useMemo(() => {
      if (dataPoints.length === 0) {
        // Return empty data set
        return {
          labels: ['No Data'],
          datasets: [{ data: [0] }],
        };
      }

      // Take last 7 data points for display
      const recentData = dataPoints.slice(-7);

      // Extract labels (dates) and values
      const labels = recentData.map((point) => {
        const date = new Date(point.timestamp);
        return `${date.getMonth() + 1}/${date.getDate()}`;
      });

      const values = recentData.map((point) =>
        showCost ? point.cost : point.value
      );

      return {
        labels,
        datasets: [
          {
            data: values,
            color: (opacity = 1) => `rgba(98, 0, 238, ${opacity})`,
            strokeWidth: 2,
          },
        ],
      };
    }, [dataPoints, showCost]);

    // Performance: Calculate statistics with useMemo
    const stats = useMemo(() => {
      if (dataPoints.length === 0) {
        return { min: 0, max: 0, avg: 0 };
      }

      const values = dataPoints.map((p) => (showCost ? p.cost : p.value));
      const min = Math.min(...values);
      const max = Math.max(...values);
      const avg = values.reduce((a, b) => a + b, 0) / values.length;

      return { min, max, avg };
    }, [dataPoints, showCost]);

    // Performance: Chart configuration memoized
    const chartConfig = useMemo(
      () => ({
        backgroundColor: theme.colors.surface,
        backgroundGradientFrom: theme.colors.surface,
        backgroundGradientTo: theme.colors.surface,
        decimalPlaces: showCost ? 2 : 0,
        color: (opacity = 1) =>
          theme.colors.primary + Math.floor(opacity * 255).toString(16),
        labelColor: (opacity = 1) =>
          theme.colors.onSurfaceVariant +
          Math.floor(opacity * 255).toString(16),
        style: {
          borderRadius: 16,
        },
        propsForDots: {
          r: '4',
          strokeWidth: '2',
          stroke: theme.colors.primary,
        },
        propsForBackgroundLines: {
          strokeDasharray: '', // solid lines
          stroke: theme.colors.outlineVariant,
          strokeWidth: 1,
        },
      }),
      [theme, showCost]
    );

    // Performance: Formatted stats memoized
    const formattedStats = useMemo(
      () => ({
        min: showCost
          ? formatCurrency(stats.min)
          : formatLargeNumber(stats.min),
        avg: showCost
          ? formatCurrency(stats.avg)
          : formatLargeNumber(stats.avg),
        max: showCost
          ? formatCurrency(stats.max)
          : formatLargeNumber(stats.max),
      }),
      [stats, showCost]
    );

    return (
      <View style={styles.container}>
        {/* Title and statistics */}
        <View style={styles.header}>
          <Text
            style={[
              styles.title,
              theme.typography.titleMedium,
              { color: theme.colors.onSurface },
            ]}
          >
            {title}
          </Text>

          <View style={styles.stats}>
            <StatItem label="Min" value={formattedStats.min} />
            <StatItem label="Avg" value={formattedStats.avg} />
            <StatItem label="Max" value={formattedStats.max} />
          </View>
        </View>

        {/* Chart */}
        <LineChart
          data={chartData}
          width={SCREEN_WIDTH - 32}
          height={height}
          chartConfig={chartConfig}
          bezier
          style={styles.chart}
          withInnerLines={true}
          withOuterLines={true}
          withVerticalLines={false}
          withHorizontalLines={true}
          withDots={dataPoints.length > 0}
          withShadow={false}
          fromZero={true}
        />
      </View>
    );
  },
  // Performance: Custom comparison to prevent unnecessary re-renders
  (prevProps, nextProps) => {
    return (
      prevProps.dataPoints.length === nextProps.dataPoints.length &&
      prevProps.title === nextProps.title &&
      prevProps.showCost === nextProps.showCost &&
      prevProps.height === nextProps.height &&
      // Only re-render if the last data point changed (most recent data)
      (prevProps.dataPoints.length === 0 ||
        nextProps.dataPoints.length === 0 ||
        prevProps.dataPoints[prevProps.dataPoints.length - 1] ===
          nextProps.dataPoints[nextProps.dataPoints.length - 1])
    );
  }
);

/**
 * Individual stat item component - memoized for performance.
 */
const StatItem = React.memo(function StatItem({
  label,
  value,
}: {
  label: string;
  value: string;
}) {
  const theme = useTheme();

  return (
    <View style={styles.statItem}>
      <Text
        style={[
          styles.statLabel,
          theme.typography.labelSmall,
          { color: theme.colors.onSurfaceVariant },
        ]}
      >
        {label}
      </Text>
      <Text
        style={[
          styles.statValue,
          theme.typography.labelMedium,
          { color: theme.colors.onSurface },
        ]}
      >
        {value}
      </Text>
    </View>
  );
});

// Create styles with theme - memoized in component
function createStyles(theme: Theme) {
  return StyleSheet.create({
    container: {
      padding: theme.spacing.md,
    },
    header: {
      marginBottom: theme.spacing.md,
    },
    title: {
      marginBottom: theme.spacing.md,
    },
    stats: {
      flexDirection: 'row',
      justifyContent: 'space-around',
    },
    statItem: {
      alignItems: 'center',
    },
    statLabel: {
      marginBottom: theme.spacing.xs,
    },
    statValue: {},
    chart: {
      borderRadius: theme.borderRadius.lg,
    },
  });
}

export default UsageChart;
