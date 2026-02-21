# Runic Intuition Server

**Version:** 2.0.0

Embodies **INTUITION** from the motto: "persistence, intuition, consciousness"

A Model Context Protocol (MCP) server providing predictive analytics, intelligent recommendations, and cost optimization for Runic usage patterns.

## Features

### Enhanced Capabilities (v2.0.0)
- **Model-specific cost prediction** with linear regression forecasting
- **Intelligent model recommendations** based on task type and constraints
- **Reset usage prediction** with velocity tracking and status assessment
- **Project-based cost optimization** with savings analysis
- **Usage pattern prediction** and forecasting
- **Smart provider recommendations**
- **Anomaly detection** in usage behavior
- **Proactive limit warnings**

## Installation

```bash
cd mcp-servers/intuition-server
npm install
npm run build
```

## Enhanced Tools

### 1. `predict_model_cost`

Forecast cost per model based on historical usage patterns using linear regression.

**Parameters:**
- `model` (string, required): Model name (e.g., 'claude-3-opus-20240229')
- `provider` (string, optional): Provider name
- `historicalUsage` (array, optional): Historical usage records
  - `timestamp` (number): Unix timestamp
  - `inputTokens` (number): Input tokens used
  - `outputTokens` (number): Output tokens used
  - `costUSD` (number): Cost in USD
- `forecastDays` (number, optional): Days to forecast (default: 7)

**Example:**
```json
{
  "model": "claude-3-opus-20240229",
  "provider": "claude",
  "historicalUsage": [
    {
      "timestamp": 1738195200,
      "inputTokens": 15000,
      "outputTokens": 8000,
      "costUSD": 0.825
    },
    {
      "timestamp": 1738281600,
      "inputTokens": 18000,
      "outputTokens": 9500,
      "costUSD": 0.9825
    }
  ],
  "forecastDays": 7
}
```

**Response:**
```json
{
  "model": "claude-3-opus-20240229",
  "provider": "claude",
  "forecastPeriod": "7 days",
  "historical": {
    "avgDailyCost": "0.9038",
    "stdDeviation": "0.0788",
    "totalCost": "1.8075",
    "totalTokens": 50500,
    "avgCostPer1kTokens": "0.035792",
    "dataPoints": 2
  },
  "forecast": [
    { "day": 1, "date": "2026-02-01", "predictedCost": "0.9200" },
    { "day": 2, "date": "2026-02-02", "predictedCost": "0.9350" }
  ],
  "projectedTotalCost": "6.5450",
  "trend": "increasing",
  "confidence": "medium",
  "recommendations": [
    "Cost is increasing - investigate usage patterns",
    "Using premium model - consider cheaper alternatives for simpler tasks"
  ]
}
```

---

### 2. `recommend_model`

Recommend the cheapest model for a given task type with detailed cost analysis.

**Parameters:**
- `taskType` (enum, required): `coding` | `chat` | `analysis` | `documentation` | `testing`
- `maxCostPerRequest` (number, optional): Maximum cost per request (USD)
- `preferredProviders` (array, optional): Preferred provider list
- `requiredCapabilities` (array, optional): Required model capabilities
- `contextWindowMin` (number, optional): Minimum context window size

**Example:**
```json
{
  "taskType": "coding",
  "maxCostPerRequest": 0.05,
  "contextWindowMin": 100000
}
```

**Response:**
```json
{
  "taskType": "coding",
  "recommendedModel": "claude-3-sonnet-20240229",
  "reasoning": "claude-3-sonnet-20240229 is recommended because it is highly suitable for coding tasks, cost-effective, large context window.",
  "topChoices": [
    {
      "model": "claude-3-sonnet-20240229",
      "score": 85.0,
      "pricing": {
        "inputCostPer1k": 0.003,
        "outputCostPer1k": 0.015,
        "contextWindow": 200000
      },
      "suitability": "high",
      "estimatedCostPer1kTokens": "0.009000"
    }
  ],
  "costComparison": {
    "cheapest": "claude-3-haiku-20240307",
    "mostExpensive": "claude-3-opus-20240229",
    "costRatio": "40.00"
  },
  "constraints": {
    "maxCostPerRequest": 0.05,
    "contextWindowMin": 100000
  }
}
```

---

### 3. `predict_reset_usage`

Forecast usage at next reset time with velocity tracking and status assessment.

**Parameters:**
- `provider` (string, required): Provider name
- `currentUsage` (number, required): Current usage percent (0-100)
- `resetType` (enum, required): `daily` | `weekly` | `monthly` | `rolling`
- `nextResetTimestamp` (number, required): Next reset time (Unix seconds)
- `recentVelocity` (array, optional): Recent usage velocity (percent per hour)

**Example:**
```json
{
  "provider": "claude",
  "currentUsage": 75.5,
  "resetType": "daily",
  "nextResetTimestamp": 1738368000,
  "recentVelocity": [2.1, 2.3, 1.9, 2.0]
}
```

