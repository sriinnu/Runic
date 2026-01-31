/**
 * Schema definitions for Persistence Server
 * Validates data structures using Zod for type-safe data handling
 */

import { z } from "zod";

/**
 * Account type enumeration
 * Differentiates between subscription-based and usage-based accounts
 */
export const AccountType = z.enum(["subscription", "usage_based", "enterprise", "free_tier"]);
export type AccountType = z.infer<typeof AccountType>;

/**
 * Enhanced usage record schema with model, project, and account tracking
 */
export const EnhancedUsageRecordSchema = z.object({
  provider: z.string().min(1, "Provider name is required"),
  timestamp: z.number().int().positive(),
  primaryUsedPercent: z.number().min(0).max(100),
  secondaryUsedPercent: z.number().min(0).max(100).optional(),
  creditsRemaining: z.number().optional(),
  inputTokens: z.number().int().nonnegative().optional(),
  outputTokens: z.number().int().nonnegative().optional(),
  costUSD: z.number().nonnegative().optional(),
  model: z.string().optional(),
  sessionId: z.string().optional(),
  // New enhanced fields
  projectId: z.string().optional(),
  accountType: AccountType.optional(),
  resetSchedule: z.string().optional(), // ISO 8601 timestamp
  rateLimitWindow: z.number().int().positive().optional(), // minutes
});

export type EnhancedUsageRecord = z.infer<typeof EnhancedUsageRecordSchema>;

/**
 * Query schema with enhanced filtering capabilities
 */
export const QuerySchema = z.object({
  provider: z.string().optional(),
  model: z.string().optional(),
  projectId: z.string().optional(),
  accountType: AccountType.optional(),
  startTime: z.number().int().positive().optional(),
  endTime: z.number().int().positive().optional(),
  limit: z.number().int().positive().default(100),
  aggregation: z.enum(["raw", "hourly", "daily", "weekly"]).default("raw"),
});

export type QueryParams = z.infer<typeof QuerySchema>;

/**
 * Reset schedule schema for tracking provider reset timings
 */
export const ResetScheduleSchema = z.object({
  provider: z.string().min(1),
  resetType: z.enum(["daily", "weekly", "monthly", "rolling"]),
  nextResetTimestamp: z.number().int().positive(),
  resetWindowMinutes: z.number().int().positive(),
  timezone: z.string().default("UTC"),
  isAutoDetected: z.boolean().default(false),
});

export type ResetSchedule = z.infer<typeof ResetScheduleSchema>;

/**
 * Model query schema for filtering by model
 */
export const ModelQuerySchema = z.object({
  model: z.string().min(1),
  provider: z.string().optional(),
  startTime: z.number().int().positive().optional(),
  endTime: z.number().int().positive().optional(),
  limit: z.number().int().positive().default(100),
});

export type ModelQuery = z.infer<typeof ModelQuerySchema>;

/**
 * Project query schema for filtering by project ID
 */
export const ProjectQuerySchema = z.object({
  projectId: z.string().min(1),
  provider: z.string().optional(),
  startTime: z.number().int().positive().optional(),
  endTime: z.number().int().positive().optional(),
  limit: z.number().int().positive().default(100),
});

export type ProjectQuery = z.infer<typeof ProjectQuerySchema>;
