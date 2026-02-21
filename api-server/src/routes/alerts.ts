/**
 * Alerts Routes
 *
 * Provides endpoints for managing usage alerts and notifications.
 *
 * Endpoints:
 * - GET /api/v1/alerts - Get all active alerts
 * - POST /api/v1/alerts - Create a new alert configuration
 *
 * @module routes/alerts
 */

import { Router, Request, Response } from 'express';
import {
  AlertSeverity
} from '../types/index.js';
import type {
  UsageAlert,
  ApiResponse,
  PaginatedResponse
} from '../types/index.js';

export const alertsRouter = Router();

/**
 * Alert configuration for creating new alerts
 */
interface AlertConfig {
  provider: string;
  threshold: number;
  severity: AlertSeverity;
  enabled: boolean;
  notificationChannels?: string[];
}

/**
 * Mock alerts data for development
 * In production, this would be stored in the database
 */
const mockAlerts: Record<string, UsageAlert> = {
  'alert-001': {
    id: 'alert-001',
    provider: 'anthropic',
    severity: AlertSeverity.Warning,
    title: 'High Usage Warning',
    message: 'You have used 75% of your daily token limit for Anthropic Claude',
    threshold: 75,
    currentUsage: 75.3,
    estimatedTimeToLimit: 7200, // 2 hours
    recommendation: 'Consider upgrading your plan or reducing usage for the remainder of the day',
    createdAt: new Date(Date.now() - 3600000).toISOString()
  },
  'alert-002': {
    id: 'alert-002',
    provider: 'openai',
    severity: AlertSeverity.Critical,
    title: 'Critical Usage Alert',
    message: 'You have used 90% of your daily token limit for OpenAI GPT-4',
    threshold: 90,
    currentUsage: 92.5,
    estimatedTimeToLimit: 1800, // 30 minutes
    recommendation: 'Immediate action required: Upgrade your plan or pause API usage',
    createdAt: new Date(Date.now() - 1800000).toISOString()
  },
  'alert-003': {
    id: 'alert-003',
    provider: 'google',
    severity: AlertSeverity.Info,
    title: 'Usage Milestone',
    message: 'You have reached 50% of your monthly token limit for Google Gemini',
    threshold: 50,
    currentUsage: 51.2,
    recommendation: 'Usage is on track. Continue monitoring to avoid overages',
    createdAt: new Date(Date.now() - 86400000).toISOString()
  }
};

/**
 * Alert configurations (thresholds and settings)
 * Uncomment when needed for future features
 */
/* const mockAlertConfigs: Record<string, AlertConfig> = {
  'config-001': {
    provider: 'anthropic',
    threshold: 75,
    severity: AlertSeverity.Warning,
    enabled: true,
    notificationChannels: ['email', 'webhook']
  },
  'config-002': {
    provider: 'openai',
    threshold: 90,
    severity: AlertSeverity.Critical,
    enabled: true,
    notificationChannels: ['email', 'webhook', 'slack']
  },
  'config-003': {
    provider: 'google',
    threshold: 50,
    severity: AlertSeverity.Info,
    enabled: true,
    notificationChannels: ['email']
  }
}; */

/**
 * GET /api/v1/alerts
 *
 * Retrieves all active alerts
 *
 * Query parameters:
 * - page: number - Page number for pagination (default: 1)
 * - pageSize: number - Number of items per page (default: 20, max: 100)
 * - severity: AlertSeverity - Filter by severity level
 * - provider: string - Filter by provider
 * - active: boolean - Filter by active status (default: true)
 * - sortBy: 'createdAt' | 'severity' | 'threshold' - Sort field (default: 'createdAt')
 * - order: 'asc' | 'desc' - Sort order (default: 'desc')
 *
 * @returns {ApiResponse<PaginatedResponse<UsageAlert>>} Paginated list of alerts
 */
