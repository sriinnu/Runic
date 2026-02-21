/**
 * Tool handlers for Intuition Server
 * Implements predictive analytics and intelligent recommendations
 */

import * as ss from "simple-statistics";
import {
  ModelCostPredictionSchema,
  ModelRecommendationSchema,
  ResetUsagePredictionSchema,
  ProjectOptimizationSchema,
  CompareModelCostsSchema,
  DetectUsageAnomalySchema,
  type TaskType,
} from "./schemas.js";

/**
 * Model pricing database (example data - should be updated from real API pricing)
 */
const MODEL_PRICING: Record<string, { inputCost: number; outputCost: number; contextWindow: number }> = {
  "claude-3-opus-20240229": { inputCost: 0.015, outputCost: 0.075, contextWindow: 200000 },
  "claude-3-sonnet-20240229": { inputCost: 0.003, outputCost: 0.015, contextWindow: 200000 },
  "claude-3-haiku-20240307": { inputCost: 0.00025, outputCost: 0.00125, contextWindow: 200000 },
  "gpt-4-turbo": { inputCost: 0.01, outputCost: 0.03, contextWindow: 128000 },
  "gpt-4": { inputCost: 0.03, outputCost: 0.06, contextWindow: 8192 },
  "gpt-3.5-turbo": { inputCost: 0.0005, outputCost: 0.0015, contextWindow: 16385 },
};

