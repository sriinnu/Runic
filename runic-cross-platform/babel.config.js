/**
 * @file babel.config.js
 * @description Babel configuration for React Native transpilation.
 * Includes path aliases and Reanimated plugin.
 */

module.exports = {
  presets: ['module:@react-native/babel-preset'],
  plugins: [
    [
      'module-resolver',
      {
        root: ['./src'],
        extensions: ['.ios.js', '.android.js', '.js', '.ts', '.tsx', '.json'],
        alias: {
          '@components': './src/components',
          '@screens': './src/screens',
          '@services': './src/services',
          '@stores': './src/stores',
          '@types': './src/types',
          '@hooks': './src/hooks',
          '@utils': './src/utils',
          '@theme': './src/theme',
        },
      },
    ],
    'react-native-reanimated/plugin', // Must be last
  ],
};
