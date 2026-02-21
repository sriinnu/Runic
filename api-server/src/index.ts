#!/usr/bin/env node

/**
 * Runic API Server
 *
 * Exposes Runic usage data via REST API and WebSocket for AI assistant apps.
 *
 * Features:
 * - Real-time usage snapshots
 * - Model and project tracking
 * - Cost analytics and trends
 * - Proactive alerts
 * - WebSocket support for live updates
 * - Webhook delivery
 *
 * @packageDocumentation
 */

import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import rateLimit from 'express-rate-limit';
import { WebSocketServer } from 'ws';
import { createServer } from 'http';
import dotenv from 'dotenv';

// Import routes
import { usageRouter } from './routes/usage.js';
import { modelsRouter } from './routes/models.js';
import { projectsRouter } from './routes/projects.js';
import { alertsRouter } from './routes/alerts.js';
import { analyticsRouter } from './routes/analytics.js';
import { resetsRouter } from './routes/resets.js';
import { webhooksRouter } from './routes/webhooks.js';

// Import services
import { WebSocketManager } from './services/websocket.js';
import { DatabaseService } from './services/database.js';

dotenv.config();

const PORT = process.env.PORT || 3000;
const app = express();
const server = createServer(app);

/**
 * Configure middleware
 */
app.use(helmet());
app.use(cors({
  origin: process.env.CORS_ORIGIN || '*',
  credentials: true
}));
app.use(compression());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

/**
 * Rate limiting
 * 1000 requests per hour per IP
 */
const limiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 1000,
  message: 'Too many requests from this IP, please try again later.'
});
app.use('/api/', limiter);

/**
 * API Routes
 */
app.use('/api/v1/usage', usageRouter);
app.use('/api/v1/models', modelsRouter);
app.use('/api/v1/projects', projectsRouter);
app.use('/api/v1/alerts', alertsRouter);
app.use('/api/v1/analytics', analyticsRouter);
app.use('/api/v1/resets', resetsRouter);
app.use('/api/v1/webhooks', webhooksRouter);

/**
 * Health check endpoint
 */
app.get('/health', (_req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    version: process.env.npm_package_version
  });
});

/**
 * API documentation endpoint
 */
app.get('/api/v1/docs', (_req, res) => {
  res.json({
    name: 'Runic API',
    version: '1.0.0',
    endpoints: {
      usage: '/api/v1/usage',
      models: '/api/v1/models',
      projects: '/api/v1/projects',
      alerts: '/api/v1/alerts',
      analytics: '/api/v1/analytics',
      resets: '/api/v1/resets',
      webhooks: '/api/v1/webhooks',
      vaayuSnapshot: '/api/v1/vaayu/snapshot'
    },
    websocket: '/ws',
    documentation: 'See README.md for full API documentation'
  });
});

/**
 * Vaayu snapshot response
 */
interface VaayuSnapshot {
  usage: {
    providers: any[];
    totalCost: number;
    totalTokens: number;
  };
  projects: {
    active: any[];
    total: number;
  };
  alerts: {
    active: any[];
    summary: {
      critical: number;
      warning: number;
      info: number;
    };
  };
  analytics: {
    todayCost: number;
    weekCost: number;
    monthCost: number;
    projectedMonthlyCost: number;
  };
  recommendations: string[];
}

/**
 * GET /api/v1/vaayu/snapshot
 *
 * Convenience endpoint that aggregates all key data for Vaayu dashboard
 *
 * @returns {ApiResponse<VaayuSnapshot>} Comprehensive snapshot
 */
app.get('/api/v1/vaayu/snapshot', async (_req, res) => {
  try {
    // In production, aggregate from multiple sources:
    // - UsageStore for current usage
    // - UsageLedger for cost data
    // - ProjectBudgetStore for project info
    // - AlertRuleStore for active alerts
    // - UsageLedgerAggregator for analytics

    // Mock data
    const snapshot: VaayuSnapshot = {
      usage: {
        providers: [
          {
            provider: 'anthropic',
            usedPercent: 75.3,
            estimatedCost: 45.80,
            totalTokens: 3500000
          },
          {
            provider: 'openai',
            usedPercent: 82.1,
            estimatedCost: 35.20,
            totalTokens: 2800000
          },
          {
            provider: 'google',
            usedPercent: 45.2,
            estimatedCost: 6.50,
            totalTokens: 1200000
          }
        ],
        totalCost: 87.50,
        totalTokens: 7500000
      },
      projects: {
        active: [
          {
            projectID: 'proj-123',
            projectName: 'Runic API Server',
            cost: 48.70,
            budgetUsed: 48.7
          },
          {
            projectID: 'proj-456',
            projectName: 'Runic iOS App',
            cost: 26.30,
            budgetUsed: 84.6
          }
        ],
        total: 3
      },
      alerts: {
        active: [
          {
            id: 'alert-001',
            severity: 'warning',
            title: 'High Usage Warning',
            provider: 'anthropic'
          },
          {
            id: 'alert-002',
            severity: 'critical',
            title: 'Critical Usage Alert',
            provider: 'openai'
          }
        ],
        summary: {
          critical: 1,
          warning: 1,
          info: 0
        }
      },
      analytics: {
        todayCost: 3.25,
        weekCost: 22.80,
        monthCost: 87.50,
        projectedMonthlyCost: 95.40
      },
      recommendations: [
        'Project "Runic iOS App" is at 84.6% of budget - consider optimization',
        'OpenAI usage is critical (82.1%) - immediate action recommended',
        'Consider upgrading to higher tier for better cost efficiency'
      ]
    };

    res.json({
      data: snapshot,
      timestamp: new Date().toISOString(),
      success: true
    });
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    res.status(500).json({
      data: null,
      timestamp: new Date().toISOString(),
      success: false,
      error: {
        message: errorMessage,
        code: 'VAAYU_SNAPSHOT_ERROR'
      }
    });
  }
});

/**
 * Error handling middleware
 */
app.use((err: any, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error('Error:', err);
  res.status(err.status || 500).json({
    error: {
      message: err.message || 'Internal server error',
      status: err.status || 500,
      timestamp: new Date().toISOString()
    }
  });
});

/**
 * WebSocket server for real-time updates
 */
const wss = new WebSocketServer({ server, path: '/ws' });
const wsManager = new WebSocketManager(wss);

/**
 * Initialize database
 */
const db = new DatabaseService();
await db.initialize();

/**
 * Start server
 */
server.listen(PORT, () => {
  console.log(`🔮 Runic API Server running on port ${PORT}`);
  console.log(`📡 WebSocket available at ws://localhost:${PORT}/ws`);
  console.log(`📚 API docs at http://localhost:${PORT}/api/v1/docs`);
  console.log(`❤️  Health check at http://localhost:${PORT}/health`);
});

/**
 * Graceful shutdown
 */
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully...');
  server.close(() => {
    console.log('Server closed');
    db.close();
    process.exit(0);
  });
});

export { app, server, wss, wsManager, db };
