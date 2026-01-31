# Runic Consciousness Server

**Version:** 2.0.0

Embodies **CONSCIOUSNESS** from the motto: "persistence, intuition, consciousness"

A Model Context Protocol (MCP) server providing real-time monitoring, alerting, and diagnostic capabilities for Runic system health and provider status.

## Features

### Enhanced Capabilities (v2.0.0)
- **Reset timing accuracy monitoring** with drift detection
- **Account type verification** (subscription vs usage-based vs enterprise)
- **Proactive reset approaching alerts** with severity levels
- **Model-specific performance diagnostics** with issue detection
- **Real-time system health monitoring**
- **Provider status page aggregation**
- **Proactive alerting and notifications**
- **System awareness and diagnostics**
- **Cross-provider health dashboard**

## Installation

```bash
cd mcp-servers/consciousness-server
npm install
npm run build
```

## Enhanced Tools

### 1. `monitor_reset_timings`

Monitor reset timing accuracy by comparing expected vs actual reset times.

**Parameters:**
- `provider` (string, required): Provider name
- `expectedResetTime` (number, required): Expected reset time (Unix seconds)
- `actualResetTime` (number, optional): Actual reset time for validation
- `toleranceMinutes` (number, optional): Acceptable drift (default: 5)

**Example:**
```json
{
  "provider": "claude",
  "expectedResetTime": 1738368000,
  "actualResetTime": 1738368120,
  "toleranceMinutes": 5
}
```

**Response:**
```json
{
  "provider": "claude",
  "expectedResetTime": "2026-02-01T00:00:00.000Z",
  "actualResetTime": "2026-02-01T00:02:00.000Z",
  "drift": {
    "seconds": 120,
    "minutes": 2.0,
    "humanReadable": "2m late"
  },
  "accuracy": "accurate",
  "toleranceMinutes": 5,
  "statistics": {
    "totalRecords": 45,
    "averageDriftSeconds": 87,
    "averageDriftMinutes": 1.5,
    "maxDriftSeconds": 285,
    "maxDriftMinutes": 4.8,
    "accuracyRate": "93.3%",
    "reliability": "excellent"
  },
  "recommendations": [
    "Reset timing is highly accurate",
    "Safe to rely on predicted reset schedules"
  ]
}
```

---

### 2. `check_account_type`

Verify and detect account type based on observed behavior patterns.

**Parameters:**
- `provider` (string, required): Provider name
- `observedBehavior` (object, required):
  - `hasUsagePercent` (boolean): Usage tracked as percentage
  - `hasCreditsRemaining` (boolean): Credits tracked
  - `hasResetSchedule` (boolean): Reset schedule exists
  - `rateLimitBehavior` (string, optional): Rate limit behavior

**Example:**
```json
{
  "provider": "claude",
  "observedBehavior": {
    "hasUsagePercent": true,
    "hasCreditsRemaining": false,
    "hasResetSchedule": true,
    "rateLimitBehavior": "rolling"
  }
}
```

**Response:**
```json
{
  "provider": "claude",
  "detectedAccountType": "subscription",
  "confidence": "high",
  "evidence": [
    "Has usage percentage tracking",
    "Has defined reset schedule",
    "Rolling rate limit behavior typical of subscription",
    "Rate limit behavior: rolling"
  ],
  "observedBehavior": {...},
  "recommendations": [
    "Monitor usage percentage to avoid hitting limits",
    "Track reset schedule for usage planning",
    "Consider upgrading if frequently hitting limits"
  ],
  "timestamp": "2026-01-31T12:00:00.000Z"
}
```

---

### 3. `alert_approaching_reset`

Generate proactive alerts when approaching reset time with high usage.

**Parameters:**
- `provider` (string, required): Provider name
- `currentUsage` (number, required): Current usage percent (0-100)
- `nextResetTimestamp` (number, required): Next reset time (Unix seconds)
- `alertThreshold` (number, optional): Usage threshold (default: 85)
- `hoursBeforeReset` (number, optional): Alert window (default: 24)

**Example:**
```json
{
  "provider": "claude",
  "currentUsage": 92.5,
  "nextResetTimestamp": 1738368000,
  "alertThreshold": 85,
  "hoursBeforeReset": 24
}
```

**Response:**
```json
{
  "provider": "claude",
  "alertLevel": "CRITICAL",
  "priority": "urgent",
  "currentStatus": {
    "currentUsage": 92.5,
    "usageMargin": 7.5,
    "alertThreshold": 85
  },
  "resetInfo": {
    "nextResetTime": "2026-02-01T00:00:00.000Z",
    "hoursUntilReset": 8.5,
    "timeRemaining": "8.5 hours"
  },
  "projection": {
    "projectedUsageAtReset": 98.2,
    "estimatedVelocity": "0.67% per hour",
    "riskLevel": "high"
  },
  "recommendedActions": [
    "High usage with limited time until reset",
    "Throttle request rate immediately",
    "Activate fallback provider",
    "Monitor usage every 15 minutes"
  ],
  "monitoringFrequency": "every 15 minutes",
  "timestamp": "2026-01-31T15:30:00.000Z"
}
```

