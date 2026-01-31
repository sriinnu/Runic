# Runic Integration Guide for AI Assistant Apps

This guide shows how to integrate Runic usage data into your AI assistant application.

---

## Overview

Runic exposes **all usage data** via:
1. **REST API** - Pull data on demand
2. **WebSocket** - Real-time push updates
3. **Webhooks** - Event notifications
4. **Client SDKs** - Easy integration

---

## Quick Integration (5 minutes)

### Option 1: REST API

```typescript
// Fetch all usage data
const response = await fetch('http://localhost:3000/api/v1/usage?includeModels=true&includeProjects=true');
const { snapshots } = await response.json();

// Each snapshot contains:
snapshots.forEach(snapshot => {
  console.log({
    provider: snapshot.provider,
    usagePercent: snapshot.primary.usedPercent,
    resetTime: snapshot.primaryReset?.resetAt,
    timeUntilReset: snapshot.primaryReset?.timeUntilReset,
    activeModel: snapshot.primaryModel?.modelName,
    activeProject: snapshot.activeProject?.projectName,
    accountType: snapshot.accountType,
    estimatedCost: snapshot.estimatedCost,
    tokenUsage: snapshot.tokenUsage
  });
});
```

### Option 2: WebSocket (Real-time)

```typescript
const ws = new WebSocket('ws://localhost:3000/ws');

ws.onmessage = (event) => {
  const message = JSON.parse(event.data);

  switch (message.type) {
    case 'usage_update':
      console.log(`${message.provider} now at ${message.data.primary.usedPercent}%`);
      break;

    case 'alert_created':
      console.log(`🚨 Alert: ${message.data.title}`);
      break;

    case 'reset_occurred':
      console.log(`✅ ${message.provider} usage reset`);
      break;
  }
};
```

---

## Available Data Points

### Core Usage Metrics

| Property | Type | Description | Example |
|----------|------|-------------|---------|
| `provider` | string | Provider name | `"claude"` |
| `primary.usedPercent` | number | Usage percentage (0-100) | `85.5` |
| `primary.resetsAt` | string | ISO timestamp of reset | `"2026-01-31T14:00:00Z"` |
| `primaryReset.timeUntilReset` | number | Seconds until reset | `12600` |
| `primaryReset.resetDescription` | string | Human-readable reset info | `"Resets in 3h 30m"` |

### Account Information

| Property | Type | Description |
|----------|------|-------------|
| `accountType` | enum | `"usage_based"`, `"subscription"`, `"free_tier"`, `"enterprise"` |
| `accountEmail` | string | Account email address |
| `accountOrganization` | string | Organization name |

### Model Tracking

| Property | Type | Description |
|----------|------|-------------|
| `primaryModel.modelName` | string | Current model being used |
| `primaryModel.tier` | string | `"opus"`, `"sonnet"`, `"haiku"` |
| `recentModels[]` | array | Recently used models |

### Project Tracking

| Property | Type | Description |
|----------|------|-------------|
| `activeProject.projectID` | string | Project identifier |
| `activeProject.projectName` | string | Human-readable project name |
| `activeProject.workspacePath` | string | File system path |

### Token Usage

| Property | Type | Description |
|----------|------|-------------|
| `tokenUsage.inputTokens` | number | Input tokens consumed |
| `tokenUsage.outputTokens` | number | Output tokens generated |
| `tokenUsage.totalTokens` | number | Total tokens |
| `tokenUsage.modelBreakdown` | object | Tokens per model |
| `tokenUsage.projectBreakdown` | object | Tokens per project |

### Cost Information

| Property | Type | Description |
|----------|------|-------------|
| `estimatedCost` | number | Cost in USD |
| `costCurrency` | string | Currency code |

---

## Use Cases for AI Assistants

### 1. Intelligent Provider Selection

```typescript
/**
 * Choose the best provider based on current availability
 */
async function selectOptimalProvider() {
  const response = await fetch('http://localhost:3000/api/v1/usage');
  const { snapshots } = await response.json();

  // Filter providers with < 75% usage
  const available = snapshots.filter(s => s.primary.usedPercent < 75);

  if (available.length === 0) {
    return { provider: null, reason: 'All providers near limit' };
  }

  // Sort by usage (prefer less used)
  available.sort((a, b) => a.primary.usedPercent - b.primary.usedPercent);

  return {
    provider: available[0].provider,
    usagePercent: available[0].primary.usedPercent,
    reason: `${available[0].provider} has ${100 - available[0].primary.usedPercent}% headroom`
  };
}
```

### 2. Proactive Warnings

