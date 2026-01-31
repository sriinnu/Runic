#!/usr/bin/env node

/**
 * Runic Intuition Server
 *
 * Embodies INTUITION from the motto: "persistence, intuition, consciousness"
 *
 * Enhanced capabilities:
 * - Model-specific cost prediction and forecasting
 * - Intelligent model recommendations based on task type
 * - Reset usage prediction with velocity tracking
 * - Project-based cost optimization
 * - Usage pattern prediction and forecasting
 * - Smart provider recommendations
 * - Cost optimization suggestions
 * - Anomaly detection in usage behavior
 * - Proactive limit warning predictions
 *
 * @version 2.0.0
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  Tool,
} from "@modelcontextprotocol/sdk/types.js";
import { z } from "zod";
import * as ss from "simple-statistics";
import { IntuitionTools } from "./tools.js";

// Legacy schema definitions (kept for backward compatibility)
const UsageDataSchema = z.object({
  timestamps: z.array(z.number()),
  values: z.array(z.number()),
  provider: z.string(),
});

const ProviderUsageSchema = z.object({
  provider: z.string(),
  currentUsage: z.number(),
  costPerToken: z.number().optional(),
  recentPattern: z.array(z.number()),
});

class IntuitionServer {
  private server: Server;
  private tools: IntuitionTools;

  constructor() {
    this.server = new Server(
      {
        name: "runic-intuition-server",
        version: "2.0.0",
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.tools = new IntuitionTools();
    this.setupHandlers();
  }

  private setupHandlers() {
    this.server.setRequestHandler(ListToolsRequestSchema, async () => {
      const tools: Tool[] = [
        // Enhanced tools
        {
          name: "predict_model_cost",
          description:
            "Forecast cost per model based on historical usage patterns. Uses linear regression " +
            "to predict future costs with confidence intervals. Returns daily forecasts and " +
            "trend analysis with actionable recommendations.",
          inputSchema: {
            type: "object",
            properties: {
              model: {
                type: "string",
                description: "Model name (e.g., 'claude-3-opus-20240229', 'gpt-4')",
              },
              provider: {
                type: "string",
                description: "Provider name (optional)",
              },
              historicalUsage: {
                type: "array",
                items: {
                  type: "object",
                  properties: {
                    timestamp: { type: "number", description: "Unix timestamp" },
                    inputTokens: { type: "number" },
                    outputTokens: { type: "number" },
                    costUSD: { type: "number" },
                  },
                  required: ["timestamp", "inputTokens", "outputTokens", "costUSD"],
                },
                description: "Historical usage records for the model",
              },
              forecastDays: {
                type: "number",
                description: "Number of days to forecast (default: 7)",
                default: 7,
              },
            },
            required: ["model"],
          },
        },
        {
          name: "recommend_model",
          description:
            "Recommend the cheapest model for a given task type. Analyzes all available models " +
            "considering cost efficiency, task suitability, context window requirements, and " +
            "other constraints. Returns ranked recommendations with detailed cost comparisons.",
          inputSchema: {
            type: "object",
            properties: {
              taskType: {
                type: "string",
                enum: ["coding", "chat", "analysis", "documentation", "testing"],
                description: "Type of task to perform",
              },
              maxCostPerRequest: {
                type: "number",
                description: "Maximum cost per request (USD)",
              },
              preferredProviders: {
                type: "array",
                items: { type: "string" },
                description: "Preferred provider list (optional)",
              },
              requiredCapabilities: {
                type: "array",
                items: { type: "string" },
                description: "Required model capabilities",
              },
              contextWindowMin: {
                type: "number",
                description: "Minimum required context window size",
              },
            },
            required: ["taskType"],
          },
        },
        {
          name: "predict_reset_usage",
          description:
            "Forecast usage at next reset time based on current velocity and usage patterns. " +
            "Calculates projected usage at reset with status assessment (SAFE/CAUTION/WARNING/CRITICAL) " +
            "and provides actionable recommendations.",
          inputSchema: {
            type: "object",
            properties: {
              provider: {
                type: "string",
                description: "Provider name",
              },
              currentUsage: {
                type: "number",
                description: "Current usage percent (0-100)",
              },
              resetType: {
                type: "string",
                enum: ["daily", "weekly", "monthly", "rolling"],
                description: "Type of reset cycle",
              },
              nextResetTimestamp: {
                type: "number",
                description: "Next reset time (Unix seconds)",
              },
              recentVelocity: {
                type: "array",
                items: { type: "number" },
                description: "Recent usage velocity (percent per hour)",
              },
            },
            required: ["provider", "currentUsage", "resetType", "nextResetTimestamp"],
          },
        },
        {
          name: "optimize_by_project",
          description:
            "Analyze and optimize costs for a specific project. Compares provider/model efficiency, " +
            "calculates potential savings, and recommends optimization strategies. Provides detailed " +
            "cost breakdown and actionable migration paths.",
          inputSchema: {
            type: "object",
            properties: {
              projectId: {
                type: "string",
                description: "Project identifier",
              },
              providers: {
                type: "array",
                items: {
                  type: "object",
                  properties: {
                    provider: { type: "string" },
                    model: { type: "string" },
                    totalCost: { type: "number" },
                    totalTokens: { type: "number" },
                    usagePercent: { type: "number" },
                  },
                  required: ["provider", "totalCost", "totalTokens"],
                },
                description: "Usage data per provider for the project",
              },
              targetCostReduction: {
                type: "number",
                description: "Target cost reduction percentage (0-100)",
              },
              days: {
                type: "number",
                description: "Analysis period in days (default: 7)",
                default: 7,
              },
            },
            required: ["projectId", "providers"],
          },
        },

        // Legacy tools (backward compatible)
        {
          name: "predict_usage_limit",
          description:
            "Predict when a provider will hit rate limits based on historical usage patterns. " +
            "Uses linear regression for time-to-limit estimation.",
          inputSchema: {
            type: "object",
            properties: {
              provider: { type: "string", description: "Provider name" },
              timestamps: {
                type: "array",
                items: { type: "number" },
                description: "Historical timestamps (Unix seconds)",
              },
              values: {
                type: "array",
                items: { type: "number" },
                description: "Historical usage percentages (0-100)",
              },
              currentUsage: { type: "number", description: "Current usage percent" },
            },
            required: ["provider", "timestamps", "values", "currentUsage"],
          },
        },
        {
          name: "recommend_provider",
          description:
            "Recommend optimal provider based on current usage levels, costs, and patterns. " +
            "Considers availability and cost efficiency.",
          inputSchema: {
            type: "object",
            properties: {
              providers: {
                type: "array",
                items: {
                  type: "object",
                  properties: {
                    provider: { type: "string" },
                    currentUsage: { type: "number" },
                    costPerToken: { type: "number" },
                    recentPattern: { type: "array", items: { type: "number" } },
                  },
                  required: ["provider", "currentUsage"],
                },
                description: "Array of provider usage data",
              },
              taskType: {
                type: "string",
                enum: ["coding", "chat", "analysis"],
                description: "Type of task to perform",
              },
            },
            required: ["providers"],
          },
        },
        {
          name: "detect_usage_anomaly",
          description:
            "Detect unusual usage patterns that may indicate issues or misconfigurations. " +
            "Uses statistical outlier detection.",
          inputSchema: {
            type: "object",
            properties: {
              provider: { type: "string", description: "Provider name" },
              recentUsage: {
                type: "array",
                items: { type: "number" },
                description: "Recent usage values",
              },
              sensitivityLevel: {
                type: "string",
                enum: ["low", "medium", "high"],
                description: "Detection sensitivity",
                default: "medium",
              },
            },
            required: ["provider", "recentUsage"],
          },
        },
        {
          name: "optimize_cost",
          description:
            "Analyze cost patterns and suggest optimization strategies. Considers token " +
            "efficiency and usage distribution.",
          inputSchema: {
            type: "object",
            properties: {
              providers: {
                type: "array",
                items: {
                  type: "object",
                  properties: {
                    provider: { type: "string" },
                    totalCost: { type: "number" },
                    totalTokens: { type: "number" },
                    usagePercent: { type: "number" },
                  },
                },
                description: "Cost data for each provider",
              },
              days: { type: "number", description: "Analysis period in days", default: 7 },
            },
            required: ["providers"],
          },
        },
        {
          name: "forecast_reset_timing",
          description:
            "Predict optimal timing for rate limit resets based on usage velocity and " +
            "historical patterns.",
          inputSchema: {
            type: "object",
            properties: {
              provider: { type: "string", description: "Provider name" },
              currentUsage: { type: "number", description: "Current usage percent" },
              windowMinutes: { type: "number", description: "Rate limit window in minutes" },
              recentVelocity: {
                type: "array",
                items: { type: "number" },
                description: "Recent usage velocity (percent/hour)",
              },
            },
            required: ["provider", "currentUsage", "windowMinutes"],
          },
        },
      ];

      return { tools };
    });

    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      try {
        switch (name) {
          // Enhanced tools
          case "predict_model_cost":
            return await this.tools.predictModelCost(args);
          case "recommend_model":
            return await this.tools.recommendModel(args);
          case "predict_reset_usage":
            return await this.tools.predictResetUsage(args);
          case "optimize_by_project":
            return await this.tools.optimizeByProject(args);

          // Legacy tools
          case "predict_usage_limit":
            return await this.predictUsageLimit(args);
          case "recommend_provider":
            return await this.recommendProvider(args);
          case "detect_usage_anomaly":
            return await this.detectAnomaly(args);
          case "optimize_cost":
            return await this.optimizeCost(args);
          case "forecast_reset_timing":
            return await this.forecastResetTiming(args);

          default:
            throw new Error(`Unknown tool: ${name}`);
        }
      } catch (error) {
        return {
          content: [
            {
              type: "text",
              text: `Error: ${error instanceof Error ? error.message : String(error)}`,
            },
          ],
          isError: true,
        };
      }
    });
  }

  // Legacy method implementations (preserved for backward compatibility)

  private async predictUsageLimit(args: any) {
    const { provider, timestamps, values, currentUsage } = args;

    if (timestamps.length < 2 || timestamps.length !== values.length) {
      throw new Error("Insufficient data for prediction");
    }

    const data = timestamps.map((t: number, i: number) => [t, values[i]]);
    const regression = ss.linearRegression(data);
    const slope = regression.m;

    if (slope <= 0) {
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify({
              provider,
              prediction: "stable",
              message: "Usage is stable or decreasing. No limit risk detected.",
              currentUsage,
              trend: "decreasing",
            }),
          },
        ],
      };
    }

    const percentRemaining = 100 - currentUsage;
    const secondsToLimit = percentRemaining / slope;
    const hoursToLimit = secondsToLimit / 3600;

    const prediction = {
      provider,
      currentUsage: Math.round(currentUsage * 10) / 10,
      usageVelocity: (slope * 3600).toFixed(2) + "% per hour",
      estimatedTimeToLimit: {
        hours: Math.round(hoursToLimit * 10) / 10,
        minutes: Math.round((hoursToLimit * 60) * 10) / 10,
        timestamp: Math.floor(Date.now() / 1000 + secondsToLimit),
      },
      confidence: timestamps.length > 10 ? "high" : "medium",
      recommendation:
        hoursToLimit < 1
          ? "URGENT: Switch providers or pause usage"
          : hoursToLimit < 4
          ? "WARNING: Monitor closely and prepare alternatives"
          : "Normal: Continue monitoring",
    };

    return {
      content: [{ type: "text", text: JSON.stringify(prediction, null, 2) }],
    };
  }

  private async recommendProvider(args: any) {
    const { providers, taskType = "coding" } = args;

    if (!providers || providers.length === 0) {
      throw new Error("No providers provided");
    }

    const scored = providers.map((p: any) => {
      let score = 0;
      const headroom = 100 - p.currentUsage;
      score += headroom * 0.5;

      if (p.costPerToken) {
        const costScore = Math.max(0, 100 - p.costPerToken * 10000);
        score += costScore * 0.3;
      }

      if (p.recentPattern && p.recentPattern.length > 0) {
        const variance = ss.variance(p.recentPattern);
        const stabilityScore = Math.max(0, 100 - variance);
        score += stabilityScore * 0.2;
      }

      return {
        provider: p.provider,
        score: Math.round(score),
        factors: {
          headroom: Math.round(headroom),
          currentUsage: Math.round(p.currentUsage),
          costPerToken: p.costPerToken?.toFixed(6),
          stability: p.recentPattern ? "stable" : "unknown",
        },
      };
    });

    scored.sort((a: any, b: any) => b.score - a.score);

    const recommendation = {
      taskType,
      recommendedProvider: scored[0].provider,
      reasoning: this.generateReasoning(scored[0]),
      rankings: scored,
      timestamp: new Date().toISOString(),
    };

    return {
      content: [{ type: "text", text: JSON.stringify(recommendation, null, 2) }],
    };
  }

  private generateReasoning(topProvider: any): string {
    const reasons = [];
    if (topProvider.factors.headroom > 80) reasons.push("plenty of headroom available");
    if (topProvider.factors.costPerToken && parseFloat(topProvider.factors.costPerToken) < 0.0001)
      reasons.push("cost-effective");
    if (topProvider.factors.stability === "stable") reasons.push("stable usage pattern");

    return reasons.length > 0
      ? `${topProvider.provider} is recommended because it has ${reasons.join(", ")}.`
      : `${topProvider.provider} has the highest overall score.`;
  }

  private async detectAnomaly(args: any) {
    const { provider, recentUsage, sensitivityLevel = "medium" } = args;

    if (recentUsage.length < 3) {
      throw new Error("Insufficient data for anomaly detection");
    }

    const mean = ss.mean(recentUsage);
    const stdDev = ss.standardDeviation(recentUsage);
    const thresholds = { low: 3, medium: 2, high: 1.5 };
    const threshold = thresholds[sensitivityLevel as keyof typeof thresholds] || 2;

    const latestValue = recentUsage[recentUsage.length - 1];
    const zScore = Math.abs((latestValue - mean) / stdDev);
    const isAnomaly = zScore > threshold;

    const result = {
      provider,
      anomalyDetected: isAnomaly,
      currentValue: latestValue,
      expectedRange: {
        mean: Math.round(mean * 10) / 10,
        lower: Math.round((mean - threshold * stdDev) * 10) / 10,
        upper: Math.round((mean + threshold * stdDev) * 10) / 10,
      },
      deviation: {
        zScore: Math.round(zScore * 100) / 100,
        standardDeviations: Math.round(zScore * 10) / 10,
      },
      severity: zScore > 3 ? "high" : zScore > 2 ? "medium" : "low",
      possibleCauses: isAnomaly
        ? ["Sudden spike in usage", "API rate limiting kicking in", "Configuration change", "Abnormal workload"]
        : [],
    };

    return {
      content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
    };
  }

  private async optimizeCost(args: any) {
    const { providers, days = 7 } = args;

    if (!providers || providers.length === 0) {
      throw new Error("No provider data provided");
    }

    const totalCost = providers.reduce((sum: number, p: any) => sum + (p.totalCost || 0), 0);
    const totalTokens = providers.reduce((sum: number, p: any) => sum + (p.totalTokens || 0), 0);

    const analysis = providers.map((p: any) => ({
      provider: p.provider,
      costShare: ((p.totalCost / totalCost) * 100).toFixed(1) + "%",
      efficiency: p.totalTokens ? (p.totalCost / p.totalTokens).toFixed(6) : "N/A",
      utilizationRate: p.usagePercent?.toFixed(1) + "%",
      recommendation: this.getCostRecommendation(p),
    }));

    const mostExpensive = [...providers].sort((a, b) => b.totalCost - a.totalCost)[0];
    const mostEfficient = [...providers]
      .filter(p => p.totalTokens > 0)
      .sort((a, b) => (a.totalCost / a.totalTokens) - (b.totalCost / b.totalTokens))[0];

    const optimization = {
      period: `${days} days`,
      totalCost: totalCost.toFixed(2),
      totalTokens,
      averageCostPerToken: (totalCost / totalTokens).toFixed(6),
      providerBreakdown: analysis,
      insights: {
        mostExpensive: mostExpensive?.provider,
        mostEfficient: mostEfficient?.provider,
        potentialSavings: this.calculatePotentialSavings(providers),
      },
      recommendations: [
        "Shift more workload to cost-efficient providers",
        "Monitor high-usage periods for optimization opportunities",
        "Consider provider quotas to control costs",
      ],
    };

    return {
      content: [{ type: "text", text: JSON.stringify(optimization, null, 2) }],
    };
  }

  private getCostRecommendation(provider: any): string {
    if (!provider.totalCost || !provider.totalTokens) return "Insufficient data for recommendation";
    const costPerToken = provider.totalCost / provider.totalTokens;
    if (costPerToken > 0.0001) return "High cost - consider alternatives for bulk operations";
    if (costPerToken > 0.00005) return "Moderate cost - good for balanced workloads";
    return "Cost-efficient - prioritize for high-volume tasks";
  }

  private calculatePotentialSavings(providers: any[]): string {
    const totalTokens = providers.reduce((sum, p) => sum + (p.totalTokens || 0), 0);
    const currentCost = providers.reduce((sum, p) => sum + (p.totalCost || 0), 0);
    const validProviders = providers.filter(p => p.totalTokens > 0);
    if (validProviders.length === 0) return "N/A";

    const bestRate = Math.min(...validProviders.map(p => p.totalCost / p.totalTokens));
    const potentialCost = totalTokens * bestRate;
    const savings = currentCost - potentialCost;

    return savings > 0 ? `$${savings.toFixed(2)} (${((savings / currentCost) * 100).toFixed(1)}%)` : "$0.00";
  }

  private async forecastResetTiming(args: any) {
    const { provider, currentUsage, windowMinutes, recentVelocity = [] } = args;

    const avgVelocity = recentVelocity.length > 0
      ? ss.mean(recentVelocity)
      : (currentUsage / windowMinutes) * 60;

    const minutesUntilReset = windowMinutes - (Date.now() / 60000) % windowMinutes;
    const projectedUsageAtReset = currentUsage + (avgVelocity * (minutesUntilReset / 60));

    const forecast = {
      provider,
      currentUsage: Math.round(currentUsage * 10) / 10,
      windowMinutes,
      minutesUntilReset: Math.round(minutesUntilReset),
      projectedUsageAtReset: Math.round(Math.min(100, projectedUsageAtReset) * 10) / 10,
      usageVelocity: avgVelocity.toFixed(2) + "% per hour",
      status:
        projectedUsageAtReset >= 95
          ? "CRITICAL: Will likely hit limit before reset"
          : projectedUsageAtReset >= 80
          ? "WARNING: Approaching limit"
          : "SAFE: Usage sustainable until reset",
      recommendation:
        projectedUsageAtReset >= 95
          ? "Throttle usage or switch providers immediately"
          : "Continue monitoring",
    };

    return {
      content: [{ type: "text", text: JSON.stringify(forecast, null, 2) }],
    };
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error("Runic Intuition Server v2.0.0 running on stdio");
  }
}

const server = new IntuitionServer();
server.run().catch(console.error);
