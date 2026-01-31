/**
 * @file SettingsScreen.tsx
 * @description Settings screen for configuring app preferences.
 * Includes theme, notifications, sync, and privacy settings.
 */

import React, { useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Switch,
  TouchableOpacity,
} from 'react-native';
import { useTheme } from '../hooks';
import { useAppStore } from '../stores';
import type { ThemeMode } from '../types';

/**
 * Settings screen component for app configuration.
 * Organized into sections for different setting categories.
 *
 * @example
 * <SettingsScreen />
 */
export function SettingsScreen() {
  const theme = useTheme();
  const { settings, updateSettings, setThemeMode, resetSettings } = useAppStore();

  // Theme setting handlers
  const handleThemeChange = useCallback(
    (mode: ThemeMode) => {
      setThemeMode(mode);
    },
    [setThemeMode]
  );

  const handleMaterialYouToggle = useCallback(
    (value: boolean) => {
      updateSettings({
        theme: { ...settings.theme, useMaterialYou: value },
      });
    },
    [settings.theme, updateSettings]
  );

  // Notification setting handlers
  const handleNotificationToggle = useCallback(
    (key: keyof typeof settings.notifications, value: boolean) => {
      updateSettings({
        notifications: { ...settings.notifications, [key]: value },
      });
    },
    [settings.notifications, updateSettings]
  );

  // Sync setting handlers
  const handleSyncToggle = useCallback(
    (key: keyof typeof settings.sync, value: boolean) => {
      updateSettings({
        sync: { ...settings.sync, [key]: value },
      });
    },
    [settings.sync, updateSettings]
  );

  // Privacy setting handlers
  const handlePrivacyToggle = useCallback(
    (key: keyof typeof settings.privacy, value: boolean) => {
      updateSettings({
        privacy: { ...settings.privacy, [key]: value },
      });
    },
    [settings.privacy, updateSettings]
  );

  return (
    <View style={[styles.container, { backgroundColor: theme.colors.background }]}>
      {/* Header */}
      <View
        style={[
          styles.header,
          { backgroundColor: theme.colors.surface },
          theme.elevation.level1,
        ]}
      >
        <Text
          style={[
            styles.title,
            theme.typography.headlineMedium,
            { color: theme.colors.onSurface },
          ]}
        >
          Settings
        </Text>
      </View>

      <ScrollView
        style={styles.scrollView}
        contentContainerStyle={styles.scrollContent}
      >
        {/* Theme Section */}
        <SettingsSection title="Theme">
          <SettingsRow label="Theme Mode">
            <View style={styles.themeOptions}>
              <ThemeButton
                label="Light"
                isSelected={settings.theme.mode === 'light'}
                onPress={() => handleThemeChange('light')}
              />
              <ThemeButton
                label="Dark"
                isSelected={settings.theme.mode === 'dark'}
                onPress={() => handleThemeChange('dark')}
              />
              <ThemeButton
                label="Auto"
                isSelected={settings.theme.mode === 'auto'}
                onPress={() => handleThemeChange('auto')}
              />
            </View>
          </SettingsRow>

          <SettingsRow
            label="Material You (Android)"
            description="Use dynamic colors from your wallpaper"
          >
            <Switch
              value={settings.theme.useMaterialYou}
              onValueChange={handleMaterialYouToggle}
              trackColor={{
                true: theme.colors.primary,
                false: theme.colors.surfaceVariant,
              }}
              thumbColor={theme.colors.surface}
            />
          </SettingsRow>
        </SettingsSection>

        {/* Notifications Section */}
        <SettingsSection title="Notifications">
          <SettingsRow
            label="Enable Notifications"
            description="Receive alerts and updates"
          >
            <Switch
              value={settings.notifications.enabled}
              onValueChange={(v) => handleNotificationToggle('enabled', v)}
              trackColor={{
                true: theme.colors.primary,
                false: theme.colors.surfaceVariant,
              }}
              thumbColor={theme.colors.surface}
            />
          </SettingsRow>

          <SettingsRow
            label="Quota Warnings"
            description="Alert when quota reaches threshold"
          >
            <Switch
              value={settings.notifications.quotaWarnings}
              onValueChange={(v) => handleNotificationToggle('quotaWarnings', v)}
              disabled={!settings.notifications.enabled}
              trackColor={{
                true: theme.colors.primary,
                false: theme.colors.surfaceVariant,
              }}
              thumbColor={theme.colors.surface}
            />
          </SettingsRow>

          <SettingsRow
            label="Sync Errors"
            description="Notify on synchronization failures"
          >
            <Switch
              value={settings.notifications.syncErrors}
              onValueChange={(v) => handleNotificationToggle('syncErrors', v)}
              disabled={!settings.notifications.enabled}
              trackColor={{
                true: theme.colors.primary,
                false: theme.colors.surfaceVariant,
              }}
              thumbColor={theme.colors.surface}
            />
          </SettingsRow>

          <SettingsRow
            label="Daily Summaries"
            description="Receive daily usage reports"
          >
            <Switch
              value={settings.notifications.dailySummaries}
              onValueChange={(v) => handleNotificationToggle('dailySummaries', v)}
              disabled={!settings.notifications.enabled}
              trackColor={{
                true: theme.colors.primary,
                false: theme.colors.surfaceVariant,
              }}
              thumbColor={theme.colors.surface}
            />
          </SettingsRow>
        </SettingsSection>

        {/* Sync Section */}
        <SettingsSection title="Data & Sync">
          <SettingsRow
            label="Auto Sync"
            description="Automatically sync provider data"
          >
            <Switch
              value={settings.sync.autoSync}
              onValueChange={(v) => handleSyncToggle('autoSync', v)}
              trackColor={{
                true: theme.colors.primary,
                false: theme.colors.surfaceVariant,
              }}
              thumbColor={theme.colors.surface}
            />
          </SettingsRow>

          <SettingsRow
            label="Sync on Launch"
            description="Sync data when app starts"
          >
            <Switch
              value={settings.sync.syncOnLaunch}
              onValueChange={(v) => handleSyncToggle('syncOnLaunch', v)}
              trackColor={{
                true: theme.colors.primary,
                false: theme.colors.surfaceVariant,
              }}
              thumbColor={theme.colors.surface}
            />
          </SettingsRow>

          <SettingsRow
            label="Offline Mode"
            description="Use cached data when offline"
          >
            <Switch
              value={settings.sync.offlineMode}
              onValueChange={(v) => handleSyncToggle('offlineMode', v)}
              trackColor={{
                true: theme.colors.primary,
                false: theme.colors.surfaceVariant,
              }}
              thumbColor={theme.colors.surface}
            />
          </SettingsRow>
        </SettingsSection>

        {/* Privacy Section */}
        <SettingsSection title="Privacy">
          <SettingsRow
            label="Analytics"
            description="Help improve the app with usage data"
          >
            <Switch
              value={settings.privacy.analytics}
              onValueChange={(v) => handlePrivacyToggle('analytics', v)}
              trackColor={{
                true: theme.colors.primary,
                false: theme.colors.surfaceVariant,
              }}
              thumbColor={theme.colors.surface}
            />
          </SettingsRow>

          <SettingsRow
            label="Crash Reporting"
            description="Send crash reports to developers"
          >
            <Switch
              value={settings.privacy.crashReporting}
              onValueChange={(v) => handlePrivacyToggle('crashReporting', v)}
              trackColor={{
                true: theme.colors.primary,
                false: theme.colors.surfaceVariant,
              }}
              thumbColor={theme.colors.surface}
            />
          </SettingsRow>

          <SettingsRow
            label="Encrypt Credentials"
            description="Secure API tokens with encryption"
          >
            <Switch
              value={settings.privacy.encryptCredentials}
              onValueChange={(v) => handlePrivacyToggle('encryptCredentials', v)}
              trackColor={{
                true: theme.colors.primary,
                false: theme.colors.surfaceVariant,
              }}
              thumbColor={theme.colors.surface}
            />
          </SettingsRow>
        </SettingsSection>

        {/* Reset Section */}
        <TouchableOpacity
          style={[
            styles.resetButton,
            { backgroundColor: theme.colors.errorContainer },
          ]}
          onPress={resetSettings}
        >
          <Text
            style={[
              styles.resetButtonText,
              theme.typography.labelLarge,
              { color: theme.colors.onErrorContainer },
            ]}
          >
            Reset to Defaults
          </Text>
        </TouchableOpacity>
      </ScrollView>
    </View>
  );
}

