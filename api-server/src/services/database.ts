/**
 * Database Service
 *
 * Manages SQLite database operations for storing usage data, alerts, and configurations.
 * Provides a simple interface for CRUD operations and data retrieval.
 *
 * Features:
 * - Usage snapshot storage and retrieval
 * - Alert management
 * - Webhook configuration storage
 * - Historical data tracking
 * - Automatic schema creation and migration
 *
 * @module services/database
 */

import Database from 'better-sqlite3';
import { resolve } from 'path';
import type {
  EnhancedUsageSnapshot,
  UsageAlert,
  WebhookConfig,
  ModelUsageInfo,
  ProjectInfo
} from '../types/index.js';

/**
 * DatabaseService class
 *
 * Handles all database operations for the Runic API server.
 * Uses SQLite for persistent storage with better-sqlite3 for synchronous operations.
 */
export class DatabaseService {
  private db: Database.Database | null;
  private dbPath: string;

  /**
   * Creates a new DatabaseService instance
   *
   * @param dbPath - Path to the SQLite database file (default: ./data/runic.db)
   */
  constructor(dbPath?: string) {
    this.db = null;
    this.dbPath = dbPath || resolve(process.cwd(), 'data', 'runic.db');
  }

  /**
   * Initializes the database connection and creates tables
   */
  public async initialize(): Promise<void> {
    try {
      // Create data directory if it doesn't exist
      const dataDir = resolve(process.cwd(), 'data');
      const fs = await import('fs');
      if (!fs.existsSync(dataDir)) {
        fs.mkdirSync(dataDir, { recursive: true });
      }

      // Open database connection
      this.db = new Database(this.dbPath);
      this.db.pragma('journal_mode = WAL');

      // Create tables
      this.createTables();

      console.log(`Database initialized at ${this.dbPath}`);
    } catch (error) {
      console.error('Failed to initialize database:', error);
      throw error;
    }
  }

  /**
   * Creates database tables if they don't exist
   */
  private createTables(): void {
    if (!this.db) {
      throw new Error('Database not initialized');
    }

    // Usage snapshots table
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS usage_snapshots (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        provider TEXT NOT NULL,
        snapshot TEXT NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE(provider, created_at)
      )
    `);

    // Alerts table
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS alerts (
        id TEXT PRIMARY KEY,
        provider TEXT NOT NULL,
        severity TEXT NOT NULL,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        threshold REAL NOT NULL,
        current_usage REAL NOT NULL,
        recommendation TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    `);

