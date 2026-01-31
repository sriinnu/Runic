# Runic Persistence Server

**Version:** 2.0.0

Embodies **PERSISTENCE** from the motto: "persistence, intuition, consciousness"

A Model Context Protocol (MCP) server that provides persistent state management, historical tracking, and data synchronization for Runic usage data.

## Features

### Core Capabilities
- **Time-series usage data storage** with SQLite backend
- **Model-based tracking** for per-model analytics and cost attribution
- **Project-level cost tracking** for multi-project workflows
- **Account type differentiation** (subscription vs usage-based)
- **Reset schedule tracking** across all providers
- **Cross-session state synchronization**
- **Historical analytics and trends**
- **Data export/import** for backup and migration

### Enhanced Features (v2.0.0)
- Model statistics aggregation (total tokens, costs, usage patterns)
- Project statistics aggregation (cost attribution per project)
- Reset schedule management with countdown timers
- Account type tracking for billing model differentiation
- Enhanced querying with multiple filter dimensions

## Installation

```bash
cd mcp-servers/persistence-server
npm install
npm run build
```

## Tools

### 1. `record_enhanced_usage`

Record enhanced usage snapshot with model, project, and account type tracking.

**Parameters:**
- `provider` (string, required): Provider name (e.g., 'claude', 'codex')
- `primaryUsedPercent` (number, required): Primary usage percent (0-100)
- `secondaryUsedPercent` (number, optional): Secondary usage percent
- `creditsRemaining` (number, optional): Remaining credits
- `inputTokens` (number, optional): Input tokens used
- `outputTokens` (number, optional): Output tokens used
- `costUSD` (number, optional): Cost in USD
- `model` (string, optional): Model name (e.g., 'claude-3-opus', 'gpt-4')
- `sessionId` (string, optional): Session identifier
- `projectId` (string, optional): Project ID for cost attribution
- `accountType` (enum, optional): `subscription` | `usage_based` | `enterprise` | `free_tier`
- `resetSchedule` (string, optional): Next reset timestamp (ISO 8601)
- `rateLimitWindow` (number, optional): Rate limit window in minutes

**Example:**
```json
{
  "provider": "claude",
  "primaryUsedPercent": 45.2,
  "inputTokens": 15000,
  "outputTokens": 8000,
  "costUSD": 0.23,
  "model": "claude-3-opus-20240229",
  "projectId": "runic-app",
  "accountType": "subscription"
}
```

**Response:**
```json
{
  "success": true,
  "recordId": 1234,
  "message": "Recorded enhanced usage for claude (claude-3-opus-20240229)",
  "timestamp": "2026-01-31T12:00:00.000Z"
}
```

---

### 2. `query_by_model`

Query usage history filtered by model name with aggregated statistics.

**Parameters:**
- `model` (string, required): Model name to filter by
- `provider` (string, optional): Provider filter
- `startTime` (number, optional): Start timestamp (Unix seconds)
- `endTime` (number, optional): End timestamp (Unix seconds)
- `limit` (number, optional): Max records (default: 100)

**Example:**
```json
{
  "model": "claude-3-opus-20240229",
  "provider": "claude",
  "limit": 50
}
```

**Response:**
```json
{
  "model": "claude-3-opus-20240229",
  "provider": "claude",
  "records": [...],
  "count": 42,
  "statistics": {
    "total_input_tokens": 450000,
    "total_output_tokens": 280000,
    "total_cost_usd": 12.45,
    "usage_count": 156,
    "avg_cost_per_1k_tokens": 0.0171
  }
}
```

---

### 3. `query_by_project`

Query usage history filtered by project ID with cost aggregation.

**Parameters:**
- `projectId` (string, required): Project ID to filter by
- `provider` (string, optional): Provider filter
- `startTime` (number, optional): Start timestamp (Unix seconds)
- `endTime` (number, optional): End timestamp (Unix seconds)
- `limit` (number, optional): Max records (default: 100)

**Example:**
```json
{
  "projectId": "runic-app",
  "limit": 100
}
```

**Response:**
```json
{
  "projectId": "runic-app",
  "provider": "all",
  "records": [...],
  "count": 78,
  "statistics": {
    "total_cost_usd": 45.67,
    "total_tokens": 2340000,
    "usage_count": 234
  }
}
```

---

### 4. `get_reset_schedule`

Get reset schedules showing upcoming limit resets across providers.

**Parameters:**
- `provider` (string, optional): Provider filter
- `daysAhead` (number, optional): Days ahead to show (default: 7)

**Example:**
```json
{
  "daysAhead": 14
}
```

**Response:**
```json
{
  "currentTime": "2026-01-31T12:00:00.000Z",
  "daysAhead": 14,
  "schedules": [
    {
      "provider": "claude",
      "reset_type": "daily",
      "nextResetTime": "2026-02-01T00:00:00.000Z",
      "timeUntilReset": {
        "hours": 12.0,
        "days": 0.5,
        "humanReadable": "12 hours"
      },
      "resetWindowMinutes": 1440,
      "timezone": "UTC",
      "isAutoDetected": true
    }
  ],
  "count": 5
}
```

---

### 5. `record_reset_schedule`

Record or update a reset schedule for a provider.

**Parameters:**
- `provider` (string, required): Provider name
- `resetType` (enum, required): `daily` | `weekly` | `monthly` | `rolling`
- `nextResetTimestamp` (number, required): Next reset time (Unix seconds)
- `resetWindowMinutes` (number, required): Reset window duration
- `timezone` (string, optional): Timezone (default: 'UTC')
- `isAutoDetected` (boolean, optional): Auto-detected flag

