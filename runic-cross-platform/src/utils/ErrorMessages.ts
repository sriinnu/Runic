/**
 * @file ErrorMessages.ts
 * @description Structured error messages with actionable guidance.
 */

import { ErrorCode } from './ErrorCodes';

/**
 * Structured error message matching Swift implementation
 */
export interface ErrorMessage {
  /** Short error title */
  title: string;
  /** Specific reason for the error */
  reason: string;
  /** Ordered list of actions user can take */
  steps: string[];
  /** Error code for support/debugging */
  code: ErrorCode;
  /** Whether this error is retryable */
  retryable: boolean;
  /** Optional provider name for context */
  providerName?: string;
}

/**
 * Creates full error description formatted for display
 */
export function getFullErrorDescription(error: ErrorMessage): string {
  const parts: string[] = [];

  if (error.providerName) {
    parts.push(`${error.title} [${error.providerName}]`);
  } else {
    parts.push(error.title);
  }

  parts.push(`\nReason: ${error.reason}`);

  if (error.steps.length > 0) {
    parts.push('\nNext Steps:');
    error.steps.forEach((step, index) => {
      parts.push(`${index + 1}. ${step}`);
    });
  }

  if (!error.retryable) {
    parts.push('\nNote: This error cannot be retried automatically');
  }

  parts.push(`\nError Code: ${error.code}`);

  return parts.join('\n');
}

/**
 * Creates compact description for UI display
 */
export function getCompactErrorDescription(error: ErrorMessage): string {
  let desc = error.reason;
  if (error.steps.length > 0) {
    desc += ` · ${error.steps[0]}`;
  }
  return desc;
}

/**
 * Error message builder with convenience methods
 */
export class ErrorMessageBuilder {
  /**
   * Creates network error message
   */
  static networkError(options: {
    provider?: string;
    reason?: string;
    timeout?: boolean;
  } = {}): ErrorMessage {
    const { provider, reason, timeout = false } = options;

    const defaultReason = timeout
      ? 'Request timed out after 30 seconds'
      : 'Network connection lost or unavailable';

    return {
      title: provider
        ? `Unable to sync with ${provider} API`
        : 'Network connection failed',
      reason: reason || defaultReason,
      steps: [
        'Check your internet connection',
        'Verify the API endpoint is accessible',
        'Try again in a few moments',
        'Check if your firewall is blocking the connection',
      ],
      code: timeout ? ErrorCode.NET_003 : ErrorCode.NET_001,
      retryable: true,
      providerName: provider,
    };
  }

  /**
   * Creates authentication error message
   */
  static authenticationError(options: {
    provider: string;
    reason: string;
    expired?: boolean;
  }): ErrorMessage {
    const { provider, reason, expired = false } = options;

    const code = expired ? ErrorCode.AUTH_003 : ErrorCode.AUTH_001;

    const steps = [
      'Verify your API credentials are correct',
      'Check if your API key is active',
      `Contact ${provider} support if the issue persists`,
    ];

    if (expired) {
      steps.unshift('Refresh your authentication token');
    }

    return {
      title: `Authentication failed for ${provider}`,
      reason,
      steps,
      code,
      retryable: false,
      providerName: provider,
    };
  }

  /**
   * Creates rate limit error message
   */
  static rateLimitError(options: {
    provider: string;
    retryAfter?: Date;
  }): ErrorMessage {
    const { provider, retryAfter } = options;

    const steps = ['Wait a few moments before trying again'];

    if (retryAfter) {
      const timeStr = retryAfter.toLocaleTimeString([], {
        hour: '2-digit',
        minute: '2-digit',
      });
      steps[0] = `Rate limit resets at ${timeStr}`;
    }

    steps.push(
      'Reduce your request frequency',
      `Check your ${provider} plan limits`,
      'Consider upgrading your plan for higher limits'
    );

    return {
      title: 'Rate limit exceeded',
      reason: `${provider} API rate limit exceeded`,
      steps,
      code: ErrorCode.RATE_001,
      retryable: true,
      providerName: provider,
    };
  }

  /**
   * Creates API error message
   */
  static apiError(options: {
    provider: string;
    statusCode: number;
    details?: string;
  }): ErrorMessage {
    const { provider, statusCode, details } = options;

    let reason: string;
    let code: ErrorCode;

    switch (statusCode) {
      case 404:
        reason = 'API endpoint not found (HTTP 404)';
        code = ErrorCode.API_002;
        break;
      case 500:
      case 502:
      case 503:
      case 504:
        reason = `${provider} server error (HTTP ${statusCode})`;
        code = ErrorCode.API_003;
        break;
      default:
        reason = details || `API request failed (HTTP ${statusCode})`;
        code = ErrorCode.API_001;
    }

    return {
      title: `API error from ${provider}`,
      reason,
      steps: [
        'Wait a few moments and try again',
        `Check ${provider} status page for outages`,
        'Verify your API endpoint configuration',
        'Contact support with error code if issue persists',
      ],
      code,
      retryable: statusCode >= 500,
      providerName: provider,
    };
  }

  /**
   * Creates parsing error message
   */
  static parsingError(options: {
    provider: string;
    field?: string;
  }): ErrorMessage {
    const { provider, field } = options;

    const reason = field
      ? `Failed to parse ${provider} response: missing or invalid field '${field}'`
      : `Failed to parse ${provider} API response`;

    return {
      title: 'Data parsing failed',
      reason,
      steps: [
        `${provider} may have updated their API format`,
        'Try updating Runic to the latest version',
        'Report this issue if it persists',
      ],
      code: ErrorCode.PARSE_001,
      retryable: false,
      providerName: provider,
    };
  }

  /**
   * Creates storage error message
   */
  static storageError(options: {
    operation: 'read' | 'write';
    reason?: string;
  }): ErrorMessage {
    const { operation, reason } = options;

    const code = operation === 'read' ? ErrorCode.STORE_001 : ErrorCode.STORE_002;
    const defaultReason =
      operation === 'read'
        ? 'Failed to read data from storage'
        : 'Failed to write data to storage';

    return {
      title: 'Storage operation failed',
      reason: reason || defaultReason,
      steps: [
        'Check available storage space',
        'Ensure app has storage permissions',
        'Try restarting the app',
        'Clear app cache if issue persists',
      ],
      code,
      retryable: operation === 'write',
    };
  }

  /**
   * Creates sync error message
   */
  static syncError(options: {
    provider: string;
    reason?: string;
  }): ErrorMessage {
    const { provider, reason } = options;

    return {
      title: `Sync failed for ${provider}`,
      reason: reason || 'Failed to synchronize provider data',
      steps: [
        'Check your internet connection',
        'Verify API credentials are valid',
        'Try refreshing manually',
        'Check provider service status',
      ],
      code: ErrorCode.SYNC_001,
      retryable: true,
      providerName: provider,
    };
  }

  /**
   * Creates generic error message
   */
  static genericError(options: {
    title: string;
    reason: string;
    steps: string[];
    code?: ErrorCode;
    retryable?: boolean;
    provider?: string;
  }): ErrorMessage {
    const {
      title,
      reason,
      steps,
      code = ErrorCode.API_001,
      retryable = true,
      provider,
    } = options;

    return {
      title,
      reason,
      steps,
      code,
      retryable,
      providerName: provider,
    };
  }
}
