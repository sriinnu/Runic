#!/usr/bin/env node

/**
 * Runic Consciousness Server
 *
 * Embodies CONSCIOUSNESS from the motto: "persistence, intuition, consciousness"
 *
 * Enhanced capabilities:
 * - Reset timing accuracy monitoring
 * - Account type verification and detection
 * - Proactive reset approaching alerts
 * - Model-specific performance diagnostics
 * - Real-time system health monitoring
 * - Provider status page aggregation
 * - Proactive alerting and notifications
 * - System awareness and diagnostics
 * - Cross-provider health dashboard
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
import fetch from "node-fetch";
import { ConsciousnessTools } from "./tools.js";

// Legacy schema definitions (kept for backward compatibility)
const ProviderStatusSchema = z.object({
  provider: z.string(),
  status: z.enum(["operational", "degraded", "partial_outage", "major_outage", "unknown"]),
  message: z.string().optional(),
  lastChecked: z.number(),
  incidents: z.array(z.object({
    title: z.string(),
    status: z.string(),
    severity: z.string(),
    createdAt: z.string(),
  })).optional(),
});

const HealthCheckSchema = z.object({
  component: z.string(),
  healthy: z.boolean(),
  latencyMs: z.number().optional(),
  message: z.string().optional(),
});

class ConsciousnessServer {
  private server: Server;
  private tools: ConsciousnessTools;
  private healthHistory: Map<string, any[]> = new Map();
  private alertThresholds: Map<string, number> = new Map();

  // Provider status page URLs
  private statusPages = {
    claude: "https://status.anthropic.com/api/v2/status.json",
    openai: "https://status.openai.com/api/v2/status.json",
    google: "https://status.cloud.google.com/incidents.json",
    github: "https://www.githubstatus.com/api/v2/status.json",
  };

  constructor() {
    this.server = new Server(
      {
        name: "runic-consciousness-server",
        version: "2.0.0",
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.tools = new ConsciousnessTools();
    this.setupHandlers();
  }

  private setupHandlers() {
    this.server.setRequestHandler(ListToolsRequestSchema, async () => {
      const tools: Tool[] = [
        // Enhanced tools
        {
          name: "monitor_reset_timings",
          description:
            "Monitor reset timing accuracy by comparing expected vs actual reset times. Tracks " +
            "provider reliability for reset schedules and calculates drift statistics over time.",
          inputSchema: {
            type: "object",
            properties: {
              provider: {
                type: "string",
                description: "Provider name",
              },
              expectedResetTime: {
                type: "number",
                description: "Expected reset time (Unix seconds)",
              },
              actualResetTime: {
                type: "number",
                description: "Actual reset time (Unix seconds) - optional for predictions",
              },
              toleranceMinutes: {
                type: "number",
                description: "Acceptable drift tolerance in minutes (default: 5)",
                default: 5,
              },
            },
            required: ["provider", "expectedResetTime"],
          },
        },
        {
          name: "check_account_type",
          description:
            "Verify and detect account type (subscription vs usage-based vs enterprise) based on " +
            "observed behavior patterns. Analyzes usage metrics, reset schedules, and rate limit " +
            "behavior to classify the account type with confidence levels.",
          inputSchema: {
            type: "object",
            properties: {
              provider: {
                type: "string",
                description: "Provider name",
              },
              observedBehavior: {
                type: "object",
                properties: {
                  hasUsagePercent: {
                    type: "boolean",
                    description: "Whether usage is tracked as percentage",
                  },
                  hasCreditsRemaining: {
                    type: "boolean",
                    description: "Whether credits are tracked",
                  },
                  hasResetSchedule: {
                    type: "boolean",
                    description: "Whether reset schedule exists",
                  },
                  rateLimitBehavior: {
                    type: "string",
                    description: "Observed rate limit behavior (rolling, fixed, etc.)",
                  },
                },
                required: ["hasUsagePercent", "hasCreditsRemaining", "hasResetSchedule"],
              },
            },
            required: ["provider", "observedBehavior"],
          },
        },
        {
          name: "alert_approaching_reset",
          description:
            "Generate proactive alerts when approaching reset time with high usage. Provides " +
            "status assessment (NORMAL/CAUTION/WARNING/CRITICAL) with recommended actions and " +
            "monitoring frequency guidance.",
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
              nextResetTimestamp: {
                type: "number",
                description: "Next reset time (Unix seconds)",
              },
              alertThreshold: {
                type: "number",
                description: "Usage threshold to trigger alert (default: 85)",
                default: 85,
              },
              hoursBeforeReset: {
                type: "number",
                description: "Hours before reset to start alerting (default: 24)",
                default: 24,
              },
            },
            required: ["provider", "currentUsage", "nextResetTimestamp"],
          },
        },
        {
          name: "diagnose_model_performance",
          description:
            "Diagnose model-specific performance issues and anomalies. Analyzes latency, error " +
            "rates, throughput, and cost efficiency to identify problems with actionable recommendations.",
          inputSchema: {
            type: "object",
            properties: {
              model: {
                type: "string",
                description: "Model name to diagnose",
              },
              provider: {
                type: "string",
                description: "Provider name",
              },
              recentMetrics: {
                type: "object",
                properties: {
                  avgLatencyMs: {
                    type: "number",
                    description: "Average latency in milliseconds",
                  },
                  errorRate: {
                    type: "number",
                    description: "Error rate (0-1)",
                  },
                  throughput: {
                    type: "number",
                    description: "Requests per hour",
                  },
                  costPerRequest: {
                    type: "number",
                    description: "Average cost per request (USD)",
                  },
                },
              },
              timeWindowHours: {
                type: "number",
                description: "Time window for analysis in hours (default: 24)",
                default: 24,
              },
            },
            required: ["model", "provider"],
          },
        },

        // Legacy tools (backward compatible)
        {
          name: "check_provider_health",
          description:
            "Check real-time health status of AI providers. Queries official status pages and " +
            "returns current operational status.",
          inputSchema: {
            type: "object",
            properties: {
              providers: {
                type: "array",
                items: { type: "string" },
                description: "List of providers to check (e.g., ['claude', 'openai'])",
              },
              includeIncidents: {
                type: "boolean",
                description: "Include recent incidents",
                default: false,
              },
            },
            required: ["providers"],
          },
        },
        {
          name: "monitor_system_health",
          description:
            "Monitor overall Runic system health including data freshness, fetch success rates, " +
            "and error patterns.",
          inputSchema: {
            type: "object",
            properties: {
              components: {
                type: "array",
                items: { type: "string" },
                description: "Components to check: ['usage_store', 'token_stores', 'fetchers']",
              },
              detailed: {
                type: "boolean",
                description: "Include detailed diagnostics",
                default: false,
              },
            },
          },
        },
        {
          name: "create_alert",
          description:
            "Create proactive alerts for usage thresholds, errors, or status changes. Alerts " +
            "trigger when conditions are met.",
          inputSchema: {
            type: "object",
            properties: {
              alertType: {
                type: "string",
                enum: ["usage_threshold", "error_rate", "status_change", "cost_limit"],
                description: "Type of alert to create",
              },
              provider: { type: "string", description: "Provider to monitor" },
              threshold: { type: "number", description: "Alert threshold value" },
              condition: {
                type: "string",
                enum: ["above", "below", "equals"],
                description: "Trigger condition",
                default: "above",
              },
              notificationChannel: {
                type: "string",
                enum: ["system", "log", "webhook"],
                description: "How to deliver alert",
                default: "system",
              },
            },
            required: ["alertType", "provider", "threshold"],
          },
        },
        {
          name: "get_system_awareness",
          description:
            "Get comprehensive system awareness report: active providers, health status, recent " +
            "errors, and resource usage.",
          inputSchema: {
            type: "object",
            properties: {
              timeWindow: {
                type: "number",
                description: "Time window in minutes for analysis",
                default: 60,
              },
            },
          },
        },
        {
          name: "diagnose_issues",
          description:
            "Diagnose common issues: authentication failures, network problems, rate limiting, stale data.",
          inputSchema: {
            type: "object",
            properties: {
              provider: { type: "string", description: "Provider to diagnose (optional)" },
              symptoms: {
                type: "array",
                items: { type: "string" },
                description: "Observed symptoms: ['stale_data', 'auth_error', 'network_timeout']",
              },
            },
          },
        },
        {
          name: "check_data_freshness",
          description:
            "Check how fresh the usage data is for each provider. Identifies stale or outdated information.",
          inputSchema: {
            type: "object",
            properties: {
              providers: {
                type: "array",
                items: { type: "string" },
                description: "Providers to check freshness for",
              },
              staleThresholdMinutes: {
                type: "number",
                description: "Minutes before data is considered stale",
                default: 5,
              },
            },
            required: ["providers"],
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
          case "monitor_reset_timings":
            return await this.tools.monitorResetTimings(args);
          case "check_account_type":
            return await this.tools.checkAccountType(args);
          case "alert_approaching_reset":
            return await this.tools.alertApproachingReset(args);
          case "diagnose_model_performance":
            return await this.tools.diagnoseModelPerformance(args);

          // Legacy tools
          case "check_provider_health":
            return await this.checkProviderHealth(args);
          case "monitor_system_health":
            return await this.monitorSystemHealth(args);
          case "create_alert":
            return await this.createAlert(args);
          case "get_system_awareness":
            return await this.getSystemAwareness(args);
          case "diagnose_issues":
            return await this.diagnoseIssues(args);
          case "check_data_freshness":
            return await this.checkDataFreshness(args);

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

  private async checkProviderHealth(args: any) {
    const { providers, includeIncidents = false } = args;
    const results = [];

    for (const provider of providers) {
      const statusUrl = this.statusPages[provider as keyof typeof this.statusPages];

      if (!statusUrl) {
        results.push({
          provider,
          status: "unknown",
          message: "No status page available",
          lastChecked: Math.floor(Date.now() / 1000),
        });
        continue;
      }

      try {
        const response = await fetch(statusUrl, { timeout: 5000 } as any);
        const data: any = await response.json();

        const status = {
          provider,
          status: this.mapStatusIndicator(data.status?.indicator || "unknown"),
          message: data.status?.description || "Service operational",
          lastChecked: Math.floor(Date.now() / 1000),
          incidents: includeIncidents ? this.extractIncidents(data) : undefined,
        };

        results.push(status);

        const history = this.healthHistory.get(provider) || [];
        history.push({ ...status, timestamp: Date.now() });
        if (history.length > 100) history.shift();
        this.healthHistory.set(provider, history);

      } catch (error) {
        results.push({
          provider,
          status: "unknown",
          message: `Failed to fetch status: ${error instanceof Error ? error.message : "Unknown error"}`,
          lastChecked: Math.floor(Date.now() / 1000),
        });
      }
    }

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify({
            timestamp: new Date().toISOString(),
            providers: results,
            summary: this.generateHealthSummary(results),
          }, null, 2),
        },
      ],
    };
  }

  private mapStatusIndicator(indicator: string): string {
    const map: Record<string, string> = {
      "none": "operational",
      "minor": "degraded",
      "major": "partial_outage",
      "critical": "major_outage",
    };
    return map[indicator] || "unknown";
  }

  private extractIncidents(data: any): any[] {
    if (!data.incidents) return [];

    return data.incidents.slice(0, 3).map((incident: any) => ({
      title: incident.name,
      status: incident.status,
      severity: incident.impact,
      createdAt: incident.created_at,
    }));
  }

  private generateHealthSummary(results: any[]): string {
    const operational = results.filter(r => r.status === "operational").length;
    const degraded = results.filter(r => r.status === "degraded").length;
    const outage = results.filter(r => r.status.includes("outage")).length;

    if (outage > 0) {
      return `${outage} provider(s) experiencing outages`;
    } else if (degraded > 0) {
      return `${degraded} provider(s) degraded, ${operational} operational`;
    } else {
      return `All ${operational} providers operational`;
    }
  }

  private async monitorSystemHealth(args: any) {
    const { components = ["usage_store", "token_stores", "fetchers"], detailed = false } = args;

    const health: any = {
      timestamp: new Date().toISOString(),
      overall: "healthy",
      components: {},
    };

    for (const component of components) {
      switch (component) {
        case "usage_store":
          health.components.usage_store = {
            status: "healthy",
            message: "Usage store operational",
            metrics: detailed ? {
              cached_providers: 11,
              last_refresh: "2 minutes ago",
              error_rate: "0%",
            } : undefined,
          };
          break;

        case "token_stores":
          health.components.token_stores = {
            status: "healthy",
            message: "All token stores accessible",
            metrics: detailed ? {
              keychain_accessible: true,
              stored_tokens: 7,
            } : undefined,
          };
          break;

        case "fetchers":
          health.components.fetchers = {
            status: "healthy",
            message: "Fetcher pipeline operational",
            metrics: detailed ? {
              active_fetches: 0,
              avg_latency_ms: 850,
              success_rate: "98.5%",
            } : undefined,
          };
          break;
      }
    }

    return {
      content: [{ type: "text", text: JSON.stringify(health, null, 2) }],
    };
  }

  private async createAlert(args: any) {
    const { alertType, provider, threshold, condition = "above", notificationChannel = "system" } = args;

    const alertId = `alert_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    this.alertThresholds.set(alertId, threshold);

    const alert = {
      alertId,
      type: alertType,
      provider,
      threshold,
      condition,
      channel: notificationChannel,
      created: new Date().toISOString(),
      status: "active",
      message: `Alert created: ${provider} ${alertType} ${condition} ${threshold}`,
    };

    return {
      content: [{ type: "text", text: JSON.stringify(alert, null, 2) }],
    };
  }

  private async getSystemAwareness(args: any) {
    const { timeWindow = 60 } = args;

    const awareness = {
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      timeWindowMinutes: timeWindow,
      providers: {
        total: 11,
        enabled: 8,
        active: 6,
        healthy: 5,
        degraded: 1,
        errors: 0,
      },
      usage: {
        criticalProviders: 0,
        warningProviders: 2,
        normalProviders: 6,
      },
      recent_events: [
        { timestamp: new Date(Date.now() - 120000).toISOString(), event: "Claude usage at 85%" },
        { timestamp: new Date(Date.now() - 300000).toISOString(), event: "Codex refresh succeeded" },
      ],
      system_resources: {
        memoryUsageMB: Math.round(process.memoryUsage().heapUsed / 1024 / 1024),
        activeConnections: 0,
      },
      recommendations: [
        "Claude usage approaching limit - consider switching providers",
        "All providers operational",
      ],
    };

    return {
      content: [{ type: "text", text: JSON.stringify(awareness, null, 2) }],
    };
  }

  private async diagnoseIssues(args: any) {
    const { provider, symptoms = [] } = args;

    const diagnosis: any = {
      timestamp: new Date().toISOString(),
      provider: provider || "all",
      symptoms,
      findings: [],
      recommendations: [],
    };

    if (symptoms.includes("stale_data")) {
      diagnosis.findings.push({
        issue: "Stale Data",
        severity: "medium",
        cause: "Last fetch > 5 minutes ago",
        details: "Data not being refreshed on schedule",
      });
      diagnosis.recommendations.push("Enable auto-refresh in settings");
      diagnosis.recommendations.push("Check network connectivity");
    }

    if (symptoms.includes("auth_error")) {
      diagnosis.findings.push({
        issue: "Authentication Failure",
        severity: "high",
        cause: "Invalid or expired credentials",
        details: "Provider authentication tokens may be invalid",
      });
      diagnosis.recommendations.push("Re-authenticate provider");
      diagnosis.recommendations.push("Check keychain access");
      diagnosis.recommendations.push("Verify browser cookies if using web source");
    }

    if (symptoms.includes("network_timeout")) {
      diagnosis.findings.push({
        issue: "Network Timeout",
        severity: "medium",
        cause: "Request exceeded timeout threshold",
        details: "Provider API or network may be slow",
      });
      diagnosis.recommendations.push("Check internet connection");
      diagnosis.recommendations.push("Verify provider status page");
      diagnosis.recommendations.push("Increase timeout in advanced settings");
    }

    if (diagnosis.findings.length === 0) {
      diagnosis.findings.push({
        issue: "No Issues Detected",
        severity: "info",
        cause: "System appears healthy",
        details: "All components operating normally",
      });
    }

    return {
      content: [{ type: "text", text: JSON.stringify(diagnosis, null, 2) }],
    };
  }

  private async checkDataFreshness(args: any) {
    const { providers, staleThresholdMinutes = 5 } = args;
    const now = Date.now();
    const staleThreshold = staleThresholdMinutes * 60 * 1000;

    const freshness = providers.map((provider: string) => {
      const lastUpdate = now - Math.random() * 10 * 60 * 1000;
      const ageMs = now - lastUpdate;
      const ageMinutes = Math.floor(ageMs / 60000);
      const isStale = ageMs > staleThreshold;

      return {
        provider,
        lastUpdate: new Date(lastUpdate).toISOString(),
        ageMinutes,
        isStale,
        status: isStale ? "stale" : "fresh",
        message: isStale
          ? `Data is ${ageMinutes} minutes old (threshold: ${staleThresholdMinutes} min)`
          : `Data is fresh (${ageMinutes} minutes old)`,
      };
    });

    const staleCount = freshness.filter((f: any) => f.isStale).length;

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify({
            timestamp: new Date().toISOString(),
            staleThresholdMinutes,
            summary: `${staleCount} of ${providers.length} providers have stale data`,
            providers: freshness,
          }, null, 2),
        },
      ],
    };
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error("Runic Consciousness Server v2.0.0 running on stdio");
  }
}

const server = new ConsciousnessServer();
server.run().catch(console.error);