**Example:**
```json
{
  "provider": "claude",
  "resetType": "daily",
  "nextResetTimestamp": 1738368000,
  "resetWindowMinutes": 1440,
  "timezone": "UTC",
  "isAutoDetected": true
}
```

---

### 6. `query_usage_history`

Query historical usage data with flexible multi-dimensional filtering.

**Parameters:**
- `provider` (string, optional): Filter by provider
- `model` (string, optional): Filter by model
- `projectId` (string, optional): Filter by project ID
- `accountType` (enum, optional): Filter by account type
- `startTime` (number, optional): Start timestamp
- `endTime` (number, optional): End timestamp
- `limit` (number, optional): Max records (default: 100)
- `aggregation` (enum, optional): `raw` | `hourly` | `daily` | `weekly`

**Example:**
```json
{
  "provider": "claude",
  "accountType": "subscription",
  "startTime": 1738281600,
  "limit": 200
}
```

---

### 7. `get_usage_trends`

Analyze usage trends with model and project filtering support.

**Parameters:**
- `provider` (string, optional): Provider to analyze
- `model` (string, optional): Model filter
- `projectId` (string, optional): Project filter
- `days` (number, optional): Analysis period (default: 7)

**Example:**
```json
{
  "provider": "claude",
  "model": "claude-3-opus-20240229",
  "days": 30
}
```

**Response:**
```json
{
  "provider": "claude",
  "model": "claude-3-opus-20240229",
  "period": "30 days",
  "statistics": {
    "avg_usage": 52.3,
    "peak_usage": 98.5,
    "min_usage": 12.1,
    "total_cost": 156.78,
    "avg_cost": 5.23
  },
  "daily_trends": [...]
}
```

---

### 8. `export_data`

Export usage data to JSON with optional statistics aggregation.

**Parameters:**
- `provider` (string, optional): Provider filter
- `format` (enum, optional): `json` | `csv` (default: 'json')
- `includeStats` (boolean, optional): Include aggregated stats

**Example:**
```json
{
  "format": "json",
  "includeStats": true
}
```

---

### 9. `get_database_stats`

Get comprehensive database statistics and health metrics.

**Example:**
```json
{}
```

**Response:**
```json
{
  "database_version": "2.0.0",
  "total_records": 15234,
  "providers": ["claude", "openai", "codex", "github"],
  "unique_models": 12,
  "unique_projects": 8,
  "date_range": {
    "earliest": "2026-01-01T00:00:00.000Z",
    "latest": "2026-01-31T12:00:00.000Z",
    "span_days": 30
  },
  "aggregates": {
    "model_statistics": 12,
    "project_statistics": 8,
    "reset_schedules": 5
  }
}
```

## Database Schema

### Tables

#### `usage_history`
Primary table for all usage records with enhanced tracking fields.

**Columns:**
- `id` - Auto-increment primary key
- `provider` - Provider name
- `timestamp` - Unix timestamp
- `primary_used_percent` - Primary usage (0-100)
- `secondary_used_percent` - Secondary usage
- `credits_remaining` - Remaining credits
- `input_tokens` - Input tokens
- `output_tokens` - Output tokens
- `cost_usd` - Cost in USD
- `model` - Model name
- `session_id` - Session identifier
- `project_id` - Project ID (new)
- `account_type` - Account type (new)
- `reset_schedule` - Reset schedule timestamp (new)
- `rate_limit_window` - Rate limit window minutes (new)
- `created_at` - Record creation time

**Indexes:**
- `idx_provider_timestamp` - (provider, timestamp)
- `idx_timestamp` - (timestamp)
- `idx_model` - (model)
- `idx_project_id` - (project_id)
- `idx_account_type` - (account_type)

#### `model_statistics`
Aggregated statistics per model and provider.

**Columns:**
- `model`, `provider` - Composite unique key
- `total_input_tokens` - Cumulative input tokens
- `total_output_tokens` - Cumulative output tokens
- `total_cost_usd` - Total cost
- `usage_count` - Number of usages
- `avg_cost_per_1k_tokens` - Average cost efficiency
- `last_used` - Last usage timestamp

#### `project_statistics`
Aggregated statistics per project and provider.

**Columns:**
- `project_id`, `provider` - Composite unique key
- `total_cost_usd` - Total project cost
- `total_tokens` - Total tokens used
- `usage_count` - Number of usages
- `last_used` - Last usage timestamp

#### `reset_schedules`
Reset schedule tracking for providers.

**Columns:**
- `provider` - Provider name (unique)
- `reset_type` - Reset cycle type
- `next_reset_timestamp` - Next reset time
- `reset_window_minutes` - Window duration
- `timezone` - Timezone
- `is_auto_detected` - Auto-detection flag
- `last_updated` - Last update timestamp

## Architecture

```
src/
├── index.ts       # Main server entry point
├── database.ts    # Database initialization and management
├── tools.ts       # Tool handlers and business logic
└── schemas.ts     # Zod validation schemas
```

## Development

```bash
# Watch mode for development
npm run dev

# Build TypeScript
npm run build

# Run server
npm start
```

## Version History

### v2.0.0 (2026-01-31)
- Added model-based tracking and analytics
- Added project-level cost attribution
- Added account type differentiation
- Added reset schedule management
- Enhanced database schema with new tables
- Split code into modular files (database, tools, schemas)
- Added comprehensive JSDoc documentation

### v1.0.0 (2026-01-30)
- Initial release with basic persistence capabilities

## License

Part of the Runic project.
