/**
 * Database management for Persistence Server
 * Handles SQLite database initialization, schema migrations, and data operations
 */

import Database from "better-sqlite3";
import { homedir } from "os";
import { join } from "path";
import { mkdirSync, existsSync } from "fs";

/**
 * Initialize and manage the persistence database
 */
export class PersistenceDatabase {
  private db: Database.Database;
  public readonly dbPath: string;

  constructor() {
    const dataDir = join(homedir(), ".runic", "mcp-data");
    if (!existsSync(dataDir)) {
      mkdirSync(dataDir, { recursive: true });
    }
    this.dbPath = join(dataDir, "persistence.db");
    this.db = new Database(this.dbPath);
    this.initDatabase();
  }

  /**
   * Initialize database schema with enhanced tracking fields
   */
  private initDatabase() {
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS usage_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        provider TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        primary_used_percent REAL NOT NULL,
        secondary_used_percent REAL,
        credits_remaining REAL,
        input_tokens INTEGER,
        output_tokens INTEGER,
        cost_usd REAL,
        model TEXT,
        session_id TEXT,
        -- Enhanced fields
        project_id TEXT,
        account_type TEXT,
        reset_schedule TEXT,
        rate_limit_window INTEGER,
        created_at INTEGER DEFAULT (strftime('%s', 'now'))
      );

      -- Indexes for performance
      CREATE INDEX IF NOT EXISTS idx_provider_timestamp
        ON usage_history(provider, timestamp);

      CREATE INDEX IF NOT EXISTS idx_timestamp
        ON usage_history(timestamp);

      CREATE INDEX IF NOT EXISTS idx_model
        ON usage_history(model);

      CREATE INDEX IF NOT EXISTS idx_project_id
        ON usage_history(project_id);

      CREATE INDEX IF NOT EXISTS idx_account_type
        ON usage_history(account_type);

      -- Provider snapshots table
      CREATE TABLE IF NOT EXISTS provider_snapshots (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        provider TEXT UNIQUE NOT NULL,
        last_snapshot TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      );

      -- Reset schedules table
      CREATE TABLE IF NOT EXISTS reset_schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        provider TEXT UNIQUE NOT NULL,
        reset_type TEXT NOT NULL,
        next_reset_timestamp INTEGER NOT NULL,
        reset_window_minutes INTEGER NOT NULL,
        timezone TEXT NOT NULL DEFAULT 'UTC',
        is_auto_detected INTEGER NOT NULL DEFAULT 0,
        last_updated INTEGER NOT NULL,
        created_at INTEGER DEFAULT (strftime('%s', 'now'))
      );

      CREATE INDEX IF NOT EXISTS idx_reset_next_reset
        ON reset_schedules(next_reset_timestamp);

      -- Metadata table for system information
      CREATE TABLE IF NOT EXISTS metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      );

      -- Model statistics table for aggregated model data
      CREATE TABLE IF NOT EXISTS model_statistics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        model TEXT NOT NULL,
        provider TEXT NOT NULL,
        total_input_tokens INTEGER DEFAULT 0,
        total_output_tokens INTEGER DEFAULT 0,
        total_cost_usd REAL DEFAULT 0,
        usage_count INTEGER DEFAULT 0,
        avg_cost_per_1k_tokens REAL,
        last_used INTEGER,
        created_at INTEGER DEFAULT (strftime('%s', 'now')),
        UNIQUE(model, provider)
      );

      CREATE INDEX IF NOT EXISTS idx_model_stats_model
        ON model_statistics(model);

      CREATE INDEX IF NOT EXISTS idx_model_stats_provider
        ON model_statistics(provider);

      -- Project statistics table
      CREATE TABLE IF NOT EXISTS project_statistics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id TEXT NOT NULL,
        provider TEXT NOT NULL,
        total_cost_usd REAL DEFAULT 0,
        total_tokens INTEGER DEFAULT 0,
        usage_count INTEGER DEFAULT 0,
        last_used INTEGER,
        created_at INTEGER DEFAULT (strftime('%s', 'now')),
        UNIQUE(project_id, provider)
      );

      CREATE INDEX IF NOT EXISTS idx_project_stats_project
        ON project_statistics(project_id);
    `);

    // Set database version
    this.setMetadata("schema_version", "2.0.0");
  }

  /**
   * Get the database instance
   */
  getDatabase(): Database.Database {
    return this.db;
  }

  /**
   * Set metadata key-value pair
   */
  setMetadata(key: string, value: string): void {
    const timestamp = Math.floor(Date.now() / 1000);
    this.db.prepare(`
      INSERT OR REPLACE INTO metadata (key, value, updated_at)
      VALUES (?, ?, ?)
    `).run(key, value, timestamp);
  }

  /**
   * Get metadata value by key
   */
  getMetadata(key: string): string | null {
    const result = this.db.prepare(`
      SELECT value FROM metadata WHERE key = ?
    `).get(key) as { value: string } | undefined;

    return result?.value ?? null;
  }

  /**
   * Close the database connection
   */
  close(): void {
    this.db.close();
  }
}
