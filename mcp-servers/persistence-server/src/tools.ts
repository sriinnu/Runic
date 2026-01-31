/**
 * Tool handlers for Persistence Server
 * Implements enhanced tracking capabilities with model, project, and reset schedule support
 */

import Database from "better-sqlite3";
import {
  EnhancedUsageRecordSchema,
  QuerySchema,
  ResetScheduleSchema,
  ModelQuerySchema,
  ProjectQuerySchema,
  type EnhancedUsageRecord,
  type ResetSchedule,
} from "./schemas.js";

export class PersistenceTools {
  constructor(private db: Database.Database) {}

  /**
   * Record enhanced usage data with model, project, and account tracking
   * @param args - Enhanced usage record data
   * @returns Success response with record ID
   */
  async recordEnhancedUsage(args: unknown) {
    const data = EnhancedUsageRecordSchema.parse(args);
    const timestamp = data.timestamp || Math.floor(Date.now() / 1000);

    const stmt = this.db.prepare(`
      INSERT INTO usage_history (
        provider, timestamp, primary_used_percent, secondary_used_percent,
        credits_remaining, input_tokens, output_tokens, cost_usd, model, session_id,
        project_id, account_type, reset_schedule, rate_limit_window
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);

    const result = stmt.run(
      data.provider,
      timestamp,
      data.primaryUsedPercent,
      data.secondaryUsedPercent ?? null,
      data.creditsRemaining ?? null,
      data.inputTokens ?? null,
      data.outputTokens ?? null,
      data.costUSD ?? null,
      data.model ?? null,
      data.sessionId ?? null,
      data.projectId ?? null,
      data.accountType ?? null,
      data.resetSchedule ?? null,
      data.rateLimitWindow ?? null
    );

    // Update model statistics if model data is present
    if (data.model && (data.inputTokens || data.outputTokens || data.costUSD)) {
      this.updateModelStatistics(
        data.model,
        data.provider,
        data.inputTokens ?? 0,
        data.outputTokens ?? 0,
        data.costUSD ?? 0,
        timestamp
      );
    }

    // Update project statistics if project data is present
    if (data.projectId && data.costUSD) {
      this.updateProjectStatistics(
        data.projectId,
        data.provider,
        data.costUSD,
        (data.inputTokens ?? 0) + (data.outputTokens ?? 0),
        timestamp
      );
    }

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify({
            success: true,
            recordId: result.lastInsertRowid,
            message: `Recorded enhanced usage for ${data.provider}${data.model ? ` (${data.model})` : ""}`,
            timestamp: new Date(timestamp * 1000).toISOString(),
          }),
        },
      ],
    };
  }

  /**
   * Query usage history filtered by model name
   * @param args - Model query parameters
   * @returns Filtered usage records for the specified model
   */
  async queryByModel(args: unknown) {
    const query = ModelQuerySchema.parse(args);

    let sql = "SELECT * FROM usage_history WHERE model = ?";
    const params: any[] = [query.model];

    if (query.provider) {
      sql += " AND provider = ?";
      params.push(query.provider);
    }
    if (query.startTime) {
      sql += " AND timestamp >= ?";
      params.push(query.startTime);
    }
    if (query.endTime) {
      sql += " AND timestamp <= ?";
      params.push(query.endTime);
    }

    sql += " ORDER BY timestamp DESC LIMIT ?";
    params.push(query.limit);

    const stmt = this.db.prepare(sql);
    const rows = stmt.all(...params);

    // Get aggregated statistics for this model
    const statsStmt = this.db.prepare(`
      SELECT
        model,
        provider,
        total_input_tokens,
        total_output_tokens,
        total_cost_usd,
        usage_count,
        avg_cost_per_1k_tokens
      FROM model_statistics
      WHERE model = ?
      ${query.provider ? "AND provider = ?" : ""}
    `);

    const stats = query.provider
      ? statsStmt.all(query.model, query.provider)
      : statsStmt.all(query.model);

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify({
            model: query.model,
            provider: query.provider || "all",
            records: rows,
            count: rows.length,
            statistics: stats,
          }, null, 2),
        },
      ],
    };
  }

  /**
   * Query usage history filtered by project ID
   * @param args - Project query parameters
   * @returns Filtered usage records for the specified project
   */
  async queryByProject(args: unknown) {
    const query = ProjectQuerySchema.parse(args);

    let sql = "SELECT * FROM usage_history WHERE project_id = ?";
    const params: any[] = [query.projectId];

    if (query.provider) {
      sql += " AND provider = ?";
      params.push(query.provider);
    }
    if (query.startTime) {
      sql += " AND timestamp >= ?";
      params.push(query.startTime);
    }
    if (query.endTime) {
      sql += " AND timestamp <= ?";
      params.push(query.endTime);
    }

    sql += " ORDER BY timestamp DESC LIMIT ?";
    params.push(query.limit);

    const stmt = this.db.prepare(sql);
    const rows = stmt.all(...params);

    // Get aggregated statistics for this project
    const statsStmt = this.db.prepare(`
      SELECT
        project_id,
        provider,
        total_cost_usd,
        total_tokens,
        usage_count
      FROM project_statistics
      WHERE project_id = ?
      ${query.provider ? "AND provider = ?" : ""}
    `);

    const stats = query.provider
      ? statsStmt.all(query.projectId, query.provider)
      : statsStmt.all(query.projectId);

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify({
            projectId: query.projectId,
            provider: query.provider || "all",
            records: rows,
            count: rows.length,
            statistics: stats,
          }, null, 2),
        },
      ],
    };
  }

  /**
   * Get reset schedules for all providers or upcoming resets
   * @param args - Optional filters
   * @returns List of reset schedules with next reset times
   */
  async getResetSchedule(args: any) {
    const { provider, daysAhead = 7 } = args;
    const now = Math.floor(Date.now() / 1000);
    const futureLimit = now + (daysAhead * 86400);

    let sql = `
      SELECT
        provider,
        reset_type,
        next_reset_timestamp,
        reset_window_minutes,
        timezone,
        is_auto_detected,
        last_updated
      FROM reset_schedules
      WHERE 1=1
    `;
    const params: any[] = [];

    if (provider) {
      sql += " AND provider = ?";
      params.push(provider);
    }

    sql += " AND next_reset_timestamp <= ? ORDER BY next_reset_timestamp ASC";
    params.push(futureLimit);

    const stmt = this.db.prepare(sql);
    const schedules = stmt.all(...params);

    // Calculate time until each reset
    const enrichedSchedules = schedules.map((schedule: any) => {
      const secondsUntilReset = schedule.next_reset_timestamp - now;
      const hoursUntilReset = secondsUntilReset / 3600;
      const daysUntilReset = secondsUntilReset / 86400;

      return {
        ...schedule,
        nextResetTime: new Date(schedule.next_reset_timestamp * 1000).toISOString(),
        timeUntilReset: {
          seconds: secondsUntilReset,
          hours: Math.round(hoursUntilReset * 10) / 10,
          days: Math.round(daysUntilReset * 100) / 100,
          humanReadable: this.formatTimeUntil(secondsUntilReset),
        },
        isAutoDetected: Boolean(schedule.is_auto_detected),
      };
    });

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify({
            currentTime: new Date(now * 1000).toISOString(),
            daysAhead,
            schedules: enrichedSchedules,
            count: enrichedSchedules.length,
          }, null, 2),
        },
      ],
    };
  }

  /**
   * Record or update a reset schedule for a provider
   * @param args - Reset schedule data
   * @returns Success response
   */
  async recordResetSchedule(args: unknown) {
    const schedule = ResetScheduleSchema.parse(args);
    const timestamp = Math.floor(Date.now() / 1000);

    const stmt = this.db.prepare(`
      INSERT OR REPLACE INTO reset_schedules (
        provider, reset_type, next_reset_timestamp, reset_window_minutes,
        timezone, is_auto_detected, last_updated
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
    `);

    stmt.run(
      schedule.provider,
      schedule.resetType,
      schedule.nextResetTimestamp,
      schedule.resetWindowMinutes,
      schedule.timezone,
      schedule.isAutoDetected ? 1 : 0,
      timestamp
    );

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify({
            success: true,
            message: `Reset schedule recorded for ${schedule.provider}`,
            nextReset: new Date(schedule.nextResetTimestamp * 1000).toISOString(),
          }),
        },
      ],
    };
  }

  /**
   * Update model statistics aggregates
   * @private
   */
  private updateModelStatistics(
    model: string,
    provider: string,
    inputTokens: number,
    outputTokens: number,
    costUSD: number,
    timestamp: number
  ): void {
    const totalTokens = inputTokens + outputTokens;
    const avgCostPer1k = totalTokens > 0 ? (costUSD / totalTokens) * 1000 : null;

    this.db.prepare(`
      INSERT INTO model_statistics (
        model, provider, total_input_tokens, total_output_tokens,
        total_cost_usd, usage_count, avg_cost_per_1k_tokens, last_used
      ) VALUES (?, ?, ?, ?, ?, 1, ?, ?)
      ON CONFLICT(model, provider) DO UPDATE SET
        total_input_tokens = total_input_tokens + excluded.total_input_tokens,
        total_output_tokens = total_output_tokens + excluded.total_output_tokens,
        total_cost_usd = total_cost_usd + excluded.total_cost_usd,
        usage_count = usage_count + 1,
        avg_cost_per_1k_tokens = (total_cost_usd + excluded.total_cost_usd) /
          (total_input_tokens + total_output_tokens + excluded.total_input_tokens + excluded.total_output_tokens) * 1000,
        last_used = excluded.last_used
    `).run(model, provider, inputTokens, outputTokens, costUSD, avgCostPer1k, timestamp);
  }

  /**
   * Update project statistics aggregates
   * @private
   */
  private updateProjectStatistics(
    projectId: string,
    provider: string,
    costUSD: number,
    totalTokens: number,
    timestamp: number
  ): void {
    this.db.prepare(`
      INSERT INTO project_statistics (
        project_id, provider, total_cost_usd, total_tokens, usage_count, last_used
      ) VALUES (?, ?, ?, ?, 1, ?)
      ON CONFLICT(project_id, provider) DO UPDATE SET
        total_cost_usd = total_cost_usd + excluded.total_cost_usd,
        total_tokens = total_tokens + excluded.total_tokens,
        usage_count = usage_count + 1,
        last_used = excluded.last_used
    `).run(projectId, provider, costUSD, totalTokens, timestamp);
  }

  /**
   * Format seconds into human-readable time string
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
   * Record usage (legacy method, now redirects to enhanced version)
   * @deprecated Use recordEnhancedUsage instead
   */
  async recordUsage(args: unknown) {
    return this.recordEnhancedUsage(args);
  }

  /**
   * Query usage history with flexible filtering
   */
  async queryHistory(args: unknown) {
    const query = QuerySchema.parse(args);

    let sql = "SELECT * FROM usage_history WHERE 1=1";
    const params: any[] = [];

    if (query.provider) {
      sql += " AND provider = ?";
      params.push(query.provider);
    }
    if (query.model) {
      sql += " AND model = ?";
      params.push(query.model);
    }
    if (query.projectId) {
      sql += " AND project_id = ?";
      params.push(query.projectId);
    }
    if (query.accountType) {
      sql += " AND account_type = ?";
      params.push(query.accountType);
    }
    if (query.startTime) {
      sql += " AND timestamp >= ?";
      params.push(query.startTime);
    }
    if (query.endTime) {
      sql += " AND timestamp <= ?";
      params.push(query.endTime);
    }

    sql += " ORDER BY timestamp DESC LIMIT ?";
    params.push(query.limit);

    const stmt = this.db.prepare(sql);
    const rows = stmt.all(...params);

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify({
            records: rows,
            count: rows.length,
            aggregation: query.aggregation,
            filters: {
              provider: query.provider,
              model: query.model,
              projectId: query.projectId,
              accountType: query.accountType,
            },
          }, null, 2),
        },
      ],
    };
  }

  /**
   * Get usage trends over time
   */
  async getTrends(args: any) {
    const { provider, days = 7, model, projectId } = args;
    const cutoffTime = Math.floor(Date.now() / 1000) - days * 86400;

    let whereClauses = ["timestamp >= ?"];
    const params: any[] = [cutoffTime];

    if (provider) {
      whereClauses.push("provider = ?");
      params.push(provider);
    }
    if (model) {
      whereClauses.push("model = ?");
      params.push(model);
    }
    if (projectId) {
      whereClauses.push("project_id = ?");
      params.push(projectId);
    }

    const whereClause = whereClauses.join(" AND ");

    const stats = this.db.prepare(`
      SELECT
        AVG(primary_used_percent) as avg_usage,
        MAX(primary_used_percent) as peak_usage,
        MIN(primary_used_percent) as min_usage,
        COUNT(*) as sample_count,
        AVG(cost_usd) as avg_cost,
        SUM(cost_usd) as total_cost,
        SUM(input_tokens) as total_input_tokens,
        SUM(output_tokens) as total_output_tokens
      FROM usage_history
      WHERE ${whereClause}
    `).get(...params);

    const daily = this.db.prepare(`
      SELECT
        DATE(timestamp, 'unixepoch') as date,
        AVG(primary_used_percent) as avg_usage,
        MAX(primary_used_percent) as peak_usage,
        SUM(cost_usd) as total_cost,
        COUNT(DISTINCT model) as models_used
      FROM usage_history
      WHERE ${whereClause}
      GROUP BY date
      ORDER BY date
    `).all(...params);

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify({
            provider: provider || "all",
            model: model || "all",
            projectId: projectId || "all",
            period: `${days} days`,
            statistics: stats,
            daily_trends: daily,
          }, null, 2),
        },
      ],
    };
  }

  /**
   * Export data to JSON format
   */
  async exportData(args: any) {
    const { provider, format = "json", includeStats = false } = args;

    let sql = "SELECT * FROM usage_history";
    const params: any[] = [];

    if (provider) {
      sql += " WHERE provider = ?";
      params.push(provider);
    }

    sql += " ORDER BY timestamp DESC";

    const stmt = this.db.prepare(sql);
    const rows = stmt.all(...params);

    const exportData: any = {
      export_format: format,
      record_count: rows.length,
      data: rows,
      exported_at: new Date().toISOString(),
    };

    if (includeStats) {
      exportData.model_statistics = this.db.prepare(
        provider ? "SELECT * FROM model_statistics WHERE provider = ?" : "SELECT * FROM model_statistics"
      ).all(provider ? [provider] : []);

      exportData.project_statistics = this.db.prepare(
        provider ? "SELECT * FROM project_statistics WHERE provider = ?" : "SELECT * FROM project_statistics"
      ).all(provider ? [provider] : []);

      exportData.reset_schedules = this.db.prepare(
        provider ? "SELECT * FROM reset_schedules WHERE provider = ?" : "SELECT * FROM reset_schedules"
      ).all(provider ? [provider] : []);
    }

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(exportData, null, 2),
        },
      ],
    };
  }

  /**
   * Get database statistics
   */
  async getDatabaseStats() {
    const totalRecords = this.db.prepare("SELECT COUNT(*) as count FROM usage_history").get() as any;
    const providers = this.db.prepare("SELECT DISTINCT provider FROM usage_history").all();
    const models = this.db.prepare("SELECT DISTINCT model FROM usage_history WHERE model IS NOT NULL").all();
    const projects = this.db.prepare("SELECT DISTINCT project_id FROM usage_history WHERE project_id IS NOT NULL").all();
    const dateRange = this.db.prepare(`
      SELECT
        MIN(timestamp) as earliest,
        MAX(timestamp) as latest
      FROM usage_history
    `).get() as any;

    const modelStats = this.db.prepare("SELECT COUNT(*) as count FROM model_statistics").get() as any;
    const projectStats = this.db.prepare("SELECT COUNT(*) as count FROM project_statistics").get() as any;
    const resetSchedules = this.db.prepare("SELECT COUNT(*) as count FROM reset_schedules").get() as any;

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify({
            database_version: "2.0.0",
            total_records: totalRecords.count,
            providers: providers.map((p: any) => p.provider),
            unique_models: models.length,
            unique_projects: projects.length,
            date_range: dateRange.earliest && dateRange.latest ? {
              earliest: new Date(dateRange.earliest * 1000).toISOString(),
              latest: new Date(dateRange.latest * 1000).toISOString(),
              span_days: Math.round((dateRange.latest - dateRange.earliest) / 86400),
            } : null,
            aggregates: {
              model_statistics: modelStats.count,
              project_statistics: projectStats.count,
              reset_schedules: resetSchedules.count,
            },
          }, null, 2),
        },
      ],
    };
  }
}
