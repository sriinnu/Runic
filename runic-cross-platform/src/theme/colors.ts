/**
 * @file colors.ts
 * @description Color palette definitions for light and dark themes.
 * Supports Material You dynamic theming on Android 12+.
 */

/**
 * Light theme color palette
 */
export const lightColors = {
  // Primary colors
  primary: '#6200EE',
  primaryVariant: '#3700B3',
  primaryContainer: '#E8DEF8',
  onPrimary: '#FFFFFF',
  onPrimaryContainer: '#21005D',

  // Secondary colors
  secondary: '#03DAC6',
  secondaryVariant: '#018786',
  secondaryContainer: '#B2F2EE',
  onSecondary: '#000000',
  onSecondaryContainer: '#002020',

  // Background colors
  background: '#FFFBFE',
  surface: '#FFFBFE',
  surfaceVariant: '#E7E0EC',
  onBackground: '#1C1B1F',
  onSurface: '#1C1B1F',
  onSurfaceVariant: '#49454F',

  // Error colors
  error: '#B3261E',
  errorContainer: '#F9DEDC',
  onError: '#FFFFFF',
  onErrorContainer: '#410E0B',

  // Utility colors
  outline: '#79747E',
  outlineVariant: '#CAC4D0',
  shadow: '#000000',
  scrim: '#000000',
  inverseSurface: '#313033',
  inverseOnSurface: '#F4EFF4',
  inversePrimary: '#D0BCFF',

  // Chart colors
  chartColors: ['#6200EE', '#03DAC6', '#FF6F00', '#C51162', '#00C853'],
} as const;

/**
 * Dark theme color palette
 */
export const darkColors = {
  // Primary colors
  primary: '#D0BCFF',
  primaryVariant: '#985EFF',
  primaryContainer: '#4F378B',
  onPrimary: '#381E72',
  onPrimaryContainer: '#EADDFF',

  // Secondary colors
  secondary: '#66FFF9',
  secondaryVariant: '#03DAC6',
  secondaryContainer: '#004D4D',
  onSecondary: '#003737',
  onSecondaryContainer: '#B2F2EE',

  // Background colors
  background: '#1C1B1F',
  surface: '#1C1B1F',
  surfaceVariant: '#49454F',
  onBackground: '#E6E1E5',
  onSurface: '#E6E1E5',
  onSurfaceVariant: '#CAC4D0',

  // Error colors
  error: '#F2B8B5',
  errorContainer: '#8C1D18',
  onError: '#601410',
  onErrorContainer: '#F9DEDC',

  // Utility colors
  outline: '#938F99',
  outlineVariant: '#49454F',
  shadow: '#000000',
  scrim: '#000000',
  inverseSurface: '#E6E1E5',
  inverseOnSurface: '#313033',
  inversePrimary: '#6750A4',

  // Chart colors
  chartColors: ['#D0BCFF', '#66FFF9', '#FFB74D', '#F48FB1', '#81C784'],
} as const;

/**
 * Provider brand colors for consistent UI theming
 */
export const providerColors = {
  openai: '#10A37F',
  anthropic: '#D4816E',
  google: '#4285F4',
  mistral: '#F2A900',
  cohere: '#39594D',
  minimax: '#FF6B6B',
  groq: '#FF6F00',
  openrouter: '#8B5CF6',
} as const;

/**
 * Status colors for alerts and notifications
 */
export const statusColors = {
  success: '#00C853',
  warning: '#FFB300',
  error: '#D32F2F',
  info: '#2196F3',
} as const;

/**
 * Type definitions for color objects
 */
export type LightColors = typeof lightColors;
export type DarkColors = typeof darkColors;
export type ProviderColors = typeof providerColors;
export type StatusColors = typeof statusColors;