**Response:**
```json
{
  "provider": "claude",
  "resetType": "daily",
  "currentUsage": 75.5,
  "projectedUsageAtReset": 91.2,
  "usageMargin": 8.8,
  "status": "CAUTION",
  "timeUntilReset": {
    "hours": 7.5,
    "minutes": 450,
    "humanReadable": "7.5 hours",
    "nextResetTime": "2026-02-01T00:00:00.000Z"
  },
  "velocity": {
    "percentPerHour": 2.08,
    "basedOn": "historical_data",
    "confidence": "high"
  },
  "recommendations": [
    "Usage trending high but manageable",
    "Monitor for unexpected spikes",
    "Plan usage distribution for remaining time"
  ]
}
```

---

### 4. `optimize_by_project`

Analyze and optimize costs for a specific project with savings projections and actionable alerts.

**Parameters:**
- `projectId` (string, required): Project identifier
- `providers` (array, required): Usage data per provider
  - `provider` (string): Provider name
  - `model` (string, optional): Model name
  - `totalCost` (number): Total cost
  - `totalTokens` (number): Total tokens used
  - `usagePercent` (number, optional): Usage percent
- `targetCostReduction` (number, optional): Target reduction percentage (0-100)
- `days` (number, optional): Analysis period in days (default: 7)

**Example:**
```json
{
  "projectId": "runic-app",
  "providers": [
    {
      "provider": "claude",
      "model": "claude-3-opus-20240229",
      "totalCost": 45.67,
      "totalTokens": 1200000
    },
    {
      "provider": "openai",
      "model": "gpt-4-turbo",
      "totalCost": 23.45,
      "totalTokens": 1500000
    }
  ],
  "targetCostReduction": 20,
  "days": 7
}
```

**Response:**
```json
{
  "projectId": "runic-app",
  "analysisPeriod": "7 days",
  "summary": {
    "totalCost": "69.1200",
    "totalTokens": 2700000,
    "avgCostPer1kTokens": "0.025600",
    "providers": 2
  },
  "efficiency": {
    "mostEfficient": {
      "provider": "openai",
      "model": "gpt-4-turbo",
      "costPerToken": "0.00001563"
    },
    "leastEfficient": {
      "provider": "claude",
      "model": "claude-3-opus-20240229",
      "costPerToken": "0.00003806"
    },
    "efficiencyGap": "2.43x"
  },
  "potentialSavings": {
    "amount": "26.9200",
    "percentage": "38.9%",
    "achievableWith": "Migrating all usage to openai"
  },
  "alerts": [
    {
      "level": "critical",
      "message": "39% potential cost savings identified",
      "action": "Switch to openai for immediate cost reduction"
    },
    {
      "level": "warning",
      "message": "2.4x efficiency gap between providers",
      "action": "Prioritize migrating from claude to openai"
    }
  ],
  "providerBreakdown": [...],
  "optimizationStrategies": [
    {
      "strategy": "Migrate from claude to openai",
      "impact": "high",
      "difficulty": "medium"
    },
    {
      "strategy": "Use cheaper models for simple tasks, reserve premium models for complex work",
      "impact": "high",
      "difficulty": "medium"
    }
  ],
  "recommendations": [
    "Prioritize openai (gpt-4-turbo) for new requests",
    "Monitor usage patterns to identify opportunities for model switching",
    "Significant savings possible - prioritize optimization"
  ]
}
```

---

### 5. `compare_model_costs`

Compare costs across multiple AI models and rank by cost efficiency.

**Parameters:**
- `models` (array, required): List of model names to compare (minimum 2)
- `taskType` (enum, required): `coding` | `writing` | `analysis` | `general`
- `historicalUsage` (array, optional): Historical usage data for accuracy
  - `model` (string): Model name
  - `inputTokens` (number): Input tokens used
  - `outputTokens` (number): Output tokens used
  - `cost` (number): Cost in USD

**Example:**
```json
{
  "models": [
    "claude-3-opus-20240229",
    "claude-3-sonnet-20240229",
    "claude-3-haiku-20240307",
    "gpt-4-turbo"
  ],
  "taskType": "coding",
  "historicalUsage": [
    {
      "model": "claude-3-opus-20240229",
      "inputTokens": 10000,
      "outputTokens": 5000,
      "cost": 0.525
    }
  ]
}
```

