/**
 * @file metro.config.js
 * @description Metro bundler configuration for React Native.
 * Supports Windows, Android, and iOS platforms.
 */

const { getDefaultConfig, mergeConfig } = require('@react-native/metro-config');

/**
 * Metro configuration object.
 * @type {import('metro-config').MetroConfig}
 */
const config = {
  transformer: {
    getTransformOptions: async () => ({
      transform: {
        experimentalImportSupport: false,
        inlineRequires: true,
      },
    }),
  },
  resolver: {
    // Support for .windows.js extensions
    sourceExts: ['js', 'jsx', 'ts', 'tsx', 'json'],
    platforms: ['android', 'ios', 'windows'],
  },
};

module.exports = mergeConfig(getDefaultConfig(__dirname), config);
