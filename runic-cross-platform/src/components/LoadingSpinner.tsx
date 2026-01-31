/**
 * @file LoadingSpinner.tsx
 * @description Animated loading spinner component.
 * Provides visual feedback during async operations.
 */

import React, { useEffect, useRef } from 'react';
import { View, StyleSheet, Animated, Easing } from 'react-native';
import { useTheme } from '../hooks';

/**
 * Props for LoadingSpinner component
 */
interface LoadingSpinnerProps {
  /** Spinner size in pixels */
  size?: number;
  /** Custom color (defaults to theme primary) */
  color?: string;
}

/**
 * Animated loading spinner component.
 * Continuously rotates to indicate loading state.
 *
 * @example
 * <LoadingSpinner size={48} />
 */
export function LoadingSpinner({ size = 40, color }: LoadingSpinnerProps) {
  const theme = useTheme();
  const spinValue = useRef(new Animated.Value(0)).current;

  // Start rotation animation on mount
  useEffect(() => {
    const spinAnimation = Animated.loop(
      Animated.timing(spinValue, {
        toValue: 1,
        duration: 1000,
        easing: Easing.linear,
        useNativeDriver: true,
      })
    );

    spinAnimation.start();

    return () => spinAnimation.stop();
  }, []);

  // Interpolate rotation value
  const spin = spinValue.interpolate({
    inputRange: [0, 1],
    outputRange: ['0deg', '360deg'],
  });

  const spinnerColor = color || theme.colors.primary;

  return (
    <View style={[styles.container, { width: size, height: size }]}>
      <Animated.View
        style={[
          styles.spinner,
          {
            width: size,
            height: size,
            borderColor: spinnerColor + '30',
            borderTopColor: spinnerColor,
            borderWidth: size / 10,
            borderRadius: size / 2,
            transform: [{ rotate: spin }],
          },
        ]}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    justifyContent: 'center',
    alignItems: 'center',
  },
  spinner: {
    borderStyle: 'solid',
  },
});

export default LoadingSpinner;
