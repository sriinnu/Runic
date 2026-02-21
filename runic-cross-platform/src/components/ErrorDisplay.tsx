/**
 * @file ErrorDisplay.tsx
 * @description Component for displaying detailed error information with retry capability.
 */

import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Animated,
  Clipboard,
} from 'react-native';
import { useTheme } from '../hooks';
import type { ErrorMessage } from '../utils/ErrorMessages';
import { getFullErrorDescription } from '../utils/ErrorMessages';

/**
 * Props for ErrorDisplay component
 */
interface ErrorDisplayProps {
  /** Structured error message */
  error: ErrorMessage;
  /** Optional callback to retry the operation */
  onRetry?: () => void;
  /** Optional callback to dismiss the error */
  onDismiss?: () => void;
  /** Whether to show expanded view by default */
  defaultExpanded?: boolean;
}

/**
 * Displays comprehensive error information with expandable details
 *
 * @example
 * <ErrorDisplay
 *   error={errorMessage}
 *   onRetry={handleRetry}
 *   onDismiss={handleDismiss}
 * />
 */
export function ErrorDisplay({
  error,
  onRetry,
  onDismiss,
  defaultExpanded = false,
}: ErrorDisplayProps) {
  const theme = useTheme();
  const [isExpanded, setIsExpanded] = useState(defaultExpanded);
  const [copied, setCopied] = useState(false);

  const handleCopy = () => {
    const fullDescription = getFullErrorDescription(error);
    Clipboard.setString(fullDescription);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <View
      style={[
        styles.container,
        {
          backgroundColor: theme.colors.errorContainer + '20',
          borderLeftColor: theme.colors.error,
        },
      ]}
    >
      {/* Error Header */}
      <View style={styles.header}>
        <View style={styles.iconContainer}>
          <Text style={styles.icon}>⚠️</Text>
        </View>

        <View style={styles.headerContent}>
          <Text
            style={[
              styles.reason,
              theme.typography.bodyMedium,
              { color: theme.colors.error },
            ]}
          >
            {error.reason}
          </Text>

          <Text
            style={[
              styles.errorCode,
              theme.typography.labelSmall,
              { color: theme.colors.onSurface + '80' },
            ]}
          >
            Error: {error.code}
          </Text>
        </View>

        {/* Expand/Collapse Button */}
        <TouchableOpacity
          onPress={() => setIsExpanded(!isExpanded)}
          style={styles.expandButton}
          hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
        >
          <Text style={[styles.chevron, { color: theme.colors.onSurface }]}>
            {isExpanded ? '▲' : '▼'}
          </Text>
        </TouchableOpacity>
      </View>

      {/* Expanded Details */}
      {isExpanded && error.steps.length > 0 && (
        <View style={styles.details}>
          <Text
            style={[
              styles.stepsTitle,
              theme.typography.labelMedium,
              { color: theme.colors.onSurface },
            ]}
          >
            Next Steps:
          </Text>

          {error.steps.map((step, index) => (
            <View key={index} style={styles.step}>
              <Text
                style={[
                  styles.stepNumber,
                  theme.typography.bodySmall,
                  { color: theme.colors.onSurface + '80' },
                ]}
              >
                {index + 1}.
              </Text>
              <Text
                style={[
                  styles.stepText,
                  theme.typography.bodySmall,
                  { color: theme.colors.onSurface + '80' },
                ]}
              >
                {step}
              </Text>
            </View>
          ))}
        </View>
      )}

      {/* Action Buttons */}
      <View style={styles.actions}>
        {error.retryable && onRetry && (
          <TouchableOpacity
            onPress={onRetry}
            style={[
              styles.button,
              styles.retryButton,
              { backgroundColor: theme.colors.primary + '20' },
            ]}
          >
            <Text style={[styles.buttonText, { color: theme.colors.primary }]}>
              🔄 Retry
            </Text>
          </TouchableOpacity>
        )}

        <TouchableOpacity
          onPress={handleCopy}
          style={[
            styles.button,
            { backgroundColor: theme.colors.surfaceVariant },
          ]}
        >
          <Text
            style={[
              styles.buttonText,
              { color: theme.colors.onSurfaceVariant },
            ]}
          >
            {copied ? '✓ Copied' : '📋 Copy Error'}
          </Text>
        </TouchableOpacity>

        {onDismiss && (
          <TouchableOpacity
            onPress={onDismiss}
            style={[
              styles.button,
              { backgroundColor: theme.colors.surfaceVariant },
            ]}
          >
            <Text
              style={[
                styles.buttonText,
                { color: theme.colors.onSurfaceVariant },
              ]}
            >
              Dismiss
            </Text>
          </TouchableOpacity>
        )}
      </View>
    </View>
  );
}