```typescript
/**
 * Check if any provider is approaching limit
 */
async function checkForWarnings() {
  const response = await fetch('http://localhost:3000/api/v1/usage');
  const { snapshots } = await response.json();

  const warnings = snapshots
    .filter(s => s.primary.usedPercent >= 80)
    .map(s => ({
      provider: s.provider,
      usage: s.primary.usedPercent,
      resetsIn: s.primaryReset?.resetDescription,
      recommendation: s.primary.usedPercent >= 90
        ? 'Switch providers immediately'
        : 'Monitor closely'
    }));

  return warnings;
}
```

### 3. Cost Tracking

```typescript
/**
 * Get total cost across all providers
 */
async function getTotalCost(days = 7) {
  const response = await fetch(`http://localhost:3000/api/v1/analytics/cost?days=${days}`);
  const { totalCost, breakdown } = await response.json();

  return {
    total: `$${totalCost.toFixed(2)}`,
    breakdown,
    perDay: `$${(totalCost / days).toFixed(2)}`
  };
}
```

### 4. Model Recommendations

```typescript
/**
 * Get cheapest model for a task type
 */
async function recommendModel(taskType: 'coding' | 'chat' | 'analysis') {
  const response = await fetch('http://localhost:3000/api/v1/models');
  const { models } = await response.json();

  // Filter by task suitability
  const suitable = models.filter(m => {
    if (taskType === 'coding') return m.tier === 'opus' || m.tier === 'sonnet';
    if (taskType === 'chat') return true; // All models ok
    if (taskType === 'analysis') return m.tier === 'opus';
    return true;
  });

  // Sort by cost per token
  suitable.sort((a, b) => (a.totalCost / a.totalTokens) - (b.totalCost / b.totalTokens));

  return suitable[0];
}
```

### 5. Project-Based Analytics

```typescript
/**
 * Get usage stats for a specific project
 */
async function getProjectStats(projectID: string) {
  const response = await fetch(`http://localhost:3000/api/v1/projects/${projectID}`);
  const project = await response.json();

  return {
    name: project.projectName,
    totalTokens: project.usage.totalTokens.toLocaleString(),
    totalCost: `$${project.usage.totalCost.toFixed(2)}`,
    primaryProvider: project.usage.byProvider,
    modelsUsed: Object.keys(project.usage.byModel)
  };
}
```

---

## Real-time Monitoring

### Subscribe to All Events

```typescript
const ws = new WebSocket('ws://localhost:3000/ws');

ws.onopen = () => {
  console.log('Connected to Runic');
};

ws.onmessage = (event) => {
  const message = JSON.parse(event.data);
  handleRunicEvent(message);
};

function handleRunicEvent(message) {
  switch (message.type) {
    case 'usage_update':
      // Update your UI with new usage data
      updateProviderUI(message.provider, message.data);
      break;

    case 'alert_created':
      // Show notification to user
      showNotification(message.data.title, message.data.message);
      break;

    case 'reset_occurred':
      // Inform user that limits have reset
      console.log(`✅ ${message.provider} reset - fresh limits available`);
      break;

    case 'model_used':
      // Track model usage
      trackModelUsage(message.data.modelName);
      break;
  }
}
```

---

## Batch Requests (Efficient)

```typescript
/**
 * Fetch multiple endpoints in one request
 */
async function fetchDashboardData() {
  const response = await fetch('http://localhost:3000/api/v1/batch', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      requests: [
        { method: 'GET', path: '/api/v1/usage' },
        { method: 'GET', path: '/api/v1/alerts?active=true' },
        { method: 'GET', path: '/api/v1/analytics/cost?days=7' }
      ]
    })
  });

  const { responses } = await response.json();

  return {
    usage: responses[0].data,
    alerts: responses[1].data,
    costs: responses[2].data
  };
}
```

---

## Client SDK Usage

### TypeScript/JavaScript

```typescript
import { RunicClient } from '@runic/client';

const client = new RunicClient({
  apiKey: process.env.RUNIC_API_KEY,
  baseURL: 'http://localhost:3000'
});

// Get all usage
const snapshots = await client.usage.getAll({
  includeModels: true,
  includeProjects: true
});

// Get specific provider
const claude = await client.usage.get('claude');

// Subscribe to updates
client.on('usage_update', (snapshot) => {
  console.log(`${snapshot.provider}: ${snapshot.primary.usedPercent}%`);
});

// Get alerts
const alerts = await client.alerts.getActive();

// Get cost analytics
const costs = await client.analytics.getCost({ days: 7 });
```

---

## Webhook Integration

```typescript
/**
 * Register a webhook to receive events at your server
 */
