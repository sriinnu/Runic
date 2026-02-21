/**
 * @file SkeletonView.tsx
 * @description Skeleton loading component with shimmer animation.
 * Provides professional loading states matching Material Design guidelines.
 */

import React, { useEffect, useRef } from 'react';
import {
  View,
  StyleSheet,
  Animated,
  ViewStyle,
  Easing,
} from 'react-native';
import LinearGradient from 'react-native-linear-gradient';
import { useTheme } from '../hooks';

/**
 * Props for SkeletonView component
 */
interface SkeletonViewProps {
  /** Width of the skeleton (number or string percentage) */
  width?: number | string;
  /** Height of the skeleton */
  height?: number;
  /** Border radius */
  borderRadius?: number;
  /** Custom style */
  style?: ViewStyle;
}

/**
 * Animated skeleton view with shimmer effect.
 * Used to indicate loading state while preserving layout.
 *
 * @example
 * <SkeletonView width={100} height={20} />
 * <SkeletonView width="100%" height={40} borderRadius={8} />
 */
export function SkeletonView({
  width = '100%',
  height = 20,
  borderRadius = 4,
  style,
}: SkeletonViewProps) {
  const theme = useTheme();
  const shimmerPosition = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    // Start shimmer animation
    const shimmerAnimation = Animated.loop(
      Animated.timing(shimmerPosition, {
        toValue: 1,
        duration: 1500,
        easing: Easing.linear,
        useNativeDriver: true,
      })
    );

    shimmerAnimation.start();

    return () => shimmerAnimation.stop();
  }, []);

  // Interpolate position for shimmer effect
  const translateX = shimmerPosition.interpolate({
    inputRange: [0, 1],
    outputRange: [-300, 300],
  });

  const baseColor = theme.colors.surfaceVariant;
  const highlightColor = theme.colors.surface;

  return (
    <View
      style={[
        styles.skeleton,
        {
          width,
          height,
          borderRadius,
          backgroundColor: baseColor,
          overflow: 'hidden',
        },
        style,
      ]}
    >
      <Animated.View
        style={[
          styles.shimmer,
          {
            transform: [{ translateX }, { rotate: '45deg' }],
          },
        ]}
      >
        <LinearGradient
          colors={[
            'transparent',
            highlightColor + 'CC',
            highlightColor,
            highlightColor + 'CC',
            'transparent',
          ]}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 0 }}
          style={styles.gradient}
        />
      </Animated.View>
    </View>
  );
}

/**
 * Props for SkeletonCard component
 */
interface SkeletonCardProps {
  /** Custom style */
  style?: ViewStyle;
}

/**
 * Skeleton card that matches ProviderCard layout.
 * Shows loading state while provider data is being fetched.
 *
 * @example
 * <SkeletonCard />
 */
export function SkeletonCard({ style }: SkeletonCardProps) {
  const theme = useTheme();

  return (
    <View
      style={[
        styles.card,
        {
          backgroundColor: theme.colors.surface,
          borderColor: theme.colors.outline,
        },
        theme.elevation.level2,
        style,
      ]}
    >
      {/* Header skeleton */}
      <View style={styles.header}>
        <SkeletonView width={48} height={48} borderRadius={24} />
        <View style={styles.headerText}>
          <SkeletonView width={120} height={16} style={{ marginBottom: 6 }} />
          <SkeletonView width={80} height={12} />
        </View>
      </View>

      {/* Quota section skeleton */}
      <View style={styles.quotaSection}>
        <View style={styles.quotaHeader}>
          <SkeletonView width={80} height={12} />
          <SkeletonView width={50} height={12} />
        </View>
        <SkeletonView width="100%" height={6} borderRadius={3} />
      </View>

      {/* Footer skeleton */}
      <View style={styles.footer}>
        <View style={styles.footerItem}>
          <SkeletonView width={70} height={12} style={{ marginBottom: 6 }} />
          <SkeletonView width={60} height={18} />
        </View>
        <View style={styles.footerItem}>
          <SkeletonView width={70} height={12} style={{ marginBottom: 6 }} />
          <SkeletonView width={80} height={18} />
        </View>
      </View>
    </View>
  );
}

/**
 * Loading state type for managing async data.
 */
export type LoadingState<T> =
  | { type: 'idle' }
  | { type: 'loading' }
  | { type: 'loaded'; data: T }
  | { type: 'failed'; error: Error };

/**
 * Helper to create loading states
 */
export const LoadingStateHelpers = {
  idle: <T,>(): LoadingState<T> => ({ type: 'idle' }),
  loading: <T,>(): LoadingState<T> => ({ type: 'loading' }),
  loaded: <T,>(data: T): LoadingState<T> => ({ type: 'loaded', data }),
  failed: <T,>(error: Error): LoadingState<T> => ({ type: 'failed', error }),

  isLoading: <T,>(state: LoadingState<T>): boolean => state.type === 'loading',
  isLoaded: <T,>(state: LoadingState<T>): boolean => state.type === 'loaded',
  isFailed: <T,>(state: LoadingState<T>): boolean => state.type === 'failed',

  getData: <T,>(state: LoadingState<T>): T | undefined =>
    state.type === 'loaded' ? state.data : undefined,

  getError: <T,>(state: LoadingState<T>): Error | undefined =>
    state.type === 'failed' ? state.error : undefined,
};

const styles = StyleSheet.create({
  skeleton: {
    overflow: 'hidden',
  },
  shimmer: {
    width: 300,
    height: '100%',
    position: 'absolute',
  },
  gradient: {
    width: '100%',
    height: '100%',
  },
  card: {
    borderRadius: 12,
    padding: 16,
    borderWidth: 1,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 16,
  },
  headerText: {
    flex: 1,
    marginLeft: 12,
  },
  quotaSection: {
    marginBottom: 16,
  },
  quotaHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 8,
  },
  footer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  footerItem: {
    flex: 1,
  },
});

export default SkeletonView;