---

### 4. `diagnose_model_performance`

Diagnose model-specific performance issues and anomalies.

**Parameters:**
- `model` (string, required): Model name to diagnose
- `provider` (string, required): Provider name
- `recentMetrics` (object, optional):
  - `avgLatencyMs` (number): Average latency
  - `errorRate` (number): Error rate (0-1)
  - `throughput` (number): Requests per hour
  - `costPerRequest` (number): Average cost (USD)
- `timeWindowHours` (number, optional): Analysis window (default: 24)

**Example:**
```json
{
  "model": "claude-3-opus-20240229",
  "provider": "claude",
  "recentMetrics": {
    "avgLatencyMs": 6500,
    "errorRate": 0.08,
    "throughput": 120,
    "costPerRequest": 0.045
  },
  "timeWindowHours": 24
}
```

**Response:**
```json
{
  "model": "claude-3-opus-20240229",
  "provider": "claude",
  "timeWindow": "24 hours",
  "timestamp": "2026-01-31T12:00:00.000Z",
  "metrics": {
    "latency": {
      "value": 6500,
      "unit": "ms",
      "status": "poor"
    },
    "errorRate": {
      "value": "8.00%",
      "status": "poor"
    },
    "throughput": {
      "value": 120,
      "unit": "requests/hour"
    },
    "costEfficiency": {
      "value": "0.045000",
      "unit": "USD/request",
      "status": "moderate"
    }
  },
  "issues": [
    {
      "type": "high_latency",
      "severity": "high",
      "description": "Average latency 6500ms exceeds 5s threshold",
      "possibleCauses": [
        "Provider API experiencing slowdowns",
        "Large context windows causing processing delays",
        "Network connectivity issues",
        "Model overloaded with requests"
      ]
    },
    {
      "type": "high_error_rate",
      "severity": "critical",
      "description": "Error rate 8.0% exceeds 5% threshold",
      "possibleCauses": [
        "Authentication failures",
        "Rate limiting in effect",
        "API service degradation",
        "Invalid request parameters"
      ]
    }
  ],
  "status": "critical",
  "recommendations": [
    "Reduce context window size if possible",
    "Consider using faster model variant",
    "Check provider status page for incidents",
    "Implement request timeout and retry logic",
    "Verify authentication credentials",
    "Check for rate limiting - may need to throttle requests",
    "Review error logs for specific failure patterns",
    "Implement exponential backoff for retries"
  ]
}
```

## Legacy Tools

The following tools are maintained for backward compatibility:

- `check_provider_health` - Check provider status pages
- `monitor_system_health` - Monitor Runic system health
- `create_alert` - Create proactive alerts
- `get_system_awareness` - Get comprehensive system report
- `diagnose_issues` - Diagnose common issues
- `check_data_freshness` - Check data freshness

## Architecture

```
src/
├── index.ts       # Main server entry point
├── tools.ts       # Enhanced tool handlers
└── schemas.ts     # Zod validation schemas
```

## Alert Levels

### NORMAL
- Usage below alert threshold
- Sufficient time until reset
- **Actions**: Continue normal operations
- **Monitoring**: Every hour

### CAUTION
- Usage above threshold
- Sufficient time remaining
- **Actions**: Monitor trends, plan usage distribution
- **Monitoring**: Every 30 minutes

### WARNING
- Usage above threshold
- Less than 50% time remaining
- **Actions**: Begin usage reduction, prepare alternatives
- **Monitoring**: Every 15 minutes

### CRITICAL
- Usage >= 95% OR high usage with < 25% time remaining
- **Actions**: Immediate throttling or provider switch
- **Monitoring**: Every 5 minutes

## Performance Metrics Classification

### Latency Status
- **Excellent**: < 1000ms
- **Good**: 1000-3000ms
- **Acceptable**: 3000-5000ms
- **Poor**: > 5000ms

### Error Rate Status
- **Excellent**: < 1%
- **Good**: 1-5%
- **Acceptable**: 5-10%
- **Poor**: > 10%

### Cost Status
- **Low**: < $0.01 per request
- **Moderate**: $0.01-$0.05
- **High**: $0.05-$0.10
- **Very High**: > $0.10

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
- Added reset timing accuracy monitoring
- Added account type verification and detection
- Added proactive reset approaching alerts
- Added model-specific performance diagnostics
- Split code into modular files (tools, schemas)
- Added comprehensive JSDoc documentation
- Enhanced with severity levels and monitoring recommendations

### v1.0.0 (2026-01-30)
- Initial release with basic consciousness capabilities

## License

Part of the Runic project.
