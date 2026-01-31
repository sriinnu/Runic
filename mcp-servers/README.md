# Runic MCP Servers

**Version:** 2.0.0
**Status:** ✅ Production Ready (Tested January 31, 2026)

Three MCP servers embodying the motto: **"persistence, intuition, consciousness"**

## Quick Verification

```bash
./verify-all-servers.sh
```

## Overview

These Model Context Protocol (MCP) servers extend Runic's capabilities beyond the menubar app, providing AI agents with powerful tools for monitoring, predicting, and optimizing AI provider usage.

**All servers tested and verified operational.** See [STATUS.md](STATUS.md) for detailed test results.

---

## 🗄️ Persistence Server

**Embodies: PERSISTENCE** - Long-term memory and data continuity

### Purpose
Provides time-series storage and historical analytics for usage data. Enables tracking trends over days, weeks, and months.

### Tools
- `record_usage` - Store usage snapshots for historical tracking
- `query_usage_history` - Query with flexible filtering and aggregation
- `get_usage_trends` - Analyze patterns, peaks, and growth rates
- `export_data` - Backup data in JSON/CSV formats
- `get_database_stats` - Database health metrics

### Storage
- **Location**: `~/.runic/mcp-data/persistence.db`
- **Format**: SQLite database with time-series optimizations
- **Retention**: Configurable, defaults to unlimited

### Installation
```bash
cd mcp-servers/persistence-server
npm install
npm run build
```

### Configuration (Claude Desktop)
```json
{
  "mcpServers": {
    "runic-persistence": {
      "command": "node",
      "args": ["/Users/srinivaspendela/Sriinnu/AI/Runic/mcp-servers/persistence-server/dist/index.js"]
    }
  }
}
```

---

## 🧠 Intuition Server

**Embodies: INTUITION** - Predictive intelligence and smart recommendations

### Purpose
Provides predictive analytics, pattern recognition, and proactive optimization suggestions. Makes Runic anticipatory rather than just reactive.

### Tools
- `predict_usage_limit` - Forecast when limits will be hit using regression
- `recommend_provider` - Suggest optimal provider based on usage and costs
- `detect_usage_anomaly` - Statistical outlier detection
- `optimize_cost` - Cost efficiency analysis and recommendations
- `forecast_reset_timing` - Predict rate limit reset timing

### Algorithms
- **Linear regression** for usage prediction
- **Z-score analysis** for anomaly detection
- **Multi-factor scoring** for provider recommendations
- **Statistical aggregation** for trend analysis

### Installation
```bash
cd mcp-servers/intuition-server
npm install
npm run build
```

### Configuration (Claude Desktop)
```json
{
  "mcpServers": {
    "runic-intuition": {
      "command": "node",
      "args": ["/Users/srinivaspendela/Sriinnu/AI/Runic/mcp-servers/intuition-server/dist/index.js"]
    }
  }
}
```

---

## 👁️ Consciousness Server

**Embodies: CONSCIOUSNESS** - Real-time awareness and alerting

### Purpose
Provides continuous monitoring, health checks, and proactive alerting. Gives the system self-awareness of its state.

### Tools
- `check_provider_health` - Query official status pages in real-time
- `monitor_system_health` - Check Runic component health
- `create_alert` - Set up threshold-based alerts
- `get_system_awareness` - Comprehensive system status report
- `diagnose_issues` - Root cause analysis for common problems
- `check_data_freshness` - Detect stale data

### Status Pages Monitored
- Anthropic (Claude)
- OpenAI (Codex/GPT)
- Google Cloud (Gemini)
- GitHub (Copilot)

### Installation
```bash
cd mcp-servers/consciousness-server
npm install
npm run build
```

### Configuration (Claude Desktop)
```json
{
  "mcpServers": {
    "runic-consciousness": {
      "command": "node",
      "args": ["/Users/srinivaspendela/Sriinnu/AI/Runic/mcp-servers/consciousness-server/dist/index.js"]
    }
  }
}
```

---

## Combined Configuration