alertsRouter.get('/', async (req: Request, res: Response) => {
  try {
    const page = Math.max(1, parseInt(req.query.page as string) || 1);
    const pageSize = Math.min(100, Math.max(1, parseInt(req.query.pageSize as string) || 20));
    const severityFilter = req.query.severity as AlertSeverity | undefined;
    const providerFilter = req.query.provider as string | undefined;
    const sortBy = (req.query.sortBy as string) || 'createdAt';
    const order = (req.query.order as string) || 'desc';

    // Get all alerts
    let alerts = Object.values(mockAlerts);

    // Apply filters
    if (severityFilter) {
      alerts = alerts.filter(a => a.severity === severityFilter);
    }
    if (providerFilter) {
      alerts = alerts.filter(a => a.provider === providerFilter);
    }

    // Sort alerts
    alerts.sort((a, b) => {
      let comparison = 0;
      switch (sortBy) {
        case 'createdAt':
          comparison = new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime();
          break;
        case 'severity':
          const severityOrder = {
            [AlertSeverity.Urgent]: 4,
            [AlertSeverity.Critical]: 3,
            [AlertSeverity.Warning]: 2,
            [AlertSeverity.Info]: 1
          };
          comparison = severityOrder[a.severity] - severityOrder[b.severity];
          break;
        case 'threshold':
          comparison = a.threshold - b.threshold;
          break;
        default:
          comparison = 0;
      }
      return order === 'asc' ? comparison : -comparison;
    });

    // Paginate
    const totalItems = alerts.length;
    const totalPages = Math.ceil(totalItems / pageSize);
    const startIndex = (page - 1) * pageSize;
    const endIndex = startIndex + pageSize;
    const paginatedAlerts = alerts.slice(startIndex, endIndex);

    const paginatedResponse: PaginatedResponse<UsageAlert> = {
      data: paginatedAlerts,
      pagination: {
        page,
        pageSize,
        totalPages,
        totalItems
      }
    };

    const response: ApiResponse<PaginatedResponse<UsageAlert>> = {
      data: paginatedResponse,
      timestamp: new Date().toISOString(),
      success: true
    };

    return res.json(response);
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    const response: ApiResponse<PaginatedResponse<UsageAlert>> = {
      data: {
        data: [],
        pagination: { page: 1, pageSize: 20, totalPages: 0, totalItems: 0 }
      },
      timestamp: new Date().toISOString(),
      success: false,
      error: {
        message: errorMessage,
        code: 'ALERTS_FETCH_ERROR'
      }
    };
    return res.status(500).json(response);
  }
});

/**
 * POST /api/v1/alerts
 *
 * Creates a new alert configuration
 *
 * Request body:
 * - provider: string - Provider identifier (required)
 * - threshold: number - Usage percentage threshold (0-100, required)
 * - severity: AlertSeverity - Alert severity level (required)
 * - enabled: boolean - Whether the alert is active (default: true)
 * - notificationChannels: string[] - Notification delivery channels (optional)
 *
 * @returns {ApiResponse<AlertConfig>} Created alert configuration
 */
alertsRouter.post('/', async (req: Request, res: Response) => {
  try {
    const {
      provider,
      threshold,
      severity,
      enabled = true,
      notificationChannels = ['email']
    } = req.body as AlertConfig;

    // Validate required fields
    if (!provider || threshold === undefined || !severity) {
      const response: ApiResponse<AlertConfig | null> = {
        data: null,
        timestamp: new Date().toISOString(),
        success: false,
        error: {
          message: 'Missing required fields: provider, threshold, severity',
          code: 'VALIDATION_ERROR'
        }
      };
      return res.status(400).json(response);
    }

    // Validate threshold range
    if (threshold < 0 || threshold > 100) {
      const response: ApiResponse<AlertConfig | null> = {
        data: null,
        timestamp: new Date().toISOString(),
        success: false,
        error: {
          message: 'Threshold must be between 0 and 100',
          code: 'VALIDATION_ERROR'
        }
      };
      return res.status(400).json(response);
    }

    // Validate severity
    if (!Object.values(AlertSeverity).includes(severity)) {
      const response: ApiResponse<AlertConfig | null> = {
        data: null,
        timestamp: new Date().toISOString(),
        success: false,
        error: {
          message: 'Invalid severity level',
          code: 'VALIDATION_ERROR'
        }
      };
      return res.status(400).json(response);
    }

    // Create alert configuration
    const alertConfig: AlertConfig = {
      provider,
      threshold,
      severity,
      enabled,
      notificationChannels
    };

    // In production, save to database
    // const savedConfig = await db.createAlertConfig(alertConfig);

    const response: ApiResponse<AlertConfig> = {
      data: alertConfig,
      timestamp: new Date().toISOString(),
      success: true
    };

    return res.status(201).json(response);
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    const response: ApiResponse<AlertConfig | null> = {
      data: null,
      timestamp: new Date().toISOString(),
      success: false,
      error: {
        message: errorMessage,
        code: 'ALERT_CREATE_ERROR'
      }
    };
    return res.status(500).json(response);
  }
});

/**
 * GET /api/v1/alerts/:alertID
 *
 * Retrieves details for a specific alert
 *
 * Path parameters:
 * - alertID: string - Alert identifier
 *
 * @returns {ApiResponse<UsageAlert>} Alert details
 */
