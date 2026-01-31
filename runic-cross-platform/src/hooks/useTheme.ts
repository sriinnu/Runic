/**
 * @file useTheme.ts
 * @description Custom hook for accessing and managing theme state.
 * Provides theme colors and utilities based on current theme mode.
 */

import { useMemo } from 'react';
import { useColorScheme } from 'react-native';
import { useAppStore } from '../stores';
import { lightTheme, darkTheme, type Theme } from '../theme';

/**
 * Hook for accessing theme based on app settings and system preferences.
 * Automatically switches between light and dark themes.
 *
 * @returns Current theme object with colors, typography, and spacing
 *
 * @example
 * const theme = useTheme();
 * <View style={{ backgroundColor: theme.colors.background }}>
 *   <Text style={theme.typography.titleLarge}>Hello</Text>
 * </View>
 */
export function useTheme(): Theme {
  const { settings } = useAppStore();
  const systemColorScheme = useColorScheme();

  const theme = useMemo(() => {
    const { mode } = settings.theme;

    // Determine if dark mode should be active
    const isDark =
      mode === 'dark' || (mode === 'auto' && systemColorScheme === 'dark');

    return isDark ? darkTheme : lightTheme;
  }, [settings.theme.mode, systemColorScheme]);

  return theme;
}

/**
 * Hook that returns only the current theme colors.
 * Lighter alternative to useTheme when only colors are needed.
 *
 * @returns Current theme colors
 *
 * @example
 * const colors = useThemeColors();
 * <View style={{ backgroundColor: colors.surface }}>
 */
export function useThemeColors() {
  const theme = useTheme();
  return theme.colors;
}

/**
 * Hook that returns whether dark mode is currently active.
 *
 * @returns True if dark mode is active
 *
 * @example
 * const isDark = useIsDarkMode();
 * const iconColor = isDark ? '#fff' : '#000';
 */
export function useIsDarkMode(): boolean {
  const theme = useTheme();
  return theme.isDark;
}

export default useTheme;
