#!/usr/bin/env node

/**
 * Runic Persistence Server
 *
 * Embodies PERSISTENCE from the motto: "persistence, intuition, consciousness"
 *
 * Enhanced capabilities:
 * - Model-based usage tracking and analytics
 * - Project-level cost attribution
 * - Account type differentiation (subscription vs usage-based)
 * - Reset schedule tracking across providers
 * - Time-series usage data storage and querying
 * - Cross-session state synchronization
 * - Historical analytics and trends
 * - Data export/import capabilities
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
import { PersistenceDatabase } from "./database.js";
import { PersistenceTools } from "./tools.js";

class PersistenceServer {
  private server: Server;
  private database: PersistenceDatabase;
  private tools: PersistenceTools;

  constructor() {
    this.server = new Server(
      {
        name: "runic-persistence-server",
        version: "2.0.0",
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    // Initialize database and tools
    this.database = new PersistenceDatabase();
    this.tools = new PersistenceTools(this.database.getDatabase());

    this.setupHandlers();
  }

  /**
   * Setup MCP request handlers for tool listing and execution
   */
  private setupHandlers() {
    this.server.setRequestHandler(ListToolsRequestSchema, async () => {
      const tools: Tool[] = [
        {
          name: "record_enhanced_usage",
          description:
            "Record enhanced usage snapshot with model, project, and account type tracking. " +
            "Supports subscription vs usage-based differentiation and reset schedule tracking. " +
            "Automatically updates model and project statistics aggregates.",
          inputSchema: {
            type: "object",
            properties: {
              provider: {
                type: "string",
                description: "Provider name (e.g., 'claude', 'codex', 'openai')",
              },
              primaryUsedPercent: {
                type: "number",
                description: "Primary usage percent (0-100)",
              },
              secondaryUsedPercent: {
                type: "number",
                description: "Secondary usage percent (0-100)",
              },
              creditsRemaining: {
                type: "number",
                description: "Remaining credits",
              },
              inputTokens: {
                type: "number",
                description: "Input tokens used",
              },
              outputTokens: {
                type: "number",
                description: "Output tokens used",
              },
              costUSD: {
                type: "number",
                description: "Cost in USD",
              },
              model: {
                type: "string",
                description: "Model name (e.g., 'claude-3-opus', 'gpt-4')",
              },
              sessionId: {
                type: "string",
                description: "Session identifier",
              },
              projectId: {
                type: "string",
                description: "Project ID for cost attribution",
              },
              accountType: {
                type: "string",
                enum: ["subscription", "usage_based", "enterprise", "free_tier"],
                description: "Account type for tracking billing model",
              },
              resetSchedule: {
                type: "string",
                description: "Next reset timestamp (ISO 8601)",
              },
              rateLimitWindow: {
                type: "number",
                description: "Rate limit window in minutes",
              },
            },
            required: ["provider", "primaryUsedPercent"],
          },
        },
        {
          name: "query_by_model",
          description:
            "Query usage history filtered by model name. Returns all usage records for a specific " +
            "model with optional provider and time range filters. Includes aggregated statistics " +
            "showing total tokens, costs, and usage patterns.",
          inputSchema: {
            type: "object",
            properties: {
              model: {
                type: "string",
                description: "Model name to filter by",
              },
              provider: {
                type: "string",
                description: "Optional provider filter",
              },
              startTime: {
                type: "number",
                description: "Start timestamp (Unix seconds)",
              },
              endTime: {
                type: "number",
                description: "End timestamp (Unix seconds)",
              },
              limit: {
                type: "number",
                description: "Max records to return (default: 100)",
                default: 100,
              },
            },
            required: ["model"],
          },
        },
        {
          name: "query_by_project",
          description:
            "Query usage history filtered by project ID. Returns all usage records for a specific " +
            "project with optional provider and time range filters. Includes aggregated cost and " +
            "token statistics per project.",
          inputSchema: {
            type: "object",
            properties: {
              projectId: {
                type: "string",
                description: "Project ID to filter by",
              },
              provider: {
                type: "string",
                description: "Optional provider filter",
              },
              startTime: {
                type: "number",
                description: "Start timestamp (Unix seconds)",
              },
              endTime: {
                type: "number",
                description: "End timestamp (Unix seconds)",
              },
              limit: {
                type: "number",
                description: "Max records to return (default: 100)",
                default: 100,
              },
            },
            required: ["projectId"],
          },
        },
        {
          name: "get_reset_schedule",
          description:
            "Get reset schedules for providers showing upcoming limit resets. Returns scheduled " +
            "reset times with countdown timers and timezone information. Supports filtering by " +
            "provider and time range (days ahead).",
          inputSchema: {
            type: "object",
            properties: {
              provider: {
                type: "string",
                description: "Optional provider filter",
              },
              daysAhead: {
                type: "number",
                description: "Number of days ahead to show resets (default: 7)",
                default: 7,
              },
            },
          },
        },
        {
          name: "record_reset_schedule",
          description:
            "Record or update a reset schedule for a provider. Tracks when rate limits will reset " +
            "and the reset window duration. Supports daily, weekly, monthly, and rolling reset types.",
          inputSchema: {
            type: "object",
            properties: {
              provider: {
                type: "string",
                description: "Provider name",
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
              resetWindowMinutes: {
                type: "number",
                description: "Reset window duration in minutes",
              },
              timezone: {
                type: "string",
                description: "Timezone (default: UTC)",
                default: "UTC",
              },
              isAutoDetected: {
                type: "boolean",
                description: "Whether schedule was auto-detected",
                default: false,
              },
            },
            required: ["provider", "resetType", "nextResetTimestamp", "resetWindowMinutes"],
          },
        },
        {
          name: "query_usage_history",
          description:
            "Query historical usage data with flexible filtering and aggregation. Supports " +
            "filtering by provider, model, project, account type, and time ranges. Returns " +
            "raw or aggregated data.",
          inputSchema: {
            type: "object",
            properties: {
              provider: { type: "string", description: "Filter by provider" },
              model: { type: "string", description: "Filter by model" },
              projectId: { type: "string", description: "Filter by project ID" },
              accountType: {
                type: "string",
                enum: ["subscription", "usage_based", "enterprise", "free_tier"],
                description: "Filter by account type",
              },
              startTime: { type: "number", description: "Start timestamp (Unix seconds)" },
              endTime: { type: "number", description: "End timestamp (Unix seconds)" },
              limit: { type: "number", description: "Max records to return", default: 100 },
              aggregation: {
                type: "string",
                enum: ["raw", "hourly", "daily", "weekly"],
                description: "Aggregation level",
                default: "raw",
              },
            },
          },
        },
        {
          name: "get_usage_trends",
          description:
            "Analyze usage trends over time with support for model and project filtering. " +
            "Calculates average usage, peak times, growth rates, and cost trends.",
          inputSchema: {
            type: "object",
            properties: {
              provider: { type: "string", description: "Provider to analyze" },
              model: { type: "string", description: "Optional model filter" },
              projectId: { type: "string", description: "Optional project filter" },
              days: { type: "number", description: "Number of days to analyze", default: 7 },
            },
          },
        },
        {
          name: "export_data",
          description:
            "Export usage data to JSON format for backup or migration. Optionally includes " +
            "aggregated statistics for models, projects, and reset schedules.",
          inputSchema: {
            type: "object",
            properties: {
              provider: { type: "string", description: "Filter by provider (optional)" },
              format: { type: "string", enum: ["json", "csv"], default: "json" },
              includeStats: {
                type: "boolean",
                description: "Include model/project statistics",
                default: false,
              },
            },
          },
        },
        {
          name: "get_database_stats",
          description:
            "Get comprehensive database statistics including record counts, unique models/projects, " +
            "date ranges, and aggregate table sizes. Shows database version and health metrics.",
          inputSchema: {
            type: "object",
            properties: {},
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
          case "record_enhanced_usage":
            return await this.tools.recordEnhancedUsage(args);
          case "query_by_model":
            return await this.tools.queryByModel(args);
          case "query_by_project":
            return await this.tools.queryByProject(args);
          case "get_reset_schedule":
            return await this.tools.getResetSchedule(args);
          case "record_reset_schedule":
            return await this.tools.recordResetSchedule(args);

          // Legacy tools (backward compatible)
          case "record_usage":
            return await this.tools.recordUsage(args);
          case "query_usage_history":
            return await this.tools.queryHistory(args);
          case "get_usage_trends":
            return await this.tools.getTrends(args);
          case "export_data":
            return await this.tools.exportData(args);
          case "get_database_stats":
            return await this.tools.getDatabaseStats();

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

  /**
   * Start the MCP server
   */
  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error("Runic Persistence Server v2.0.0 running on stdio");
  }
}

const server = new PersistenceServer();
server.run().catch(console.error);