    // Webhooks table
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS webhooks (
        id TEXT PRIMARY KEY,
        url TEXT NOT NULL,
        events TEXT NOT NULL,
        secret TEXT NOT NULL,
        enabled INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )
    `);

    // Models table
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS models (
        model_name TEXT PRIMARY KEY,
        model_family TEXT NOT NULL,
        version TEXT,
        tier TEXT NOT NULL,
        display_name TEXT NOT NULL,
        total_tokens INTEGER DEFAULT 0,
        total_cost REAL DEFAULT 0,
        usage_count INTEGER DEFAULT 0,
        last_used TEXT
      )
    `);

    // Projects table
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS projects (
        project_id TEXT PRIMARY KEY,
        project_name TEXT,
        workspace_path TEXT,
        repository TEXT,
        tags TEXT,
        display_name TEXT NOT NULL,
        total_tokens INTEGER DEFAULT 0,
        total_cost REAL DEFAULT 0,
        request_count INTEGER DEFAULT 0,
        last_active TEXT
      )
    `);

    // Create indices for better query performance
    this.db.exec(`
      CREATE INDEX IF NOT EXISTS idx_usage_provider ON usage_snapshots(provider);
      CREATE INDEX IF NOT EXISTS idx_usage_created_at ON usage_snapshots(created_at);
      CREATE INDEX IF NOT EXISTS idx_alerts_provider ON alerts(provider);
      CREATE INDEX IF NOT EXISTS idx_alerts_severity ON alerts(severity);
      CREATE INDEX IF NOT EXISTS idx_models_last_used ON models(last_used);
      CREATE INDEX IF NOT EXISTS idx_projects_last_active ON projects(last_active);
    `);
  }

  /**
   * Stores a usage snapshot in the database
   *
   * @param snapshot - Enhanced usage snapshot
   */
  public saveUsageSnapshot(snapshot: EnhancedUsageSnapshot): void {
    if (!this.db) {
      throw new Error('Database not initialized');
    }

    const stmt = this.db.prepare(`
      INSERT OR REPLACE INTO usage_snapshots (provider, snapshot, created_at)
      VALUES (?, ?, ?)
    `);

    stmt.run(
      snapshot.provider,
      JSON.stringify(snapshot),
      snapshot.updatedAt
    );
  }

  /**
   * Retrieves the latest usage snapshot for a provider
   *
   * @param provider - Provider identifier
   * @returns Usage snapshot or null if not found
   */
  public getLatestSnapshot(provider: string): EnhancedUsageSnapshot | null {
    if (!this.db) {
      throw new Error('Database not initialized');
    }

    const stmt = this.db.prepare(`
      SELECT snapshot FROM usage_snapshots
      WHERE provider = ?
      ORDER BY created_at DESC
      LIMIT 1
    `);

    const row = stmt.get(provider) as { snapshot: string } | undefined;

    if (!row) {
      return null;
    }

    return JSON.parse(row.snapshot) as EnhancedUsageSnapshot;
  }

  /**
   * Retrieves usage history for a provider
   *
   * @param provider - Provider identifier
   * @param limit - Maximum number of snapshots to return
   * @returns Array of usage snapshots
   */
  public getUsageHistory(provider: string, limit: number = 100): EnhancedUsageSnapshot[] {
    if (!this.db) {
      throw new Error('Database not initialized');
    }

    const stmt = this.db.prepare(`
      SELECT snapshot FROM usage_snapshots
      WHERE provider = ?
      ORDER BY created_at DESC
      LIMIT ?
    `);

    const rows = stmt.all(provider, limit) as { snapshot: string }[];

    return rows.map(row => JSON.parse(row.snapshot) as EnhancedUsageSnapshot);
  }

  /**
   * Stores an alert in the database
   *
   * @param alert - Usage alert
   */
  public saveAlert(alert: UsageAlert): void {
    if (!this.db) {
      throw new Error('Database not initialized');
    }

    const stmt = this.db.prepare(`
      INSERT OR REPLACE INTO alerts (
        id, provider, severity, title, message, threshold,
        current_usage, recommendation, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);

    stmt.run(
      alert.id,
      alert.provider,
      alert.severity,
      alert.title,
      alert.message,
      alert.threshold,
      alert.currentUsage,
      alert.recommendation,
      alert.createdAt
    );
  }

  /**
   * Retrieves all alerts
   *
   * @param limit - Maximum number of alerts to return
   * @returns Array of usage alerts
   */
  public getAlerts(limit: number = 100): UsageAlert[] {
    if (!this.db) {
      throw new Error('Database not initialized');
    }

    const stmt = this.db.prepare(`
      SELECT * FROM alerts
      ORDER BY created_at DESC
      LIMIT ?
    `);

    const rows = stmt.all(limit) as any[];

    return rows.map(row => ({
      id: row.id,
      provider: row.provider,
      severity: row.severity,
      title: row.title,
      message: row.message,
      threshold: row.threshold,
      currentUsage: row.current_usage,
      recommendation: row.recommendation,
      createdAt: row.created_at
    } as UsageAlert));
  }

  /**
   * Stores a webhook configuration in the database
   *
   * @param webhook - Webhook configuration
   */
  public saveWebhook(webhook: WebhookConfig): void {
    if (!this.db) {
      throw new Error('Database not initialized');
    }

    const stmt = this.db.prepare(`
      INSERT OR REPLACE INTO webhooks (id, url, events, secret, enabled, created_at)
      VALUES (?, ?, ?, ?, ?, ?)
    `);

    stmt.run(
      webhook.id,
      webhook.url,
      JSON.stringify(webhook.events),
      webhook.secret,
      webhook.enabled ? 1 : 0,
      webhook.createdAt
    );
  }

  /**
   * Retrieves all webhook configurations
   *
   * @returns Array of webhook configurations
   */
  public getWebhooks(): WebhookConfig[] {
    if (!this.db) {
      throw new Error('Database not initialized');
    }

    const stmt = this.db.prepare('SELECT * FROM webhooks ORDER BY created_at DESC');
    const rows = stmt.all() as any[];

    return rows.map(row => ({
      id: row.id,
      url: row.url,
      events: JSON.parse(row.events),
      secret: row.secret,
      enabled: row.enabled === 1,
      createdAt: row.created_at
    } as WebhookConfig));
  }

  /**
   * Stores or updates model information
   *
   * @param model - Model usage information
   */
  public saveModel(model: ModelUsageInfo): void {
    if (!this.db) {
      throw new Error('Database not initialized');
    }

    const stmt = this.db.prepare(`
      INSERT OR REPLACE INTO models (
        model_name, model_family, version, tier, display_name, last_used
      ) VALUES (?, ?, ?, ?, ?, ?)
    `);

    stmt.run(
      model.modelName,
      model.modelFamily,
      model.version || null,
      model.tier,
      model.displayName,
      new Date().toISOString()
    );
  }

  /**
   * Stores or updates project information
   *
   * @param project - Project information
   */
  public saveProject(project: ProjectInfo): void {
    if (!this.db) {
      throw new Error('Database not initialized');
    }

    const stmt = this.db.prepare(`
      INSERT OR REPLACE INTO projects (
        project_id, project_name, workspace_path, repository,
        tags, display_name, last_active
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
    `);

    stmt.run(
      project.projectID,
      project.projectName || null,
      project.workspacePath || null,
      project.repository || null,
      JSON.stringify(project.tags),
      project.displayName,
      new Date().toISOString()
    );
  }

  /**
   * Deletes old usage snapshots to manage database size
   *
   * @param daysToKeep - Number of days of history to retain (default: 30)
   * @returns Number of snapshots deleted
   */
  public cleanupOldSnapshots(daysToKeep: number = 30): number {
    if (!this.db) {
      throw new Error('Database not initialized');
    }

    const cutoffDate = new Date(Date.now() - daysToKeep * 24 * 60 * 60 * 1000).toISOString();

    const stmt = this.db.prepare(`
      DELETE FROM usage_snapshots
      WHERE created_at < ?
    `);

    const result = stmt.run(cutoffDate);
    return result.changes;
  }

  /**
   * Closes the database connection
   */
  public close(): void {
    if (this.db) {
      this.db.close();
      this.db = null;
      console.log('Database connection closed');
    }
  }

  /**
   * Checks if the database is initialized and ready
   *
   * @returns True if database is ready
   */
  public isReady(): boolean {
    return this.db !== null;
  }
}
