# Runic REST API Server

**Purpose**: Expose Runic usage data for AI assistant apps and external integrations.

This API server provides real-time access to:
- Provider usage snapshots with reset timings
- Model usage breakdown
- Project-based tracking
- Cost analytics
- Proactive alerts
- Historical trends

---

## Quick Start

```bash
cd api-server
npm install
npm run build
npm start
```

Server runs on `http://localhost:3000` by default.

---

## API Endpoints

### Core Usage Data

#### `GET /api/v1/providers`
Get list of all monitored providers.

**Response:**
```json
{
  "providers": ["claude", "codex", "gemini", ...],
  "count": 11
}
```

---

#### `GET /api/v1/usage`
Get current usage snapshots for all providers.

**Query Parameters:**
- `provider` (optional) - Filter by provider name
- `includeModels` (optional) - Include model breakdown
- `includeProjects` (optional) - Include project association

**Response:**
```json
{
  "timestamp": "2026-01-31T10:30:00Z",
  "snapshots": [
    {
      "provider": "claude",
      "accountType": "subscription",
      "accountEmail": "user@example.com",
      "primary": {
        "usedPercent": 85.5,
        "windowMinutes": 300,
        "resetsAt": "2026-01-31T14:00:00Z",
        "resetDescription": "Resets in 3h 30m"
      },
      "primaryReset": {
        "resetType": "sessionBased",
        "resetAt": "2026-01-31T14:00:00Z",
        "windowDuration": 18000,
        "resetsAutomatically": true,
        "timeUntilReset": 12600
      },
      "primaryModel": {
        "modelName": "claude-3-5-sonnet-20241022",
        "modelFamily": "claude-3",
        "tier": "sonnet",
        "version": "20241022"
      },
      "recentModels": [...],
      "activeProject": {
        "projectID": "runic-ios",
        "projectName": "Runic iOS App",
        "workspacePath": "/Users/.../RuniciOS"
      },
      "tokenUsage": {
        "inputTokens": 1250000,
        "outputTokens": 450000,
        "cacheCreationTokens": 50000,
        "cacheReadTokens": 200000,
        "totalTokens": 1950000,
        "modelBreakdown": {
          "claude-opus-4": 500000,
          "claude-sonnet-3.5": 1450000
        }
      },
      "estimatedCost": 12.50,
      "updatedAt": "2026-01-31T10:30:00Z",
      "fetchSource": "oauth"
    }
  ]
}
```

---

#### `GET /api/v1/usage/:provider`
Get detailed usage for a specific provider.

**Response:** Single snapshot object (see above).

---

### Model Tracking

#### `GET /api/v1/models`
Get model usage breakdown across all providers.

**Query Parameters:**
- `provider` (optional) - Filter by provider
- `days` (optional, default: 7) - Time range
- `groupBy` (optional) - Group by "provider", "model", or "tier"

**Response:**
```json
{
  "period": "7 days",
  "models": [
    {
      "modelName": "claude-3-5-sonnet-20241022",
      "provider": "claude",
      "tier": "sonnet",
      "totalTokens": 1950000,
      "totalCost": 12.50,
      "requestCount": 458,
      "avgTokensPerRequest": 4256
    }
  ]
}
```

---

#### `GET /api/v1/models/:modelName`
Get detailed stats for a specific model.

---

### Project Tracking

#### `GET /api/v1/projects`
List all tracked projects.

**Response:**
```json
{
  "projects": [
    {
      "projectID": "runic-ios",
      "projectName": "Runic iOS App",
      "totalTokens": 850000,
      "totalCost": 5.25,
      "primaryProvider": "claude",
      "lastActive": "2026-01-31T10:30:00Z"
    }
  ]
}
```

---

#### `GET /api/v1/projects/:projectID`
Get detailed stats for a project.

**Response:**
```json
{
  "projectID": "runic-ios",
  "projectName": "Runic iOS App",
  "workspacePath": "/Users/.../RuniciOS",
  "usage": {
    "totalTokens": 850000,
    "totalCost": 5.25,
    "byProvider": {
      "claude": { "tokens": 700000, "cost": 4.50 },
      "codex": { "tokens": 150000, "cost": 0.75 }
    },
    "byModel": {
      "claude-3-5-sonnet": { "tokens": 700000, "cost": 4.50 }
    }
  },
  "timeline": [
    { "date": "2026-01-31", "tokens": 120000, "cost": 0.80 }
  ]
}
```

---

### Alerts

#### `GET /api/v1/alerts`
Get active and recent alerts.

**Query Parameters:**
- `active` (boolean) - Only active alerts
- `severity` (optional) - Filter by severity

**Response:**
```json
{
  "active": [
    {
      "id": "alert_123",
      "provider": "claude",
      "severity": "critical",
      "title": "Claude Usage Critical",
      "message": "⚠️ 92% used. Approaching limit!",
      "threshold": 90,
      "currentUsage": 92.5,
      "estimatedTimeToLimit": 1800,
      "recommendation": "Switch to alternative provider",
      "createdAt": "2026-01-31T10:25:00Z"
    }
  ]
}
```

---

#### `POST /api/v1/alerts`
Create a new alert rule.