async function registerWebhook() {
  await fetch('http://localhost:3000/api/v1/webhooks', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      url: 'https://your-app.com/webhooks/runic',
      events: ['usage_update', 'alert_created'],
      secret: 'your-webhook-secret'
    })
  });
}

/**
 * Handle webhook in your server
 */
app.post('/webhooks/runic', (req, res) => {
  const { event, timestamp, data, signature } = req.body;

  // Verify signature
  const expectedSignature = createHmac('sha256', 'your-webhook-secret')
    .update(JSON.stringify(data))
    .digest('hex');

  if (signature !== `sha256=${expectedSignature}`) {
    return res.status(401).send('Invalid signature');
  }

  // Process event
  handleRunicEvent({ type: event, data, timestamp });

  res.status(200).send('OK');
});
```

---

## Best Practices

### 1. Caching

```typescript
// Cache usage data for 30 seconds to reduce API calls
const cache = new Map();

async function getCachedUsage() {
  const cacheKey = 'usage';
  const cached = cache.get(cacheKey);

  if (cached && Date.now() - cached.timestamp < 30000) {
    return cached.data;
  }

  const data = await fetch('http://localhost:3000/api/v1/usage').then(r => r.json());
  cache.set(cacheKey, { data, timestamp: Date.now() });

  return data;
}
```

### 2. Error Handling

```typescript
async function safelyFetchUsage() {
  try {
    const response = await fetch('http://localhost:3000/api/v1/usage');

    if (!response.ok) {
      throw new Error(`API error: ${response.status}`);
    }

    return await response.json();
  } catch (error) {
    console.error('Failed to fetch usage:', error);
    // Return cached data or default values
    return { snapshots: [] };
  }
}
```

### 3. Polling Strategy

```typescript
// Smart polling: Fast when near limits, slow otherwise
async function smartPoll() {
  const { snapshots } = await getCachedUsage();
  const maxUsage = Math.max(...snapshots.map(s => s.primary.usedPercent));

  let interval;
  if (maxUsage >= 90) {
    interval = 10_000; // 10 seconds when critical
  } else if (maxUsage >= 75) {
    interval = 30_000; // 30 seconds when warning
  } else {
    interval = 300_000; // 5 minutes when normal
  }

  setTimeout(smartPoll, interval);
}
```

---

## Example: Complete AI Assistant Integration

```typescript
import { RunicClient } from '@runic/client';

class AIAssistant {
  private runic: RunicClient;

  constructor() {
    this.runic = new RunicClient({
      apiKey: process.env.RUNIC_API_KEY
    });

    this.setupEventHandlers();
  }

  private setupEventHandlers() {
    this.runic.on('alert_created', (alert) => {
      this.handleAlert(alert);
    });

    this.runic.on('usage_update', (snapshot) => {
      this.checkLimits(snapshot);
    });
  }

  async selectProvider(task: string) {
    const snapshots = await this.runic.usage.getAll();

    // Find provider with lowest usage
    const best = snapshots
      .filter(s => s.primary.usedPercent < 80)
      .sort((a, b) => a.primary.usedPercent - b.primary.usedPercent)[0];

    if (!best) {
      throw new Error('All providers near limit');
    }

    return best.provider;
  }

  async trackUsage(provider: string, tokens: number) {
    // Your tracking logic here
    console.log(`Used ${tokens} tokens on ${provider}`);
  }

  private handleAlert(alert: any) {
    if (alert.severity === 'critical') {
      // Switch providers automatically
      this.switchProvider();
    }
  }

  private async checkLimits(snapshot: any) {
    if (snapshot.primary.usedPercent >= 90) {
      console.warn(`⚠️ ${snapshot.provider} at ${snapshot.primary.usedPercent}%`);
    }
  }
}
```

---

## Security

### API Key Authentication

```typescript
const headers = {
  'Authorization': `Bearer ${process.env.RUNIC_API_KEY}`,
  'Content-Type': 'application/json'
};

const response = await fetch('http://localhost:3000/api/v1/usage', { headers });
```

### Self-Hosting

For maximum privacy, run the Runic API server on your own infrastructure:

```bash
docker run -p 3000:3000 \
  -e DATABASE_URL=postgresql://... \
  -e API_KEY_SALT=your-secret \
  runic/api-server
```

---

## Support

- **Documentation**: See `api-server/README.md`
- **Examples**: Check `examples/` directory
- **Issues**: GitHub issues for bug reports

---

**Happy integrating!** 🚀
