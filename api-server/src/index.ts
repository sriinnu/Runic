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
      webhooks: '/api/v1/webhooks'
    },
    websocket: '/ws',
    documentation: 'See README.md for full API documentation'
  });
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
