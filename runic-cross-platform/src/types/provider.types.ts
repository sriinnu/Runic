/**
 * @file provider.types.ts
 * @description Type definitions for AI provider data models and related structures.
 * Defines the core data types used throughout the application for provider management,
 * usage tracking, and billing information.
 */

/**
 * Supported AI provider platforms
 */
export type ProviderId =
  | 'openai'
  | 'anthropic'
  | 'google'
  | 'mistral'
  | 'cohere'
  | 'minimax'
  | 'groq'
  | 'openrouter';

/**
 * Provider operational status
 */
export type ProviderStatus = 'active' | 'inactive' | 'error' | 'limited';

/**
 * Billing cycle types
 */
export type BillingCycle = 'monthly' | 'yearly' | 'pay-as-you-go';

/**
 * Currency codes (ISO 4217)
 */
export type CurrencyCode = 'USD' | 'EUR' | 'GBP' | 'JPY' | 'CNY';

/**
 * Time period for usage data aggregation
 */
export type TimePeriod = 'hour' | 'day' | 'week' | 'month' | 'year' | 'all';

/**
 * Usage data point for time-series charts
 */
export interface UsageDataPoint {
  /** Timestamp of the data point */
  timestamp: number;
  /** Token count or API calls */
  value: number;
  /** Cost in the provider's currency */
  cost: number;
  /** Model or service identifier */
  modelId?: string;
}

/**
 * Usage statistics for a specific provider
 */
export interface UsageStats {
  /** Total tokens used */
  totalTokens: number;
  /** Total cost incurred */
  totalCost: number;
  /** Number of API requests */
  requestCount: number;
  /** Average tokens per request */
  averageTokensPerRequest: number;
  /** Peak usage hour */
  peakUsageTime?: number;
  /** Historical data points */
  dataPoints: UsageDataPoint[];
}

/**
 * Provider billing and quota information
 */
export interface ProviderBilling {
  /** Current billing cycle */
  cycle: BillingCycle;
  /** Total quota limit */
  quotaLimit: number;
  /** Used quota amount */
  quotaUsed: number;
  /** Remaining quota */
  quotaRemaining: number;
  /** Currency for billing */
  currency: CurrencyCode;
  /** Billing cycle start date */
  cycleStartDate: number;
  /** Billing cycle end date */
  cycleEndDate: number;
  /** Estimated cost for current cycle */
  estimatedCost: number;
}

/**
 * Complete provider configuration and data
 */
export interface Provider {
  /** Unique provider identifier */
  id: ProviderId;
  /** Display name */
  name: string;
  /** Provider description */
  description: string;
  /** Current operational status */
  status: ProviderStatus;
  /** Logo/icon URL */
  iconUrl: string;
  /** Brand color (hex) */
  brandColor: string;
  /** API endpoint base URL */
  apiEndpoint: string;
  /** Authentication token/key */
  apiToken?: string;
  /** Whether provider is enabled */
  enabled: boolean;
  /** Billing information */
  billing: ProviderBilling;
  /** Usage statistics */
  usage: UsageStats;
  /** Last sync timestamp */
  lastSyncTime: number;
  /** Last error message if any */
  lastError?: string;
}

/**
 * Provider configuration for user settings
 */
export interface ProviderConfig {
  /** Provider ID */
  id: ProviderId;
  /** Whether provider is enabled */
  enabled: boolean;
  /** API token/key */
  apiToken: string;
  /** Auto-refresh enabled */
  autoRefresh: boolean;
  /** Refresh interval in minutes */
  refreshInterval: number;
  /** Notification preferences */
  notifications: {
    /** Notify on quota threshold */
    quotaThreshold: boolean;
    /** Threshold percentage (0-100) */
    thresholdPercentage: number;
    /** Notify on errors */
    errors: boolean;
  };
}

/**
 * Aggregated usage across all providers
 */
export interface AggregatedUsage {
  /** Total cost across all providers */
  totalCost: number;
  /** Total tokens across all providers */
  totalTokens: number;
  /** Total requests across all providers */
  totalRequests: number;
  /** Cost breakdown by provider */
  costByProvider: Record<ProviderId, number>;
  /** Usage breakdown by time period */
  usageByPeriod: UsageDataPoint[];
  /** Most used provider */
  topProvider: ProviderId;
}
