/**
 * Type definitions for Runic API
 *
 * These types match the enhanced usage models from RunicCore
 * and are exposed via the REST API for AI assistant apps.
 */

/**
 * Account type for a provider
 */
export enum AccountType {
  UsageBased = 'usage_based',
  Subscription = 'subscription',
  FreeTier = 'free_tier',
  Enterprise = 'enterprise',
  Unknown = 'unknown'
}

/**
 * Reset type for usage limits
 */
export enum ResetType {
  Hourly = 'hourly',
  Daily = 'daily',
  Weekly = 'weekly',
  Monthly = 'monthly',
  SessionBased = 'session',
  Manual = 'manual',
  Never = 'never'
}

/**
 * Model family categorization
 */
export enum ModelFamily {
  GPT4 = 'gpt-4',
  GPT35 = 'gpt-3.5',
  Claude3 = 'claude-3',
  Claude4 = 'claude-4',
  Gemini = 'gemini',
  Codex = 'codex',
  Other = 'other'
}

/**
 * Model tier (performance/cost level)
 */
export enum ModelTier {
  Opus = 'opus',
  Sonnet = 'sonnet',
  Haiku = 'haiku',
  Turbo = 'turbo',
  Standard = 'standard',
  Unknown = 'unknown'
}

/**
 * Alert severity levels
 */
export enum AlertSeverity {
  Info = 'info',
  Warning = 'warning',
  Critical = 'critical',
  Urgent = 'urgent'
}

/**
 * Usage rate window (session, weekly, etc.)
 */
export interface RateWindow {
  usedPercent: number;
  windowMinutes?: number;
  resetsAt?: string; // ISO 8601 timestamp
  resetDescription?: string;
}

/**
 * Reset information for a usage window
 */
export interface UsageResetInfo {
  resetType: ResetType;
  resetAt?: string; // ISO 8601 timestamp
  windowDuration?: number; // in seconds
  resetsAutomatically: boolean;
  timeUntilReset?: number; // in seconds
  resetDescription: string;
}

/**
 * Model usage information
 */
export interface ModelUsageInfo {
  modelName: string;
  modelFamily: ModelFamily;
  version?: string;
  tier: ModelTier;
  displayName: string;
}

/**
 * Project information
 */
export interface ProjectInfo {
  projectID: string;
  projectName?: string;
  workspacePath?: string;
  repository?: string;
  tags: string[];
  displayName: string;
}

/**
 * Detailed token usage breakdown
 */
export interface DetailedTokenUsage {
  inputTokens: number;
  outputTokens: number;
  cacheCreationTokens: number;
  cacheReadTokens: number;
  totalTokens: number;
  modelBreakdown: Record<string, number>; // modelName -> token count
  projectBreakdown: Record<string, number>; // projectID -> token count
}

/**
 * Enhanced usage snapshot (main data structure)
 */
export interface EnhancedUsageSnapshot {
  // Core usage data
  provider: string;
  primary: RateWindow;
  secondary?: RateWindow;
  tertiary?: RateWindow;

  // Account information
  accountType: AccountType;
  accountEmail?: string;
  accountOrganization?: string;

  // Reset tracking
  primaryReset?: UsageResetInfo;
  secondaryReset?: UsageResetInfo;

  // Model/agent tracking
  recentModels: ModelUsageInfo[];
  primaryModel?: ModelUsageInfo;

  // Project tracking
  activeProject?: ProjectInfo;
  recentProjects: ProjectInfo[];

  // Session tracking
  sessionID?: string;
  sessionStartedAt?: string; // ISO 8601

  // Token usage breakdown
  tokenUsage?: DetailedTokenUsage;

  // Cost information
  estimatedCost?: number;
  costCurrency: string;

  // Metadata
  updatedAt: string; // ISO 8601
  fetchSource: string; // "oauth", "web", "cli"
}

/**
 * Usage alert
 */
export interface UsageAlert {
  id: string;
  provider: string;
  severity: AlertSeverity;
  title: string;
  message: string;
  threshold: number; // Percentage
  currentUsage: number;
  estimatedTimeToLimit?: number; // in seconds
  recommendation: string;
  createdAt: string; // ISO 8601
}

/**
 * Sync state across devices
 */
export interface SyncState {
  deviceID: string;
  deviceName: string;
  platform: 'macos' | 'ios' | 'android' | 'windows' | 'cli';
  lastSync: string; // ISO 8601
  snapshots: Record<string, EnhancedUsageSnapshot>; // providerID -> snapshot
}

/**
 * API response wrapper
 */
export interface ApiResponse<T> {
  data: T;
  timestamp: string;
  success: boolean;
  error?: {
    message: string;
    code: string;
  };
}

/**
 * Paginated response
 */
export interface PaginatedResponse<T> {
  data: T[];
  pagination: {
    page: number;
    pageSize: number;
    totalPages: number;
    totalItems: number;
  };
}

/**
 * WebSocket message types
 */
export enum WebSocketMessageType {
  UsageUpdate = 'usage_update',
  AlertCreated = 'alert_created',
  ResetOccurred = 'reset_occurred',
  ModelUsed = 'model_used',
  ProjectChanged = 'project_changed'
}

/**
 * WebSocket message
 */
export interface WebSocketMessage {
  type: WebSocketMessageType;
  provider?: string;
  timestamp: string;
  data: any;
}

/**
 * Webhook configuration
 */
export interface WebhookConfig {
  id: string;
  url: string;
  events: WebSocketMessageType[];
  secret: string;
  enabled: boolean;
  createdAt: string;
}
