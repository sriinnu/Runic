/**
 * @file index.js
 * @description Entry point for React Native application.
 * Registers the main App component.
 */

import { AppRegistry } from 'react-native';
import App from './App';
import { name as appName } from './package.json';

AppRegistry.registerComponent(appName, () => App);
