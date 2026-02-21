/**
 * @file LoadingButton.tsx
 * @description Button component with loading state support.
 * Shows activity indicator and disables interaction while loading.
 */

import React from 'react';
import {
  TouchableOpacity,
  Text,
  StyleSheet,
  ActivityIndicator,
  View,
  ViewStyle,
  TextStyle,
} from 'react-native';
import { useTheme } from '../hooks';

/**
 * Props for LoadingButton component
 */
interface LoadingButtonProps {
  /** Button text label */
  label: string;
  /** Callback when button is pressed */
  onPress: () => void;
  /** Whether button is in loading state */
  isLoading?: boolean;
  /** Whether button is disabled */
  disabled?: boolean;
  /** Button variant */
  variant?: 'primary' | 'secondary' | 'text';
  /** Custom button style */
  style?: ViewStyle;
  /** Custom text style */
  textStyle?: TextStyle;
  /** Loading message (replaces label when loading) */
  loadingLabel?: string;
}

/**
 * Button component with built-in loading state.
 * Automatically shows activity indicator and prevents interaction while loading.
 *
 * @example
 * <LoadingButton
 *   label="Sync Now"
 *   onPress={handleSync}
 *   isLoading={isSyncing}
 *   loadingLabel="Syncing..."
 * />
 */
export function LoadingButton({
  label,
  onPress,
  isLoading = false,
  disabled = false,
  variant = 'primary',
  style,
  textStyle,
  loadingLabel,
}: LoadingButtonProps) {
  const theme = useTheme();
  const isDisabled = disabled || isLoading;

  // Get button colors based on variant
  const getButtonColors = () => {
    switch (variant) {
      case 'primary':
        return {
          backgroundColor: isDisabled
            ? theme.colors.surfaceVariant
            : theme.colors.primary,
          textColor: isDisabled
            ? theme.colors.onSurfaceVariant
            : theme.colors.onPrimary,
        };
      case 'secondary':
        return {
          backgroundColor: isDisabled
            ? theme.colors.surfaceVariant
            : theme.colors.secondaryContainer,
          textColor: isDisabled
            ? theme.colors.onSurfaceVariant
            : theme.colors.onSecondaryContainer,
        };
      case 'text':
        return {
          backgroundColor: 'transparent',
          textColor: isDisabled
            ? theme.colors.onSurfaceVariant
            : theme.colors.primary,
        };
    }
  };

  const { backgroundColor, textColor } = getButtonColors();
  const displayLabel = isLoading && loadingLabel ? loadingLabel : label;

  return (
    <TouchableOpacity
      style={[
        styles.button,
        { backgroundColor },
        variant === 'text' && styles.textButton,
        style,
      ]}
      onPress={onPress}
      disabled={isDisabled}
      activeOpacity={0.7}
    >
      <View style={styles.content}>
        {isLoading && (
          <ActivityIndicator
            size="small"
            color={textColor}
            style={styles.spinner}
          />
        )}
        <Text
          style={[
            styles.label,
            theme.typography.labelLarge,
            { color: textColor },
            textStyle,
          ]}
        >
          {displayLabel}
        </Text>
      </View>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  button: {
    borderRadius: 20,
    paddingHorizontal: 24,
    paddingVertical: 12,
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: 48,
  },
  textButton: {
    paddingHorizontal: 12,
  },
  content: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
  },
  spinner: {
    marginRight: 8,
  },
  label: {
    fontWeight: '600',
  },
});

export default LoadingButton;
