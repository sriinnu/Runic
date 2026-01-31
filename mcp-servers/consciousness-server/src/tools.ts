/**
 * Tool handlers for Consciousness Server
 * Implements real-time monitoring, alerting, and diagnostic capabilities
 */

import fetch from "node-fetch";
import {
  ResetTimingSchema,
  AccountVerificationSchema,
  ResetAlertSchema,
  ModelDiagnosticSchema,
  type AccountType,
} from "./schemas.js";

export class ConsciousnessTools {
  private healthHistory: Map<string, any[]> = new Map();
  private alertThresholds: Map<string, number> = new Map();
  private resetTimingHistory: Map<string, any[]> = new Map();

  // Provider status page URLs
  private statusPages = {
    claude: "https://status.anthropic.com/api/v2/status.json",
    openai: "https://status.openai.com/api/v2/status.json",
    google: "https://status.cloud.google.com/incidents.json",
    github: "https://www.githubstatus.com/api/v2/status.json",
  };

  /**
   * Monitor reset timing accuracy by comparing expected vs actual reset times
   * Tracks provider reliability for reset schedules
   * @param args - Reset timing parameters
   * @returns Accuracy analysis with drift detection
   */
  async monitorResetTimings(args: unknown) {
    const data = ResetTimingSchema.parse(args);

    // Get or initialize timing history for this provider
    const history = this.resetTimingHistory.get(data.provider) || [];

    // Calculate drift if actual reset time is provided
    let drift: number | null = null;
    let accuracy: string = "pending";

    if (data.actualResetTime) {
      drift = data.actualResetTime - data.expectedResetTime;
      const driftMinutes = Math.abs(drift) / 60;

      if (driftMinutes <= data.toleranceMinutes) {
        accuracy = "accurate";
      } else if (driftMinutes <= data.toleranceMinutes * 2) {
        accuracy = "acceptable";
      } else {
        accuracy = "poor";
      }

      // Record in history
      history.push({
        expectedResetTime: data.expectedResetTime,
        actualResetTime: data.actualResetTime,
        drift,
        timestamp: Math.floor(Date.now() / 1000),
      });

      // Keep last 100 records
      if (history.length > 100) history.shift();
      this.resetTimingHistory.set(data.provider, history);
    }

    // Calculate statistics from history
    const stats = this.calculateResetTimingStats(history);

    const response = {
      provider: data.provider,
      expectedResetTime: new Date(data.expectedResetTime * 1000).toISOString(),
      actualResetTime: data.actualResetTime
        ? new Date(data.actualResetTime * 1000).toISOString()
        : null,
      drift: drift !== null ? {
        seconds: drift,
        minutes: Math.round((drift / 60) * 10) / 10,
        humanReadable: this.formatTimeDrift(drift),
      } : null,
      accuracy,
      toleranceMinutes: data.toleranceMinutes,
      statistics: stats,
      recommendations: this.getResetTimingRecommendations(accuracy, stats),
    };

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(response, null, 2),
        },
      ],
    };
  }

  /**
   * Verify and detect account type based on observed behavior patterns
   * @param args - Account verification parameters
   * @returns Detected account type with confidence level
   */
  async checkAccountType(args: unknown) {
    const data = AccountVerificationSchema.parse(args);

    let detectedType: AccountType = "unknown" as any;
    let confidence: string = "low";
    const evidence: string[] = [];

    // Analyze observed behavior patterns
    if (data.observedBehavior.hasUsagePercent && data.observedBehavior.hasResetSchedule) {
      if (data.observedBehavior.rateLimitBehavior === "rolling") {
        detectedType = "subscription";
        confidence = "high";
        evidence.push("Has usage percentage tracking");
        evidence.push("Has defined reset schedule");
        evidence.push("Rolling rate limit behavior typical of subscription");
      } else {
        detectedType = "subscription";
        confidence = "medium";
        evidence.push("Has usage percentage tracking");
        evidence.push("Has defined reset schedule");
      }
    } else if (data.observedBehavior.hasCreditsRemaining) {
      detectedType = "usage_based";
      confidence = "high";
      evidence.push("Tracks remaining credits");
      evidence.push("No percentage-based usage tracking");
    } else if (!data.observedBehavior.hasUsagePercent && !data.observedBehavior.hasCreditsRemaining) {
      detectedType = "enterprise";
      confidence = "medium";
      evidence.push("No visible usage limits");
      evidence.push("May have custom enterprise agreement");
    }

    // Add rate limit behavior analysis
    if (data.observedBehavior.rateLimitBehavior) {
      evidence.push(`Rate limit behavior: ${data.observedBehavior.rateLimitBehavior}`);
    }

    const response = {
      provider: data.provider,
      detectedAccountType: detectedType,
      confidence,
      evidence,
      observedBehavior: data.observedBehavior,
      recommendations: this.getAccountTypeRecommendations(detectedType),
      timestamp: new Date().toISOString(),
    };

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(response, null, 2),
        },
      ],
    };
  }

  /**
   * Generate proactive alerts when approaching reset time with high usage
   * @param args - Reset alert parameters
   * @returns Alert assessment with recommended actions
   */
  async alertApproachingReset(args: unknown) {
    const data = ResetAlertSchema.parse(args);

    const now = Math.floor(Date.now() / 1000);
    const secondsUntilReset = data.nextResetTimestamp - now;
    const hoursUntilReset = secondsUntilReset / 3600;

    // Determine alert level
    let alertLevel: string;
    let priority: string;
    let actions: string[];

    if (data.currentUsage >= 95) {
      alertLevel = "CRITICAL";
      priority = "immediate";
      actions = [
        "URGENT: Stop or significantly reduce usage immediately",
        "Switch to alternative provider for new requests",
        "Cancel non-essential queued operations",
        "Prepare for potential service interruption",
      ];
    } else if (data.currentUsage >= data.alertThreshold) {
      if (hoursUntilReset <= data.hoursBeforeReset / 4) {
        alertLevel = "CRITICAL";
        priority = "urgent";
        actions = [
          "High usage with limited time until reset",
          "Throttle request rate immediately",
          "Activate fallback provider",
          "Monitor usage every 15 minutes",
        ];
      } else if (hoursUntilReset <= data.hoursBeforeReset / 2) {
        alertLevel = "WARNING";
        priority = "high";
        actions = [
          "Usage above threshold with reset approaching",
          "Begin gradual usage reduction",
          "Prepare alternative providers",
          "Schedule non-critical tasks for after reset",
        ];
      } else {
        alertLevel = "CAUTION";
        priority = "medium";
        actions = [
          "Usage above threshold but time remaining",
          "Monitor usage trends closely",
          "Plan usage distribution",
          "Review upcoming workload",
        ];
      }
    } else {
      alertLevel = "NORMAL";
      priority = "low";
      actions = [
        "Usage within safe limits",
        "Continue normal operations",
        "Periodic monitoring recommended",
      ];
    }

    // Calculate projected usage at reset
    const usageMargin = 100 - data.currentUsage;
    const hourlyVelocity = hoursUntilReset > 0
      ? (data.currentUsage / (24 - hoursUntilReset))
      : 0;
    const projectedUsageAtReset = Math.min(100, data.currentUsage + (hourlyVelocity * hoursUntilReset));

    const alert = {
      provider: data.provider,
      alertLevel,
      priority,
      currentStatus: {
        currentUsage: Math.round(data.currentUsage * 10) / 10,
        usageMargin: Math.round(usageMargin * 10) / 10,
        alertThreshold: data.alertThreshold,
      },
      resetInfo: {
        nextResetTime: new Date(data.nextResetTimestamp * 1000).toISOString(),
        hoursUntilReset: Math.round(hoursUntilReset * 10) / 10,
        timeRemaining: this.formatTimeUntil(secondsUntilReset),
      },
      projection: {
        projectedUsageAtReset: Math.round(projectedUsageAtReset * 10) / 10,
        estimatedVelocity: Math.round(hourlyVelocity * 100) / 100 + "% per hour",
        riskLevel: projectedUsageAtReset >= 95 ? "high" : projectedUsageAtReset >= 85 ? "medium" : "low",
      },
      recommendedActions: actions,
      monitoringFrequency: alertLevel === "CRITICAL" ? "every 5 minutes" :
                           alertLevel === "WARNING" ? "every 15 minutes" :
                           alertLevel === "CAUTION" ? "every 30 minutes" : "every hour",
      timestamp: new Date().toISOString(),
    };

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(alert, null, 2),
        },
      ],
    };
  }

  /**
   * Diagnose model-specific performance issues and anomalies
   * @param args - Model diagnostic parameters
   * @returns Performance analysis with issue detection
   */
  async diagnoseModelPerformance(args: unknown) {
    const data = ModelDiagnosticSchema.parse(args);

    const diagnosis: any = {
      model: data.model,
      provider: data.provider,
      timeWindow: `${data.timeWindowHours} hours`,
      timestamp: new Date().toISOString(),
      metrics: {},
      issues: [],
      status: "healthy",
      recommendations: [],
    };

    // Analyze metrics if provided
    if (data.recentMetrics) {
      diagnosis.metrics = {
        latency: data.recentMetrics.avgLatencyMs
          ? {
              value: data.recentMetrics.avgLatencyMs,
              unit: "ms",
              status: this.getLatencyStatus(data.recentMetrics.avgLatencyMs),
            }
          : null,
        errorRate: data.recentMetrics.errorRate
          ? {
              value: (data.recentMetrics.errorRate * 100).toFixed(2) + "%",
              status: this.getErrorRateStatus(data.recentMetrics.errorRate),
            }
          : null,
        throughput: data.recentMetrics.throughput
          ? {
              value: data.recentMetrics.throughput,
              unit: "requests/hour",
            }
          : null,
        costEfficiency: data.recentMetrics.costPerRequest
          ? {
              value: data.recentMetrics.costPerRequest.toFixed(6),
              unit: "USD/request",
              status: this.getCostStatus(data.recentMetrics.costPerRequest),
            }
          : null,
      };

      // Detect issues
      if (data.recentMetrics.avgLatencyMs && data.recentMetrics.avgLatencyMs > 5000) {
        diagnosis.issues.push({
          type: "high_latency",
          severity: "high",
          description: `Average latency ${data.recentMetrics.avgLatencyMs}ms exceeds 5s threshold`,
          possibleCauses: [
            "Provider API experiencing slowdowns",
            "Large context windows causing processing delays",
            "Network connectivity issues",
            "Model overloaded with requests",
          ],
        });
        diagnosis.status = "degraded";
      }

      if (data.recentMetrics.errorRate && data.recentMetrics.errorRate > 0.05) {
        diagnosis.issues.push({
          type: "high_error_rate",
          severity: "critical",
          description: `Error rate ${(data.recentMetrics.errorRate * 100).toFixed(1)}% exceeds 5% threshold`,
          possibleCauses: [
            "Authentication failures",
            "Rate limiting in effect",
            "API service degradation",
            "Invalid request parameters",
          ],
        });
        diagnosis.status = "critical";
      }

      if (data.recentMetrics.costPerRequest && data.recentMetrics.costPerRequest > 0.1) {
        diagnosis.issues.push({
          type: "high_cost",
          severity: "medium",
          description: `Cost per request $${data.recentMetrics.costPerRequest.toFixed(4)} is high`,
          possibleCauses: [
            "Using premium model for simple tasks",
            "Inefficient prompt engineering",
            "Excessive output token generation",
            "Lack of response caching",
          ],
        });
      }

      // Generate recommendations
      diagnosis.recommendations = this.getModelDiagnosticRecommendations(
        diagnosis.issues,
        data.recentMetrics
      );
    } else {
      diagnosis.metrics = null;
      diagnosis.status = "unknown";
      diagnosis.recommendations = ["Provide recent metrics for detailed analysis"];
    }

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(diagnosis, null, 2),
        },
      ],
    };
  }

  // Helper methods

  /**
   * Calculate reset timing statistics from history
   * @private
   */
  private calculateResetTimingStats(history: any[]) {
    if (history.length === 0) {
      return {
        totalRecords: 0,
        message: "No historical data available",
      };
    }

    const drifts = history.map(h => Math.abs(h.drift));
    const avgDrift = drifts.reduce((sum, d) => sum + d, 0) / drifts.length;
    const maxDrift = Math.max(...drifts);
    const accurateCount = drifts.filter(d => d <= 300).length; // Within 5 minutes

    return {
      totalRecords: history.length,
      averageDriftSeconds: Math.round(avgDrift),
      averageDriftMinutes: Math.round((avgDrift / 60) * 10) / 10,
      maxDriftSeconds: Math.round(maxDrift),
      maxDriftMinutes: Math.round((maxDrift / 60) * 10) / 10,
      accuracyRate: ((accurateCount / history.length) * 100).toFixed(1) + "%",
      reliability: accurateCount / history.length >= 0.9 ? "excellent" :
                   accurateCount / history.length >= 0.7 ? "good" :
                   accurateCount / history.length >= 0.5 ? "fair" : "poor",
    };
  }

  /**
   * Format time drift into human-readable string
   * @private
   */
  private formatTimeDrift(driftSeconds: number): string {
    const absDrift = Math.abs(driftSeconds);
    const sign = driftSeconds > 0 ? "late" : "early";

    if (absDrift < 60) {
      return `${Math.round(absDrift)}s ${sign}`;
    } else if (absDrift < 3600) {
      return `${Math.round(absDrift / 60)}m ${sign}`;
    } else {
      return `${Math.round(absDrift / 3600 * 10) / 10}h ${sign}`;
    }
  }

  /**
   * Format time until event
   * @private
   */
  private formatTimeUntil(seconds: number): string {
    if (seconds < 0) return "overdue";
    if (seconds < 60) return `${Math.floor(seconds)} seconds`;
    if (seconds < 3600) return `${Math.floor(seconds / 60)} minutes`;
    if (seconds < 86400) return `${Math.round(seconds / 3600 * 10) / 10} hours`;
    return `${Math.round(seconds / 86400 * 100) / 100} days`;
  }

  /**
   * Get recommendations for reset timing accuracy
   * @private
   */
  private getResetTimingRecommendations(accuracy: string, stats: any): string[] {
    const recommendations = [];

    if (accuracy === "poor" || (stats.reliability && stats.reliability === "poor")) {
      recommendations.push("Reset timing is unreliable - consider manual monitoring");
      recommendations.push("Provider may not have consistent reset schedule");
      recommendations.push("Increase monitoring frequency around expected reset times");
    } else if (accuracy === "acceptable") {
      recommendations.push("Reset timing is generally reliable with some variance");
      recommendations.push("Monitor for drift patterns to improve predictions");
    } else if (accuracy === "accurate") {
      recommendations.push("Reset timing is highly accurate");
      recommendations.push("Safe to rely on predicted reset schedules");
    }

    if (stats.totalRecords && stats.totalRecords < 10) {
      recommendations.push("Limited historical data - continue monitoring to improve accuracy");
    }

    return recommendations;
  }

  /**
   * Get recommendations based on account type
   * @private
   */
  private getAccountTypeRecommendations(accountType: string): string[] {
    const recommendations: Record<string, string[]> = {
      subscription: [
        "Monitor usage percentage to avoid hitting limits",
        "Track reset schedule for usage planning",
        "Consider upgrading if frequently hitting limits",
      ],
      usage_based: [
        "Monitor credit consumption carefully",
        "Set up credit balance alerts",
        "Consider auto-recharge if available",
      ],
      enterprise: [
        "Verify custom rate limits with provider",
        "May have different monitoring requirements",
        "Check enterprise SLA for guaranteed uptime",
      ],
    };

    return recommendations[accountType] || ["Verify account type with provider"];
  }

  /**
   * Get latency status classification
   * @private
   */
  private getLatencyStatus(latencyMs: number): string {
    if (latencyMs < 1000) return "excellent";
    if (latencyMs < 3000) return "good";
    if (latencyMs < 5000) return "acceptable";
    return "poor";
  }

  /**
   * Get error rate status classification
   * @private
   */
  private getErrorRateStatus(errorRate: number): string {
    if (errorRate < 0.01) return "excellent";
    if (errorRate < 0.05) return "good";
    if (errorRate < 0.1) return "acceptable";
    return "poor";
  }

  /**
   * Get cost status classification
   * @private
   */
  private getCostStatus(costPerRequest: number): string {
    if (costPerRequest < 0.01) return "low";
    if (costPerRequest < 0.05) return "moderate";
    if (costPerRequest < 0.1) return "high";
    return "very_high";
  }

  /**
   * Get model diagnostic recommendations
   * @private
   */
  private getModelDiagnosticRecommendations(issues: any[], metrics: any): string[] {
    const recommendations = [];

    const hasLatencyIssue = issues.some(i => i.type === "high_latency");
    const hasErrorIssue = issues.some(i => i.type === "high_error_rate");
    const hasCostIssue = issues.some(i => i.type === "high_cost");

    if (hasLatencyIssue) {
      recommendations.push("Reduce context window size if possible");
      recommendations.push("Consider using faster model variant");
      recommendations.push("Check provider status page for incidents");
      recommendations.push("Implement request timeout and retry logic");
    }

    if (hasErrorIssue) {
      recommendations.push("Verify authentication credentials");
      recommendations.push("Check for rate limiting - may need to throttle requests");
      recommendations.push("Review error logs for specific failure patterns");
      recommendations.push("Implement exponential backoff for retries");
    }

    if (hasCostIssue) {
      recommendations.push("Use cheaper model for simple tasks");
      recommendations.push("Implement response caching");
      recommendations.push("Optimize prompts to reduce token usage");
      recommendations.push("Set max_tokens limits to control costs");
    }

    if (recommendations.length === 0) {
      recommendations.push("Model performance is within normal parameters");
      recommendations.push("Continue current monitoring practices");
    }

    return recommendations;
  }
}
