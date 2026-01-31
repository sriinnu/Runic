/**
 * Schema definitions for Consciousness Server
 * Validates monitoring, alerting, and diagnostic data using Zod
 */

import { z } from "zod";

/**
 * Provider status enumeration
 */
export const ProviderStatus = z.enum([
  "operational",
  "degraded",
  "partial_outage",
  "major_outage",
  "unknown"
]);
export type ProviderStatus = z.infer<typeof ProviderStatus>;

/**
 * Account type enumeration
 */
export const AccountType = z.enum([
  "subscription",
  "usage_based",
  "enterprise",
  "free_tier"
]);
export type AccountType = z.infer<typeof AccountType>;

/**
 * Reset timing monitor schema
 */
export const ResetTimingSchema = z.object({
  provider: z.string().min(1),
  expectedResetTime: z.number().int().positive(),
  actualResetTime: z.number().int().positive().optional(),
  toleranceMinutes: z.number().int().positive().default(5),
});

export type ResetTiming = z.infer<typeof ResetTimingSchema>;

/**
 * Account type verification schema
 */
export const AccountVerificationSchema = z.object({
  provider: z.string().min(1),
  observedBehavior: z.object({
    hasUsagePercent: z.boolean(),
    hasCreditsRemaining: z.boolean(),
    hasResetSchedule: z.boolean(),
    rateLimitBehavior: z.string().optional(),
  }),
});

export type AccountVerification = z.infer<typeof AccountVerificationSchema>;

/**
 * Reset alert schema
 */
export const ResetAlertSchema = z.object({
  provider: z.string().min(1),
  currentUsage: z.number().min(0).max(100),
  nextResetTimestamp: z.number().int().positive(),
  alertThreshold: z.number().min(0).max(100).default(85),
  hoursBeforeReset: z.number().positive().default(24),
});

export type ResetAlert = z.infer<typeof ResetAlertSchema>;

/**
 * Model performance diagnostic schema
 */
export const ModelDiagnosticSchema = z.object({
  model: z.string().min(1),
  provider: z.string().min(1),
  recentMetrics: z.object({
    avgLatencyMs: z.number().nonnegative().optional(),
    errorRate: z.number().min(0).max(1).optional(),
    throughput: z.number().nonnegative().optional(),
    costPerRequest: z.number().nonnegative().optional(),
  }).optional(),
  timeWindowHours: z.number().int().positive().default(24),
});

export type ModelDiagnostic = z.infer<typeof ModelDiagnosticSchema>;

/**
 * Health check schema
 */
export const HealthCheckSchema = z.object({
  component: z.string().min(1),
  healthy: z.boolean(),
  latencyMs: z.number().nonnegative().optional(),
  message: z.string().optional(),
  timestamp: z.number().int().positive().optional(),
});

export type HealthCheck = z.infer<typeof HealthCheckSchema>;

/**
 * Provider incident schema
 */
export const ProviderIncidentSchema = z.object({
  title: z.string(),
  status: z.string(),
  severity: z.string(),
  createdAt: z.string(),
  resolvedAt: z.string().optional(),
});

export type ProviderIncident = z.infer<typeof ProviderIncidentSchema>;