**Request Body:**
```json
{
  "provider": "claude",
  "threshold": 85,
  "severity": "warning",
  "notifyVia": ["webhook", "email"]
}
```

---

### Analytics

#### `GET /api/v1/analytics/cost`
Get cost analytics.

**Query Parameters:**
- `days` (default: 7)
- `groupBy` - "day", "provider", "model", "project"

**Response:**
```json
{
  "period": "7 days",
  "totalCost": 45.80,
  "breakdown": {
    "claude": 28.50,
    "codex": 12.30,
    "gemini": 5.00
  },
  "daily": [
    { "date": "2026-01-31", "cost": 8.20 }
  ],
  "topModels": [
    { "model": "claude-opus-4", "cost": 18.50 }
  ]
}
```

---

#### `GET /api/v1/analytics/trends`
Get usage trends and predictions.

**Response:**
```json
{
  "trends": [
    {
      "provider": "claude",
      "avgUsage": 78.5,
      "peakUsage": 95.0,
      "trend": "increasing",
      "prediction": {
        "willHitLimit": true,
        "estimatedTime": "2026-01-31T15:30:00Z",
        "confidence": "high"
      }
    }
  ]
}
```

---

### Reset Timings

#### `GET /api/v1/resets`
Get reset schedules for all providers.

**Response:**
```json
{
  "resets": [
    {
      "provider": "claude",
      "resetType": "sessionBased",
      "nextReset": "2026-01-31T14:00:00Z",
      "timeUntilReset": 12600,
      "windowDuration": 18000,
      "projectedUsageAtReset": 96.5
    }
  ]
}
```

---

### WebSocket (Real-time Updates)

#### `ws://localhost:3000/ws`
Connect for real-time usage updates.

**Message Format:**
```json
{
  "type": "usage_update",
  "provider": "claude",
  "snapshot": { ... }
}
```

**Event Types:**
- `usage_update` - Provider usage changed
- `alert_created` - New alert triggered
- `reset_occurred` - Provider reset happened
- `model_used` - New model detected

---

## Authentication

### API Key (Recommended)

```bash
curl -H "Authorization: Bearer YOUR_API_KEY" \
  http://localhost:3000/api/v1/usage
```

### OAuth 2.0 (Optional)

For multi-user deployments, use OAuth 2.0:

```
POST /oauth/token
GET /oauth/authorize
```

---

## Client SDKs

### TypeScript/JavaScript

```typescript
import { RunicClient } from '@runic/client';

const client = new RunicClient({
  apiKey: 'your-api-key',
  baseURL: 'http://localhost:3000'
});

// Get all usage
const usage = await client.usage.getAll();

// Get specific provider
const claude = await client.usage.get('claude');

// Watch for updates
client.on('usage_update', (snapshot) => {
  console.log(`${snapshot.provider} at ${snapshot.primary.usedPercent}%`);
});
```

### Python

```python
from runic_client import RunicClient

client = RunicClient(api_key='your-api-key')

# Get usage
usage = client.usage.get_all()

# Subscribe to alerts
@client.on('alert_created')
def handle_alert(alert):
    print(f"Alert: {alert.title}")

client.connect()
```

### Swift (for iOS/macOS)

```swift
import RunicClient

let client = RunicClient(apiKey: "your-api-key")

// Async/await
let snapshots = try await client.usage.getAll()

// Combine
client.usagePublisher
    .sink { snapshot in
        print("\(snapshot.provider): \(snapshot.primary.usedPercent)%")
    }
```

---

## Webhooks

Register webhooks to receive events:

```bash
POST /api/v1/webhooks
{
  "url": "https://your-app.com/webhooks/runic",
  "events": ["usage_update", "alert_created"],
  "secret": "your-webhook-secret"
}
```

**Webhook Payload:**
```json
{
  "event": "alert_created",
  "timestamp": "2026-01-31T10:30:00Z",
  "data": { ... },
  "signature": "sha256=..."
}
```

---

## Deployment

### Docker

```bash
docker build -t runic-api .
docker run -p 3000:3000 runic-api
```

### Environment Variables

```bash
PORT=3000
DATABASE_URL=postgresql://...
REDIS_URL=redis://...
API_KEY_SALT=your-secret-salt
ENABLE_WEBHOOKS=true
ENABLE_WEBSOCKETS=true
```

---

## Rate Limiting

Default limits:
- 1000 requests/hour per API key
- 100 WebSocket connections per client
- 50 webhook deliveries/minute

---

## For AI Assistant Apps

### Recommended Polling Intervals

- **Active monitoring**: Every 30 seconds
- **Background sync**: Every 5 minutes
- **Widget updates**: Every 15 minutes

### Efficient Queries

```typescript
// Poll only changed data
GET /api/v1/usage?since=2026-01-31T10:25:00Z

// Minimal response
GET /api/v1/usage?fields=provider,primary.usedPercent,primaryReset

// Batch requests
POST /api/v1/batch
{
  "requests": [
    { "method": "GET", "path": "/api/v1/usage" },
    { "method": "GET", "path": "/api/v1/alerts" }
  ]
}
```

---

## Security

- HTTPS only in production
- API key rotation
- Rate limiting per client
- Request signing for webhooks
- CORS configuration
- Input validation with Zod

---

## License

MIT - Part of the Runic project