/**
 * Settings section component with title.
 */
function SettingsSection({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  const theme = useTheme();

  return (
    <View style={styles.section}>
      <Text
        style={[
          styles.sectionTitle,
          theme.typography.titleSmall,
          { color: theme.colors.primary },
        ]}
      >
        {title}
      </Text>
      <View
        style={[
          styles.sectionContent,
          { backgroundColor: theme.colors.surface },
          theme.elevation.level1,
        ]}
      >
        {children}
      </View>
    </View>
  );
}

/**
 * Individual settings row component.
 */
function SettingsRow({
  label,
  description,
  children,
}: {
  label: string;
  description?: string;
  children: React.ReactNode;
}) {
  const theme = useTheme();

  return (
    <View style={styles.settingsRow}>
      <View style={styles.settingsRowText}>
        <Text
          style={[
            styles.settingsLabel,
            theme.typography.bodyLarge,
            { color: theme.colors.onSurface },
          ]}
        >
          {label}
        </Text>
        {description && (
          <Text
            style={[
              styles.settingsDescription,
              theme.typography.bodySmall,
              { color: theme.colors.onSurfaceVariant },
            ]}
          >
            {description}
          </Text>
        )}
      </View>
      {children}
    </View>
  );
}

/**
 * Theme selection button.
 */
function ThemeButton({
  label,
  isSelected,
  onPress,
}: {
  label: string;
  isSelected: boolean;
  onPress: () => void;
}) {
  const theme = useTheme();

  return (
    <TouchableOpacity
      style={[
        styles.themeButton,
        {
          backgroundColor: isSelected
            ? theme.colors.primary
            : theme.colors.surfaceVariant,
        },
      ]}
      onPress={onPress}
    >
      <Text
        style={[
          styles.themeButtonText,
          theme.typography.labelMedium,
          {
            color: isSelected
              ? theme.colors.onPrimary
              : theme.colors.onSurfaceVariant,
          },
        ]}
      >
        {label}
      </Text>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    padding: 16,
    paddingTop: 48,
  },
  title: {},
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    padding: 16,
  },
  section: {
    marginBottom: 24,
  },
  sectionTitle: {
    marginBottom: 8,
    paddingHorizontal: 4,
  },
  sectionContent: {
    borderRadius: 12,
    overflow: 'hidden',
  },
  settingsRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: 16,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#e0e0e0',
  },
  settingsRowText: {
    flex: 1,
    marginRight: 16,
  },
  settingsLabel: {},
  settingsDescription: {
    marginTop: 2,
  },
  themeOptions: {
    flexDirection: 'row',
    gap: 8,
  },
  themeButton: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 16,
  },
  themeButtonText: {},
  resetButton: {
    padding: 16,
    borderRadius: 12,
    alignItems: 'center',
    marginTop: 16,
  },
  resetButtonText: {},
});

export default SettingsScreen;