alertsRouter.get('/:alertID', async (req: Request, res: Response) => {
  try {
    const { alertID } = req.params;

    // Fetch alert data
    const alert = mockAlerts[alertID];

    if (!alert) {
      const response: ApiResponse<UsageAlert | null> = {
        data: null,
        timestamp: new Date().toISOString(),
        success: false,
        error: {
          message: `Alert '${alertID}' not found`,
          code: 'ALERT_NOT_FOUND'
        }
      };
      return res.status(404).json(response);
    }

    const response: ApiResponse<UsageAlert> = {
      data: alert,
      timestamp: new Date().toISOString(),
      success: true
    };

    return res.json(response);
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    const response: ApiResponse<UsageAlert | null> = {
      data: null,
      timestamp: new Date().toISOString(),
      success: false,
      error: {
        message: errorMessage,
        code: 'ALERT_FETCH_ERROR'
      }
    };
    return res.status(500).json(response);
  }
});

/**
 * Alert evaluation result
 */
interface AlertEvaluation {
  alerts: UsageAlert[];
  triggered: number;
  evaluated: number;
  timestamp: string;
  summary: {
    critical: number;
    warning: number;
    info: number;
  };
}

/**
 * POST /api/v1/alerts/evaluate
 *
 * Evaluates all alert rules against current usage data
 *
 * Request body:
 * - broadcastWebSocket: boolean - Whether to broadcast alerts via WebSocket (default: true)
 * - triggerWebhooks: boolean - Whether to trigger webhooks (default: true)
 *
 * @returns {ApiResponse<AlertEvaluation>} Evaluation results
 */
alertsRouter.post('/evaluate', async (req: Request, res: Response) => {
  try {
    const {
      broadcastWebSocket = true,
      triggerWebhooks = true
    } = req.body;

    // In production:
    // 1. Load alert rules from AlertRuleStore
    // 2. Check current usage from UsageStore
    // 3. Check budgets from ProjectBudgetStore
    // 4. Check velocity/anomalies from UsageLedgerAggregator
    // 5. Generate alerts based on rule conditions

    const triggeredAlerts: UsageAlert[] = [];

    // Mock: Check budget thresholds
    const budgetAlerts = [
      {
        id: 'alert-budget-001',
        provider: 'anthropic',
        severity: AlertSeverity.Warning,
        title: 'Budget Threshold Exceeded',
        message: 'Project "Runic iOS App" has exceeded 80% of monthly budget',
        threshold: 80,
        currentUsage: 84.6,
        recommendation: 'Review project costs and consider increasing budget or optimizing usage',
        createdAt: new Date().toISOString()
      }
    ];

    // Mock: Check velocity anomalies
    const velocityAlerts = [
      {
        id: 'alert-velocity-001',
        provider: 'openai',
        severity: AlertSeverity.Critical,
        title: 'Unusual Usage Spike Detected',
        message: 'Token usage has increased by 250% compared to average hourly usage',
        threshold: 200,
        currentUsage: 250,
        estimatedTimeToLimit: 3600,
        recommendation: 'Investigate recent API calls and check for runaway processes',
        createdAt: new Date().toISOString()
      }
    ];

    triggeredAlerts.push(...budgetAlerts, ...velocityAlerts);

    // Count by severity
    const criticalCount = triggeredAlerts.filter(a => a.severity === AlertSeverity.Critical).length;
    const warningCount = triggeredAlerts.filter(a => a.severity === AlertSeverity.Warning).length;
    const infoCount = triggeredAlerts.filter(a => a.severity === AlertSeverity.Info).length;

    // Broadcast via WebSocket if enabled
    if (broadcastWebSocket) {
      // In production: wsManager.broadcastAlert(alert)
      console.log(`Would broadcast ${triggeredAlerts.length} alerts via WebSocket`);
    }

    // Trigger webhooks if enabled
    if (triggerWebhooks) {
      // In production: deliverWebhooks(triggeredAlerts, webhookRules)
      console.log(`Would trigger webhooks for ${triggeredAlerts.length} alerts`);
    }

    const evaluation: AlertEvaluation = {
      alerts: triggeredAlerts,
      triggered: triggeredAlerts.length,
      evaluated: 5, // Mock: evaluated 5 rules
      timestamp: new Date().toISOString(),
      summary: {
        critical: criticalCount,
        warning: warningCount,
        info: infoCount
      }
    };

    const response: ApiResponse<AlertEvaluation> = {
      data: evaluation,
      timestamp: new Date().toISOString(),
      success: true
    };

    return res.json(response);
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    const response: ApiResponse<AlertEvaluation | null> = {
      data: null,
      timestamp: new Date().toISOString(),
      success: false,
      error: {
        message: errorMessage,
        code: 'ALERT_EVALUATION_ERROR'
      }
    };
    return res.status(500).json(response);
  }
});
