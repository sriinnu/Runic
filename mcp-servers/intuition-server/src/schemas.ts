/**
 * Schema definitions for Intuition Server
 * Validates predictive analytics and recommendation data using Zod
 */

import { z } from "zod";

/**
 * Task type enumeration for model recommendations
 */
export const TaskType = z.enum(["coding", "chat", "analysis", "documentation", "testing", "writing", "general"]);
export type TaskType = z.infer<typeof TaskType>;

/**
 * Model cost prediction schema
 */
export const ModelCostPredictionSchema = z.object({
  model: z.string().min(1),
  provider: z.string().optional(),
  historicalUsage: z.array(z.object({
    timestamp: z.number().int().positive(),
    inputTokens: z.number().int().nonnegative(),
    outputTokens: z.number().int().nonnegative(),
    costUSD: z.number().nonnegative(),
  })).optional(),
  forecastDays: z.number().int().positive().default(7),
});

export type ModelCostPrediction = z.infer<typeof ModelCostPredictionSchema>;

/**
 * Model recommendation schema
 */
export const ModelRecommendationSchema = z.object({
  taskType: TaskType,
  maxCostPerRequest: z.number().nonnegative().optional(),
  preferredProviders: z.array(z.string()).optional(),
  requiredCapabilities: z.array(z.string()).optional(),
  contextWindowMin: z.number().int().positive().optional(),
});

export type ModelRecommendation = z.infer<typeof ModelRecommendationSchema>;

/**
 * Reset usage prediction schema
 */
export const ResetUsagePredictionSchema = z.object({
  provider: z.string().min(1),
  currentUsage: z.number().min(0).max(100),
  resetType: z.enum(["daily", "weekly", "monthly", "rolling"]),
  nextResetTimestamp: z.number().int().positive(),
  recentVelocity: z.array(z.number()).optional(),
});

export type ResetUsagePrediction = z.infer<typeof ResetUsagePredictionSchema>;

/**
 * Project optimization schema
 */
export const ProjectOptimizationSchema = z.object({
  projectId: z.string().min(1),
  providers: z.array(z.object({
    provider: z.string(),
    model: z.string().optional(),
    totalCost: z.number().nonnegative(),
    totalTokens: z.number().int().nonnegative(),
    usagePercent: z.number().min(0).max(100).optional(),
  })),
  targetCostReduction: z.number().min(0).max(100).optional(), // percentage
  days: z.number().int().positive().default(7),
});

export type ProjectOptimization = z.infer<typeof ProjectOptimizationSchema>;

/**
 * Usage data schema for predictions
 */
export const UsageDataSchema = z.object({
  timestamps: z.array(z.number().int().positive()).min(2),
  values: z.array(z.number().min(0).max(100)).min(2),
  provider: z.string().min(1),
});

export type UsageData = z.infer<typeof UsageDataSchema>;

/**
 * Provider usage schema for recommendations
 */
export const ProviderUsageSchema = z.object({
  provider: z.string().min(1),
  currentUsage: z.number().min(0).max(100),
  costPerToken: z.number().nonnegative().optional(),
  recentPattern: z.array(z.number()).optional(),
  availableModels: z.array(z.string()).optional(),
});

export type ProviderUsage = z.infer<typeof ProviderUsageSchema>;

/**
 * Compare model costs schema
 */
export const CompareModelCostsSchema = z.object({
  models: z.array(z.string()).min(2),
  taskType: z.enum(["coding", "writing", "analysis", "general"]),
  historicalUsage: z.array(z.object({
    model: z.string(),
    inputTokens: z.number().int().nonnegative(),
    outputTokens: z.number().int().nonnegative(),
    cost: z.number().nonnegative(),
  })).optional(),
});

export type CompareModelCosts = z.infer<typeof CompareModelCostsSchema>;

/**
 * Detect usage anomaly schema
 */
export const DetectUsageAnomalySchema = z.object({
  hourlyUsage: z.array(z.object({
    hour: z.string(),
    tokens: z.number().int().nonnegative(),
    cost: z.number().nonnegative(),
  })).min(3),
  threshold: z.number().positive().default(2.5),
});

export type DetectUsageAnomaly = z.infer<typeof DetectUsageAnomalySchema>;