/**
 * Compact error display for inline use
 */
interface CompactErrorDisplayProps {
  error: ErrorMessage;
  onRetry?: () => void;
}

export function CompactErrorDisplay({
  error,
  onRetry,
}: CompactErrorDisplayProps) {
  const theme = useTheme();

  return (
    <View style={styles.compactContainer}>
      <View style={styles.compactHeader}>
        <Text style={styles.compactIcon}>⚠️</Text>
        <View style={styles.compactContent}>
          <Text
            style={[
              styles.compactReason,
              theme.typography.bodySmall,
              { color: theme.colors.error },
            ]}
            numberOfLines={2}
          >
            {error.reason}
          </Text>

          {error.steps[0] && (
            <Text
              style={[
                styles.compactHint,
                theme.typography.labelSmall,
                { color: theme.colors.onSurface + '80' },
              ]}
              numberOfLines={1}
            >
              {error.steps[0]}
            </Text>
          )}

          <View style={styles.compactFooter}>
            {error.retryable && onRetry && (
              <TouchableOpacity onPress={onRetry}>
                <Text
                  style={[
                    theme.typography.labelSmall,
                    { color: theme.colors.primary },
                  ]}
                >
                  Retry
                </Text>
              </TouchableOpacity>
            )}

            <Text
              style={[
                theme.typography.labelSmall,
                { color: theme.colors.onSurface + '60', marginLeft: 12 },
              ]}
            >
              Code: {error.code}
            </Text>
          </View>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    borderRadius: 12,
    borderLeftWidth: 4,
    padding: 16,
    marginVertical: 8,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'flex-start',
  },
  iconContainer: {
    marginRight: 12,
  },
  icon: {
    fontSize: 24,
  },
  headerContent: {
    flex: 1,
  },
  reason: {
    marginBottom: 4,
  },
  errorCode: {
    marginTop: 4,
  },
  expandButton: {
    padding: 4,
    marginLeft: 8,
  },
  chevron: {
    fontSize: 12,
  },
  details: {
    marginTop: 16,
    marginLeft: 36,
  },
  stepsTitle: {
    marginBottom: 8,
    fontWeight: '600',
  },
  step: {
    flexDirection: 'row',
    marginTop: 6,
  },
  stepNumber: {
    marginRight: 8,
    minWidth: 20,
  },
  stepText: {
    flex: 1,
  },
  actions: {
    flexDirection: 'row',
    marginTop: 16,
    marginLeft: 36,
    gap: 8,
  },
  button: {
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 8,
  },
  retryButton: {
    marginRight: 8,
  },
  buttonText: {
    fontSize: 13,
    fontWeight: '600',
  },
  // Compact styles
  compactContainer: {
    paddingVertical: 8,
  },
  compactHeader: {
    flexDirection: 'row',
    alignItems: 'flex-start',
  },
  compactIcon: {
    fontSize: 16,
    marginRight: 8,
  },
  compactContent: {
    flex: 1,
  },
  compactReason: {
    marginBottom: 4,
  },
  compactHint: {
    marginBottom: 6,
  },
  compactFooter: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 4,
  },
});

export default ErrorDisplay;