export class IntuitionTools {
  /**
   * Predict model cost based on historical usage patterns
   * Uses linear regression to forecast future costs
   * @param args - Model cost prediction parameters
   * @returns Cost forecast with confidence intervals
   */
  async predictModelCost(args: unknown) {
    const data = ModelCostPredictionSchema.parse(args);

    if (!data.historicalUsage || data.historicalUsage.length < 2) {
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify({
              model: data.model,
              error: "Insufficient historical data for prediction",
              recommendation: "Need at least 2 historical usage records",
            }),
          },
        ],
      };
    }

    // Calculate daily cost trends
    const dailyCosts = this.aggregateByDay(data.historicalUsage);
    const timestamps = dailyCosts.map(d => d.timestamp);
    const costs = dailyCosts.map(d => d.cost);

    // Linear regression for cost prediction
    const regressionData = timestamps.map((t, i) => [t, costs[i]]);
    const regression = ss.linearRegression(regressionData);
    const slope = regression.m; // cost per second
    const intercept = regression.b;

    // Forecast future costs
    const now = Math.floor(Date.now() / 1000);
    const forecast = [];
    for (let day = 1; day <= data.forecastDays; day++) {
      const futureTimestamp = now + (day * 86400);
      const predictedCost = slope * futureTimestamp + intercept;
      forecast.push({
        day,
        date: new Date(futureTimestamp * 1000).toISOString().split('T')[0],
        predictedCost: Math.max(0, predictedCost).toFixed(4),
      });
    }

    // Calculate statistics
    const avgDailyCost = ss.mean(costs);
    const stdDev = ss.standardDeviation(costs);
    const totalHistoricalTokens = data.historicalUsage.reduce(
      (sum, record) => sum + record.inputTokens + record.outputTokens,
      0
    );
    const totalHistoricalCost = data.historicalUsage.reduce(
      (sum, record) => sum + record.costUSD,
      0
    );
    const avgCostPer1kTokens = totalHistoricalTokens > 0
      ? (totalHistoricalCost / totalHistoricalTokens) * 1000
      : 0;

    const prediction = {
      model: data.model,
      provider: data.provider || "auto-detect",
      forecastPeriod: `${data.forecastDays} days`,
      historical: {
        avgDailyCost: avgDailyCost.toFixed(4),
        stdDeviation: stdDev.toFixed(4),
        totalCost: totalHistoricalCost.toFixed(4),
        totalTokens: totalHistoricalTokens,
        avgCostPer1kTokens: avgCostPer1kTokens.toFixed(6),
        dataPoints: dailyCosts.length,
      },
      forecast: forecast,
      projectedTotalCost: forecast.reduce((sum, f) => sum + parseFloat(f.predictedCost), 0).toFixed(4),
      trend: slope > 0 ? "increasing" : slope < 0 ? "decreasing" : "stable",
      confidence: dailyCosts.length >= 7 ? "high" : dailyCosts.length >= 3 ? "medium" : "low",
      recommendations: this.getCostRecommendations(slope, avgDailyCost, data.model),
    };

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(prediction, null, 2),
        },
      ],
    };
  }

  /**
   * Recommend the cheapest model for a given task type
   * Considers cost, capabilities, and current availability
   * @param args - Model recommendation parameters
   * @returns Recommended models ranked by cost-effectiveness
   */
  async recommendModel(args: unknown) {
    const data = ModelRecommendationSchema.parse(args);

    // Score each model based on task type and constraints
    const modelScores = Object.entries(MODEL_PRICING).map(([model, pricing]) => {
      let score = 100;

      // Task type suitability
      const taskSuitability = this.getTaskSuitability(model, data.taskType);
      score *= taskSuitability;

      // Cost factor (lower is better)
      const avgCost = (pricing.inputCost + pricing.outputCost) / 2;
      const costScore = Math.max(0, 100 - (avgCost * 1000)); // Scale to 0-100
      score *= (costScore / 100);

      // Context window requirement
      if (data.contextWindowMin && pricing.contextWindow < data.contextWindowMin) {
        score = 0; // Disqualify if doesn't meet minimum
      }

      // Max cost constraint
      if (data.maxCostPerRequest) {
        const estimatedCost = (pricing.inputCost + pricing.outputCost) * 500; // Assume 500 tokens
        if (estimatedCost > data.maxCostPerRequest) {
          score *= 0.5; // Penalize but don't disqualify
        }
      }

      return {
        model,
        score: Math.round(score * 100) / 100,
        pricing: {
          inputCostPer1k: pricing.inputCost,
          outputCostPer1k: pricing.outputCost,
          contextWindow: pricing.contextWindow,
        },
        suitability: taskSuitability >= 0.8 ? "high" : taskSuitability >= 0.5 ? "medium" : "low",
        estimatedCostPer1kTokens: ((pricing.inputCost + pricing.outputCost) / 2).toFixed(6),
      };
    });

    // Sort by score descending
    const rankedModels = modelScores
      .filter(m => m.score > 0)
      .sort((a, b) => b.score - a.score);

    if (rankedModels.length === 0) {
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify({
              error: "No models match the specified criteria",
              suggestion: "Try relaxing constraints or increasing maxCostPerRequest",
            }),
          },
        ],
      };
    }

    const recommendation = {
      taskType: data.taskType,
      recommendedModel: rankedModels[0].model,
      reasoning: this.generateModelRecommendationReasoning(rankedModels[0], data.taskType),
      topChoices: rankedModels.slice(0, 5),
      costComparison: {
        cheapest: rankedModels[rankedModels.length - 1]?.model,
        mostExpensive: rankedModels[0]?.model,
        costRatio: (
          parseFloat(rankedModels[0]?.estimatedCostPer1kTokens || "0") /
          parseFloat(rankedModels[rankedModels.length - 1]?.estimatedCostPer1kTokens || "1")
        ).toFixed(2),
      },
      constraints: {
        maxCostPerRequest: data.maxCostPerRequest,
        contextWindowMin: data.contextWindowMin,
        preferredProviders: data.preferredProviders,
      },
    };

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(recommendation, null, 2),
        },
      ],
    };
  }

  /**
   * Predict usage at next reset time based on current velocity
   * @param args - Reset usage prediction parameters
   * @returns Projected usage at reset with status assessment
   */
  async predictResetUsage(args: unknown) {
    const data = ResetUsagePredictionSchema.parse(args);

    const now = Math.floor(Date.now() / 1000);
    const secondsUntilReset = data.nextResetTimestamp - now;

    if (secondsUntilReset <= 0) {
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify({
              provider: data.provider,
              status: "RESET_OVERDUE",
              message: "Reset time has passed - data may be stale",
              currentUsage: data.currentUsage,
            }),
          },
        ],
      };
    }

    // Calculate velocity from recent data or estimate
    let usageVelocity: number;
    if (data.recentVelocity && data.recentVelocity.length > 0) {
      usageVelocity = ss.mean(data.recentVelocity); // percent per hour
    } else {
      // Estimate uniform velocity
      usageVelocity = data.currentUsage / (this.getResetWindowHours(data.resetType));
    }

    const hoursUntilReset = secondsUntilReset / 3600;
    const projectedUsageAtReset = Math.min(100, data.currentUsage + (usageVelocity * hoursUntilReset));
    const usageMargin = 100 - projectedUsageAtReset;

    // Determine status and recommendations
    let status: string;
    let recommendations: string[];

    if (projectedUsageAtReset >= 100) {
      status = "CRITICAL";
      recommendations = [
        "Will hit limit before reset - immediate action required",
        "Switch to alternative provider",
        "Reduce usage rate significantly",
        "Consider upgrading account tier if available",
      ];
    } else if (projectedUsageAtReset >= 90) {
      status = "WARNING";
      recommendations = [
        "High risk of hitting limit before reset",
        "Prepare backup provider",
        "Monitor usage closely",
        "Consider throttling non-critical requests",
      ];
    } else if (projectedUsageAtReset >= 75) {
      status = "CAUTION";
      recommendations = [
        "Usage trending high but manageable",
        "Monitor for unexpected spikes",
        "Plan usage distribution for remaining time",
      ];
    } else {
      status = "SAFE";
      recommendations = [
        "Usage well within safe limits",
        "Continue normal operations",
        "Current usage pattern is sustainable",
      ];
    }

    const prediction = {
      provider: data.provider,
      resetType: data.resetType,
      currentUsage: Math.round(data.currentUsage * 10) / 10,
      projectedUsageAtReset: Math.round(projectedUsageAtReset * 10) / 10,
      usageMargin: Math.round(usageMargin * 10) / 10,
      status,
      timeUntilReset: {
        hours: Math.round(hoursUntilReset * 10) / 10,
        minutes: Math.round((hoursUntilReset * 60) * 10) / 10,
        humanReadable: this.formatTimeUntil(secondsUntilReset),
        nextResetTime: new Date(data.nextResetTimestamp * 1000).toISOString(),
      },
      velocity: {
        percentPerHour: Math.round(usageVelocity * 100) / 100,
        basedOn: data.recentVelocity ? "historical_data" : "estimated",
        confidence: data.recentVelocity && data.recentVelocity.length >= 3 ? "high" : "medium",
      },
      recommendations,
    };

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(prediction, null, 2),
        },
      ],
    };
  }

  /**
   * Optimize costs by project with model and provider recommendations
   * @param args - Project optimization parameters
   * @returns Cost optimization strategies and savings projections
   */
  async optimizeByProject(args: unknown) {
    const data = ProjectOptimizationSchema.parse(args);

    const totalCost = data.providers.reduce((sum, p) => sum + p.totalCost, 0);
    const totalTokens = data.providers.reduce((sum, p) => sum + p.totalTokens, 0);

    // Analyze each provider's efficiency
    const providerAnalysis = data.providers.map(p => {
      const costPerToken = p.totalTokens > 0 ? p.totalCost / p.totalTokens : 0;
      const costShare = (p.totalCost / totalCost) * 100;

      return {
        provider: p.provider,
        model: p.model || "unknown",
        totalCost: p.totalCost.toFixed(4),
        totalTokens: p.totalTokens,
        costPerToken: costPerToken.toFixed(8),
        costShare: costShare.toFixed(1) + "%",
        efficiency: this.getEfficiencyRating(costPerToken),
        usagePercent: p.usagePercent,
      };
    });

    // Sort by cost per token to find most efficient
    const sortedByEfficiency = [...providerAnalysis].sort((a, b) =>
      parseFloat(a.costPerToken) - parseFloat(b.costPerToken)
    );

    const mostEfficient = sortedByEfficiency[0];
    const leastEfficient = sortedByEfficiency[sortedByEfficiency.length - 1];

    // Calculate potential savings
    const targetCostPerToken = parseFloat(mostEfficient.costPerToken);
    const potentialSavings = data.providers.reduce((savings, p) => {
      const currentCostPerToken = p.totalTokens > 0 ? p.totalCost / p.totalTokens : 0;
      if (currentCostPerToken > targetCostPerToken) {
        const savingsForProvider = (currentCostPerToken - targetCostPerToken) * p.totalTokens;
        return savings + savingsForProvider;
      }
      return savings;
    }, 0);

    const savingsPercent = totalCost > 0 ? (potentialSavings / totalCost) * 100 : 0;

    // Generate optimization strategies
    const strategies = this.generateOptimizationStrategies(
      providerAnalysis,
      mostEfficient,
      leastEfficient,
      data.targetCostReduction
    );

    // Generate actionable alerts
    const alerts = this.generateActionableAlerts(
      totalCost,
      savingsPercent,
      mostEfficient,
      leastEfficient,
      providerAnalysis
    );

    const optimization = {
      projectId: data.projectId,
      analysisPeriod: `${data.days} days`,
      summary: {
        totalCost: totalCost.toFixed(4),
        totalTokens,
        avgCostPer1kTokens: ((totalCost / totalTokens) * 1000).toFixed(6),
        providers: data.providers.length,
      },
      efficiency: {
        mostEfficient: {
          provider: mostEfficient.provider,
          model: mostEfficient.model,
          costPerToken: mostEfficient.costPerToken,
        },
        leastEfficient: {
          provider: leastEfficient.provider,
          model: leastEfficient.model,
          costPerToken: leastEfficient.costPerToken,
        },
        efficiencyGap: (
          parseFloat(leastEfficient.costPerToken) / parseFloat(mostEfficient.costPerToken)
        ).toFixed(2) + "x",
      },
      potentialSavings: {
        amount: potentialSavings.toFixed(4),
        percentage: savingsPercent.toFixed(1) + "%",
        achievableWith: `Migrating all usage to ${mostEfficient.provider}`,
      },
      alerts,
      providerBreakdown: providerAnalysis,
      optimizationStrategies: strategies,
      recommendations: [
        `Prioritize ${mostEfficient.provider} (${mostEfficient.model}) for new requests`,
        "Monitor usage patterns to identify opportunities for model switching",
        "Consider batching requests to reduce per-request overhead",
        savingsPercent > 20 ? "Significant savings possible - prioritize optimization" : "Current distribution is reasonably efficient",
      ],
    };

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(optimization, null, 2),
        },
      ],
    };
  }

  /**
   * Compare model costs across multiple models
   * @param args - Model comparison parameters
   * @returns Cost comparison with rankings and recommendations
   */
  async compareModelCosts(args: unknown) {
    const data = CompareModelCostsSchema.parse(args);

    // Build cost data for each model
    const modelComparisons = data.models.map(model => {
      const pricing = MODEL_PRICING[model];

      if (!pricing) {
        return {
          model,
          error: "Pricing data not available",
          costPerToken: null,
          costRatio: null,
          recommendation: "Unable to evaluate - no pricing data",
          savings: null,
        };
      }

      // Calculate average cost per token
      const avgCostPerToken = (pricing.inputCost + pricing.outputCost) / 2;

      // Calculate historical average if provided
      let historicalCostPerToken: number | null = null;
      if (data.historicalUsage) {
        const modelUsage = data.historicalUsage.filter(u => u.model === model);
        if (modelUsage.length > 0) {
          const totalTokens = modelUsage.reduce((sum, u) => sum + u.inputTokens + u.outputTokens, 0);
          const totalCost = modelUsage.reduce((sum, u) => sum + u.cost, 0);
          historicalCostPerToken = totalTokens > 0 ? totalCost / totalTokens : null;
        }
      }

      // Get task suitability
      const suitability = this.getTaskSuitability(model, data.taskType);

      return {
        model,
        pricing: {
          inputCostPer1M: (pricing.inputCost * 1000).toFixed(2),
          outputCostPer1M: (pricing.outputCost * 1000).toFixed(2),
          avgCostPerToken: avgCostPerToken.toFixed(8),
          contextWindow: pricing.contextWindow,
        },
        historicalCostPerToken: historicalCostPerToken ? historicalCostPerToken.toFixed(8) : null,
        taskSuitability: suitability,
        suitabilityRating: suitability >= 0.8 ? "high" : suitability >= 0.6 ? "medium" : "low",
        costPerToken: avgCostPerToken,
      };
    });

    // Filter out models with errors
    const validModels = modelComparisons.filter(m => m.costPerToken !== null);

    if (validModels.length === 0) {
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify({
              error: "No valid models with pricing data found",
              models: data.models,
            }),
          },
        ],
      };
    }

    // Sort by cost (ascending)
    const sortedByCost = [...validModels].sort((a, b) =>
      (a.costPerToken || Infinity) - (b.costPerToken || Infinity)
    );

    const cheapest = sortedByCost[0];
    const mostExpensive = sortedByCost[sortedByCost.length - 1];

    // Calculate cost ratios and savings relative to cheapest
    const modelsWithMetrics = sortedByCost.map(m => {
      const costRatio = (m.costPerToken || 0) / (cheapest.costPerToken || 1);
      const savings = ((m.costPerToken || 0) - (cheapest.costPerToken || 0));

      // Generate recommendation
      let recommendation = "";
      if (m.model === cheapest.model) {
        recommendation = `Most cost-effective option for ${data.taskType}`;
      } else if (m.suitabilityRating === "high" && costRatio <= 1.5) {
        recommendation = `Good balance of capability and cost for ${data.taskType}`;
      } else if (costRatio > 3) {
        recommendation = `${costRatio.toFixed(1)}x more expensive - only use for critical tasks`;
      } else {
        recommendation = `${costRatio.toFixed(1)}x more expensive than cheapest option`;
      }

      return {
        model: m.model,
        pricing: m.pricing,
        historicalCostPerToken: m.historicalCostPerToken,
        taskSuitability: m.suitabilityRating,
        costPerToken: (m.costPerToken || 0).toFixed(8),
        costRatio: costRatio.toFixed(2) + "x",
        costDifferencePer1MTokens: (savings * 1000000).toFixed(2),
        recommendation,
      };
    });

    const comparison = {
      taskType: data.taskType,
      modelsCompared: data.models.length,
      cheapest: {
        model: cheapest.model,
        costPerToken: (cheapest.costPerToken || 0).toFixed(8),
        suitability: cheapest.suitabilityRating,
      },
      mostExpensive: {
        model: mostExpensive.model,
        costPerToken: (mostExpensive.costPerToken || 0).toFixed(8),
        suitability: mostExpensive.suitabilityRating,
      },
      costRange: {
        min: (cheapest.costPerToken || 0).toFixed(8),
        max: (mostExpensive.costPerToken || 0).toFixed(8),
        spread: ((mostExpensive.costPerToken || 0) / (cheapest.costPerToken || 1)).toFixed(2) + "x",
      },
      models: modelsWithMetrics,
      overallRecommendation: this.generateComparisonRecommendation(
        modelsWithMetrics,
        data.taskType,
        cheapest
      ),
    };

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(comparison, null, 2),
        },
      ],
    };
  }

  /**
   * Detect usage anomalies using statistical analysis
   * @param args - Hourly usage data and threshold
   * @returns Anomaly detection results with severity and recommendations
   */
  async detectUsageAnomaly(args: unknown) {
    const data = DetectUsageAnomalySchema.parse(args);

    // Extract token and cost arrays
    const tokens = data.hourlyUsage.map(h => h.tokens);
    const costs = data.hourlyUsage.map(h => h.cost);

    // Calculate statistics
    const tokenMean = ss.mean(tokens);
    const tokenStdDev = ss.standardDeviation(tokens);
    const costMean = ss.mean(costs);
    const costStdDev = ss.standardDeviation(costs);

    // Detect anomalies using Z-score
    const anomalies: Array<{
      hour: string;
      tokens: number;
      cost: number;
      tokenZScore: number;
      costZScore: number;
      severity: string;
      message: string;
    }> = [];

    data.hourlyUsage.forEach(hourData => {
      const tokenZScore = Math.abs((hourData.tokens - tokenMean) / tokenStdDev);
      const costZScore = Math.abs((hourData.cost - costMean) / costStdDev);

      // Check if either metric exceeds threshold
      if (tokenZScore > data.threshold || costZScore > data.threshold) {
        let severity = "low";
        let message = "";

        if (tokenZScore > 3 || costZScore > 3) {
          severity = "critical";
          message = "Extreme anomaly detected - immediate investigation required";
        } else if (tokenZScore > 2.5 || costZScore > 2.5) {
          severity = "high";
          message = "Significant anomaly detected - review usage patterns";
        } else if (tokenZScore > 2 || costZScore > 2) {
          severity = "medium";
          message = "Notable deviation from normal usage";
        } else {
          severity = "low";
          message = "Minor deviation detected";
        }

        // Add context to message
        if (hourData.tokens > tokenMean) {
          message += ` - tokens ${((hourData.tokens / tokenMean - 1) * 100).toFixed(0)}% above average`;
        } else {
          message += ` - tokens ${((1 - hourData.tokens / tokenMean) * 100).toFixed(0)}% below average`;
        }

        anomalies.push({
          hour: hourData.hour,
          tokens: hourData.tokens,
          cost: hourData.cost,
          tokenZScore: Math.round(tokenZScore * 100) / 100,
          costZScore: Math.round(costZScore * 100) / 100,
          severity,
          message,
        });
      }
    });

    // Sort anomalies by severity
    const severityOrder = { critical: 0, high: 1, medium: 2, low: 3 };
    anomalies.sort((a, b) =>
      severityOrder[a.severity as keyof typeof severityOrder] -
      severityOrder[b.severity as keyof typeof severityOrder]
    );

    // Generate recommendations
    const recommendations = this.generateAnomalyRecommendations(anomalies, tokenMean, costMean);

    const analysis = {
      period: {
        hours: data.hourlyUsage.length,
        from: data.hourlyUsage[0].hour,
        to: data.hourlyUsage[data.hourlyUsage.length - 1].hour,
      },
      baseline: {
        avgTokensPerHour: Math.round(tokenMean),
        avgCostPerHour: costMean.toFixed(4),
        tokenStdDev: Math.round(tokenStdDev),
        costStdDev: costStdDev.toFixed(4),
      },
      threshold: {
        value: data.threshold,
        description: `${data.threshold} standard deviations from mean`,
      },
      anomalyCount: anomalies.length,
      anomaliesDetected: anomalies.length > 0,
      anomalies,
      recommendations,
      summary: anomalies.length === 0
        ? "No significant anomalies detected - usage patterns are stable"
        : `${anomalies.length} anomal${anomalies.length === 1 ? 'y' : 'ies'} detected - review recommended`,
    };

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(analysis, null, 2),
        },
      ],
    };
  }

  // Helper methods

  /**
   * Aggregate usage records by day
   * @private
   */
  private aggregateByDay(records: Array<{ timestamp: number; costUSD: number }>) {
    const dailyMap = new Map<string, { timestamp: number; cost: number }>();

    records.forEach(record => {
      const date = new Date(record.timestamp * 1000).toISOString().split('T')[0];
      const existing = dailyMap.get(date);

      if (existing) {
        existing.cost += record.costUSD;
      } else {
        dailyMap.set(date, { timestamp: record.timestamp, cost: record.costUSD });
      }
    });

    return Array.from(dailyMap.values()).sort((a, b) => a.timestamp - b.timestamp);
  }

  /**
   * Get cost optimization recommendations
   * @private
   */
  private getCostRecommendations(slope: number, avgCost: number, model: string): string[] {
    const recommendations = [];

    if (slope > 0) {
      recommendations.push("Cost is increasing - investigate usage patterns");
      if (avgCost > 1) {
        recommendations.push("Consider switching to more cost-effective model variant");
      }
    } else if (slope < 0) {
      recommendations.push("Cost is decreasing - current optimization is working");
    }

    if (avgCost > 5) {
      recommendations.push("High daily cost - review necessity of all requests");
    }

    if (model.includes("opus") || model.includes("gpt-4")) {
      recommendations.push("Using premium model - consider cheaper alternatives for simpler tasks");
    }

    return recommendations;
  }

  /**
   * Get task suitability score for a model
   * @private
   */
  private getTaskSuitability(model: string, taskType: TaskType): number {
    const suitabilityMap: Record<string, Record<string, number>> = {
      "claude-3-opus-20240229": {
        coding: 1.0, chat: 0.9, analysis: 1.0, documentation: 0.9, testing: 0.8, writing: 0.95, general: 0.9
      },
      "claude-3-sonnet-20240229": {
        coding: 0.85, chat: 0.9, analysis: 0.85, documentation: 0.9, testing: 0.8, writing: 0.9, general: 0.85
      },
      "claude-3-haiku-20240307": {
        coding: 0.6, chat: 0.8, analysis: 0.6, documentation: 0.7, testing: 0.7, writing: 0.75, general: 0.7
      },
      "gpt-4-turbo": {
        coding: 0.95, chat: 0.85, analysis: 0.95, documentation: 0.85, testing: 0.9, writing: 0.9, general: 0.85
      },
      "gpt-4": {
        coding: 0.9, chat: 0.8, analysis: 0.9, documentation: 0.8, testing: 0.85, writing: 0.85, general: 0.8
      },
      "gpt-3.5-turbo": {
        coding: 0.6, chat: 0.8, analysis: 0.6, documentation: 0.7, testing: 0.65, writing: 0.75, general: 0.7
      },
    };

    return suitabilityMap[model]?.[taskType] || 0.5;
  }

  /**
   * Generate reasoning for model recommendation
   * @private
   */
  private generateModelRecommendationReasoning(topModel: any, taskType: TaskType): string {
    const reasons = [];

    if (topModel.suitability === "high") {
      reasons.push(`highly suitable for ${taskType} tasks`);
    }

    const costNum = parseFloat(topModel.estimatedCostPer1kTokens);
    if (costNum < 0.001) {
      reasons.push("very cost-effective");
    } else if (costNum < 0.01) {
      reasons.push("cost-effective");
    }

    if (topModel.pricing.contextWindow >= 100000) {
      reasons.push("large context window");
    }

    return `${topModel.model} is recommended because it is ${reasons.join(", ")}.`;
  }

  /**
   * Get reset window hours based on reset type
   * @private
   */
  private getResetWindowHours(resetType: string): number {
    const windowMap: Record<string, number> = {
      daily: 24,
      weekly: 168,
      monthly: 720,
      rolling: 24,
    };
    return windowMap[resetType] || 24;
  }

  /**
   * Format seconds into human-readable time
   * @private
   */
  private formatTimeUntil(seconds: number): string {
    if (seconds < 60) return `${Math.floor(seconds)} seconds`;
    if (seconds < 3600) return `${Math.floor(seconds / 60)} minutes`;
    if (seconds < 86400) return `${Math.round(seconds / 3600 * 10) / 10} hours`;
    return `${Math.round(seconds / 86400 * 100) / 100} days`;
  }

  /**
   * Get efficiency rating based on cost per token
   * @private
   */
  private getEfficiencyRating(costPerToken: number): string {
    if (costPerToken < 0.00001) return "excellent";
    if (costPerToken < 0.00005) return "good";
    if (costPerToken < 0.0001) return "fair";
    return "poor";
  }

  /**
   * Generate optimization strategies
   * @private
   */
  private generateOptimizationStrategies(
    providers: any[],
    mostEfficient: any,
    leastEfficient: any,
    targetReduction?: number
  ): Array<{ strategy: string; impact: string; difficulty: string }> {
    const strategies = [];

    const efficiencyGap = parseFloat(leastEfficient.costPerToken) / parseFloat(mostEfficient.costPerToken);

    if (efficiencyGap > 2) {
      strategies.push({
        strategy: `Migrate from ${leastEfficient.provider} to ${mostEfficient.provider}`,
        impact: "high",
        difficulty: "medium",
      });
    }

    strategies.push({
      strategy: "Implement request caching to reduce redundant API calls",
      impact: "medium",
      difficulty: "low",
    });

    strategies.push({
      strategy: "Use cheaper models for simple tasks, reserve premium models for complex work",
      impact: "high",
      difficulty: "medium",
    });

    if (targetReduction && targetReduction > 20) {
      strategies.push({
        strategy: "Batch similar requests together to optimize token usage",
        impact: "medium",
        difficulty: "medium",
      });
    }

    return strategies;
  }

  /**
   * Generate actionable alerts for project optimization
   * @private
   */
  private generateActionableAlerts(
    totalCost: number,
    savingsPercent: number,
    mostEfficient: any,
    leastEfficient: any,
    providerAnalysis: any[]
  ): Array<{ level: string; message: string; action: string }> {
    const alerts = [];

    // High cost alert
    if (totalCost > 100) {
      alerts.push({
        level: "warning",
        message: `Total cost of $${totalCost.toFixed(2)} is high`,
        action: "Review usage patterns and consider cost reduction strategies",
      });
    }

    // High savings potential alert
    if (savingsPercent > 30) {
      alerts.push({
        level: "critical",
        message: `${savingsPercent.toFixed(0)}% potential cost savings identified`,
        action: `Switch to ${mostEfficient.provider} for immediate cost reduction`,
      });
    } else if (savingsPercent > 15) {
      alerts.push({
        level: "warning",
        message: `${savingsPercent.toFixed(0)}% potential cost savings available`,
        action: "Consider gradual migration to more efficient providers",
      });
    }

    // Efficiency gap alert
    const efficiencyGap = parseFloat(leastEfficient.costPerToken) / parseFloat(mostEfficient.costPerToken);
    if (efficiencyGap > 5) {
      alerts.push({
        level: "critical",
        message: `${efficiencyGap.toFixed(1)}x efficiency gap between providers`,
        action: `Prioritize migrating from ${leastEfficient.provider} to ${mostEfficient.provider}`,
      });
    }

    // Poor efficiency alerts
    providerAnalysis.forEach(p => {
      if (p.efficiency === "poor" && parseFloat(p.costShare.replace("%", "")) > 20) {
        alerts.push({
          level: "warning",
          message: `${p.provider} has poor efficiency and represents ${p.costShare} of costs`,
          action: `Reduce usage of ${p.provider} or switch to more efficient alternatives`,
        });
      }
    });

    // Info alert if everything is good
    if (alerts.length === 0) {
      alerts.push({
        level: "info",
        message: "Cost distribution is reasonably efficient",
        action: "Continue monitoring for optimization opportunities",
      });
    }

    return alerts;
  }

  /**
   * Generate comparison recommendation
   * @private
   */
  private generateComparisonRecommendation(
    models: any[],
    taskType: string,
    cheapest: any
  ): string {
    const recommendations = [];

    recommendations.push(
      `For ${taskType} tasks, ${cheapest.model} offers the best cost efficiency at ${cheapest.costPerToken} per token.`
    );

    // Find high suitability models
    const highSuitability = models.filter(m => m.taskSuitability === "high");
    if (highSuitability.length > 0 && highSuitability[0].model !== cheapest.model) {
      const bestSuitable = highSuitability[0];
      recommendations.push(
        `For optimal ${taskType} performance, consider ${bestSuitable.model} (${bestSuitable.taskSuitability} suitability).`
      );
    }

    // Warn about expensive models
    const expensive = models.filter(m => parseFloat(m.costRatio.replace("x", "")) > 3);
    if (expensive.length > 0) {
      recommendations.push(
        `Avoid ${expensive.map(m => m.model).join(", ")} for routine tasks - they are 3x+ more expensive.`
      );
    }

    return recommendations.join(" ");
  }

  /**
   * Generate anomaly recommendations
   * @private
   */
  private generateAnomalyRecommendations(
    anomalies: any[],
    tokenMean: number,
    costMean: number
  ): string[] {
    const recommendations = [];

    if (anomalies.length === 0) {
      return ["Usage patterns are stable - no immediate action required"];
    }

    // Check for critical anomalies
    const critical = anomalies.filter(a => a.severity === "critical");
    if (critical.length > 0) {
      recommendations.push(
        `URGENT: ${critical.length} critical anomal${critical.length === 1 ? 'y' : 'ies'} detected - investigate immediately`
      );
      recommendations.push(
        "Check for runaway processes, API misuse, or security incidents"
      );
    }

    // Check for high anomalies
    const high = anomalies.filter(a => a.severity === "high");
    if (high.length > 0) {
      recommendations.push(
        `${high.length} significant anomal${high.length === 1 ? 'y' : 'ies'} detected - review usage patterns`
      );
    }

    // Check for patterns
    if (anomalies.length > 3) {
      recommendations.push(
        "Multiple anomalies detected - consider adjusting detection threshold or reviewing baseline usage"
      );
    }

    // Specific recommendations
    const highUsageAnomalies = anomalies.filter(a => a.tokens > tokenMean * 1.5);
    if (highUsageAnomalies.length > 0) {
      recommendations.push(
        `High token usage detected during: ${highUsageAnomalies.map(a => a.hour).join(", ")}`
      );
    }

    const highCostAnomalies = anomalies.filter(a => a.cost > costMean * 1.5);
    if (highCostAnomalies.length > 0) {
      recommendations.push(
        "Review expensive operations during peak anomaly periods"
      );
    }

    recommendations.push(
      "Set up alerts for anomalies to catch issues in real-time"
    );

    return recommendations;
  }
}