**Response:**
```json
{
  "taskType": "coding",
  "modelsCompared": 4,
  "cheapest": {
    "model": "claude-3-haiku-20240307",
    "costPerToken": "0.00075000",
    "suitability": "medium"
  },
  "mostExpensive": {
    "model": "claude-3-opus-20240229",
    "costPerToken": "0.04500000",
    "suitability": "high"
  },
  "costRange": {
    "min": "0.00075000",
    "max": "0.04500000",
    "spread": "60.00x"
  },
  "models": [
    {
      "model": "claude-3-haiku-20240307",
      "pricing": {
        "inputCostPer1M": "0.25",
        "outputCostPer1M": "1.25",
        "avgCostPerToken": "0.00075000",
        "contextWindow": 200000
      },
      "historicalCostPerToken": null,
      "taskSuitability": "medium",
      "costPerToken": "0.00075000",
      "costRatio": "1.00x",
      "costDifferencePer1MTokens": "0.00",
      "recommendation": "Most cost-effective option for coding"
    },
    {
      "model": "claude-3-sonnet-20240229",
      "costPerToken": "0.00900000",
      "costRatio": "12.00x",
      "recommendation": "Good balance of capability and cost for coding"
    }
  ],
  "overallRecommendation": "For coding tasks, claude-3-haiku-20240307 offers the best cost efficiency. For optimal performance, consider claude-3-sonnet-20240229 (high suitability)."
}
```

---

### 6. `detect_usage_anomaly`

Detect unusual usage patterns using Z-score statistical analysis.

**Parameters:**
- `hourlyUsage` (array, required): Hourly usage data (minimum 3 hours)
  - `hour` (string): Hour timestamp (ISO 8601 or custom format)
  - `tokens` (number): Total tokens used in this hour
  - `cost` (number): Total cost in this hour (USD)
- `threshold` (number, optional): Detection threshold in standard deviations (default: 2.5)

**Example:**
```json
{
  "hourlyUsage": [
    { "hour": "2024-01-01T00:00:00Z", "tokens": 10000, "cost": 0.05 },
    { "hour": "2024-01-01T01:00:00Z", "tokens": 10200, "cost": 0.051 },
    { "hour": "2024-01-01T02:00:00Z", "tokens": 10100, "cost": 0.0505 },
    { "hour": "2024-01-01T03:00:00Z", "tokens": 80000, "cost": 0.40 },
    { "hour": "2024-01-01T04:00:00Z", "tokens": 10050, "cost": 0.05025 }
  ],
  "threshold": 2.5
}
```

**Response:**
```json
{
  "period": {
    "hours": 5,
    "from": "2024-01-01T00:00:00Z",
    "to": "2024-01-01T04:00:00Z"
  },
  "baseline": {
    "avgTokensPerHour": 24070,
    "avgCostPerHour": "0.1203",
    "tokenStdDev": 28267,
    "costStdDev": "0.1413"
  },
  "threshold": {
    "value": 2.5,
    "description": "2.5 standard deviations from mean"
  },
  "anomalyCount": 1,
  "anomaliesDetected": true,
  "anomalies": [
    {
      "hour": "2024-01-01T03:00:00Z",
      "tokens": 80000,
      "cost": 0.40,
      "tokenZScore": 2.65,
      "costZScore": 2.65,
      "severity": "high",
      "message": "Significant anomaly detected - review usage patterns - tokens 325% above average"
    }
  ],
  "recommendations": [
    "1 significant anomaly detected - review usage patterns",
    "High token usage detected during: 2024-01-01T03:00:00Z",
    "Review expensive operations during peak anomaly periods",
    "Set up alerts for anomalies to catch issues in real-time"
  ],
  "summary": "1 anomaly detected - review recommended"
}
```

## Legacy Tools

The following tools are maintained for backward compatibility:

- `predict_usage_limit` - Predict when provider hits rate limits
- `recommend_provider` - Recommend optimal provider
- `detect_usage_anomaly` - Detect unusual usage patterns
- `optimize_cost` - Analyze cost patterns
- `forecast_reset_timing` - Predict optimal reset timing

## Architecture

```
src/
├── index.ts       # Main server entry point
├── tools.ts       # Enhanced tool handlers
└── schemas.ts     # Zod validation schemas
```

## Model Pricing Database

The server maintains pricing information for common models:

| Model | Input (per 1k) | Output (per 1k) | Context Window |
|-------|----------------|-----------------|----------------|
| claude-3-opus | $0.015 | $0.075 | 200k |
| claude-3-sonnet | $0.003 | $0.015 | 200k |
| claude-3-haiku | $0.00025 | $0.00125 | 200k |
| gpt-4-turbo | $0.01 | $0.03 | 128k |
| gpt-4 | $0.03 | $0.06 | 8k |
| gpt-3.5-turbo | $0.0005 | $0.0015 | 16k |

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

### v2.1.0 (2026-01-31)
- **NEW:** Added `compare_model_costs` tool for cost comparison and ranking
- **NEW:** Added `detect_usage_anomaly` tool with Z-score statistical analysis
- **ENHANCED:** Updated `optimize_by_project` to include actionable alerts
- Added support for `writing` and `general` task types
- Improved anomaly detection with severity levels (critical/high/medium/low)
- Added comprehensive test suite

### v2.0.0 (2026-01-31)
- Added model-specific cost prediction
- Added intelligent model recommendations by task type
- Added reset usage prediction with velocity tracking
- Added project-based cost optimization
- Split code into modular files (tools, schemas)
- Added comprehensive JSDoc documentation

### v1.0.0 (2026-01-30)
- Initial release with basic intuition capabilities

## License

Part of the Runic project.
