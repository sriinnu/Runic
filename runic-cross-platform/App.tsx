/**
 * @file App.tsx
 * @description Main application component with navigation setup.
 * Initializes services, configures navigation, and applies theme.
 */

import React, { useEffect } from 'react';
import { StatusBar } from 'react-native';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import { useTheme } from './src/hooks';
import { useAppStore, useProviderStore } from './src/stores';
import { notificationService } from './src/services';
import {
  HomeScreen,
  ProviderDetailScreen,
  SettingsScreen,
} from './src/screens';
import type { RootStackParamList } from './src/types';

const Stack = createNativeStackNavigator<RootStackParamList>();

/**
 * Main application component.
 * Sets up navigation, theme, and initializes services.
 *
 * @example
 * export default App;
 */
function App(): JSX.Element {
  const theme = useTheme();

  // Initialize stores
  const { initialize: initializeApp } = useAppStore();
  const { initialize: initializeProviders } = useProviderStore();

  // Initialize on mount
  useEffect(() => {
    // Initialize notification service
    notificationService.initialize();

    // Initialize stores
    initializeApp();
    initializeProviders();
  }, []);

  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <SafeAreaProvider>
        <StatusBar
          barStyle={theme.isDark ? 'light-content' : 'dark-content'}
          backgroundColor={theme.colors.background}
        />
        <NavigationContainer
          theme={{
            dark: theme.isDark,
            colors: {
              primary: theme.colors.primary,
              background: theme.colors.background,
              card: theme.colors.surface,
              text: theme.colors.onSurface,
              border: theme.colors.outline,
              notification: theme.colors.error,
            },
          }}
        >
          <Stack.Navigator
            screenOptions={{
              headerShown: false,
              animation: 'slide_from_right',
              contentStyle: {
                backgroundColor: theme.colors.background,
              },
            }}
          >
            <Stack.Screen name="Home" component={HomeScreen} />
            <Stack.Screen
              name="ProviderDetail"
              component={ProviderDetailScreen}
            />
            <Stack.Screen name="Settings" component={SettingsScreen} />
          </Stack.Navigator>
        </NavigationContainer>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}

export default App;