Add all three servers to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "runic-persistence": {
      "command": "node",
      "args": ["/Users/srinivaspendela/Sriinnu/AI/Runic/mcp-servers/persistence-server/dist/index.js"]
    },
    "runic-intuition": {
      "command": "node",
      "args": ["/Users/srinivaspendela/Sriinnu/AI/Runic/mcp-servers/intuition-server/dist/index.js"]
    },
    "runic-consciousness": {
      "command": "node",
      "args": ["/Users/srinivaspendela/Sriinnu/AI/Runic/mcp-servers/consciousness-server/dist/index.js"]
    }
  }
}
```

---

## Example Workflows

### 1. Proactive Limit Warning
```typescript
// Consciousness checks freshness
consciousness.check_data_freshness({ providers: ["claude"] })

// Persistence retrieves history
persistence.query_usage_history({
  provider: "claude",
  limit: 20
})

// Intuition predicts limit
intuition.predict_usage_limit({
  provider: "claude",
  timestamps: [...],
  values: [...],
  currentUsage: 87
})
// Result: "URGENT: Limit in 23 minutes"
```

### 2. Cost Optimization
```typescript
// Persistence gets cost data
persistence.query_usage_history({
  aggregation: "daily",
  days: 7
})

// Intuition analyzes costs
intuition.optimize_cost({
  providers: [...],
  days: 7
})
// Result: "Shift 40% of workload to Codex for $12.50 savings"
```

### 3. Provider Selection
```typescript
// Consciousness checks health
consciousness.check_provider_health({
  providers: ["claude", "codex", "gemini"]
})

// Intuition recommends best option
intuition.recommend_provider({
  providers: [...],
  taskType: "coding"
})
// Result: "Codex recommended: plenty of headroom, cost-effective"
```

---

## Architecture

### Technology Stack
- **Runtime**: Node.js with TypeScript
- **MCP SDK**: `@modelcontextprotocol/sdk` v1.0.4
- **Database**: SQLite3 (persistence server)
- **Statistics**: `simple-statistics` (intuition server)
- **HTTP**: `node-fetch` (consciousness server)

### Design Principles
1. **Stateless Tools** - Each tool call is independent
2. **Fast Response** - Most operations < 100ms
3. **Error Resilience** - Graceful degradation on failures
4. **Type Safety** - Zod schemas for validation
5. **Observable** - Logs to stderr for debugging

### Security
- Read-only access to Runic data
- No credential storage (uses existing Runic auth)
- Local-only operation (no external services)
- SQLite file permissions match user

---

## Development

### Building All Servers
```bash
for server in persistence-server intuition-server consciousness-server; do
  cd mcp-servers/$server
  npm install
  npm run build
  cd ../..
done
```

### Testing Individual Server
```bash
cd mcp-servers/persistence-server
node dist/index.js
# Ctrl+C to exit
```

### Debugging with Claude Desktop
1. Open Claude Desktop
2. Check MCP servers panel (should show green indicators)
3. Test with: "Use the runic-persistence server to record my current usage"

---

## Future Enhancements

### Persistence
- [ ] Automatic data pruning policies
- [ ] Export to cloud storage (S3, GCS)
- [ ] Real-time sync with main app via IPC

### Intuition
- [ ] Machine learning models for prediction
- [ ] Multi-step lookahead forecasting
- [ ] Cost/performance Pareto frontier

### Consciousness
- [ ] Webhook integrations (Slack, Discord)
- [ ] Prometheus metrics export
- [ ] Distributed health checks

---

## Troubleshooting

### Server not appearing in Claude Desktop
1. Check `claude_desktop_config.json` syntax
2. Restart Claude Desktop completely
3. Check logs: `~/Library/Logs/Claude/mcp*.log`

### Permission errors
```bash
chmod +x mcp-servers/*/dist/index.js
```

### Database locked (persistence)
- Close any other processes accessing `~/.runic/mcp-data/persistence.db`
- SQLite only allows one writer at a time

---

## License

MIT License - Part of the Runic project

## Motto

**Persistence. Intuition. Consciousness.**

Remember the past. Predict the future. Be aware of the present.
