/**
 * Webhooks Routes
 *
 * Provides endpoints for managing webhook configurations and delivery.
 *
 * Endpoints:
 * - POST /api/v1/webhooks - Create a new webhook
 * - GET /api/v1/webhooks - Get all webhooks
 *
 * @module routes/webhooks
 */

import { Router, Request, Response } from 'express';
import { randomBytes, createHmac } from 'crypto';
import {
  WebSocketMessageType,
  AlertSeverity
} from '../types/index.js';
import type {
  WebhookConfig,
  ApiResponse,
  PaginatedResponse,
  UsageAlert
} from '../types/index.js';

export const webhooksRouter = Router();

/**
 * Webhook payload types
 */
type WebhookType = 'slack' | 'discord' | 'generic';

/**
 * Slack message block format
 */
interface SlackPayload {
  text: string;
  attachments?: {
    color: string;
    blocks: any[];
    fallback: string;
  }[];
}

/**
 * Discord embed format
 */
interface DiscordPayload {
  content: string;
  embeds?: {
    title: string;
    description: string;
    color: number;
    fields: { name: string; value: string; inline?: boolean }[];
    timestamp: string;
  }[];
}

/**
 * Generic webhook payload
 */
interface GenericPayload {
  event: string;
  timestamp: string;
  data: any;
}

/**
 * Formats a webhook payload based on the webhook type
 *
 * @param alert - Usage alert to format
 * @param type - Webhook type (slack, discord, or generic)
 * @returns Formatted payload
 */
function formatWebhookPayload(alert: UsageAlert, type: WebhookType): SlackPayload | DiscordPayload | GenericPayload {
  if (type === 'slack') {
    // Slack blocks format with color attachments
    const color = alert.severity === AlertSeverity.Critical ? '#dc2626' :
                  alert.severity === AlertSeverity.Warning ? '#f59e0b' :
                  alert.severity === AlertSeverity.Info ? '#3b82f6' : '#6b7280';

    const slackPayload: SlackPayload = {
      text: `Alert: ${alert.title}`,
      attachments: [{
        color,
        fallback: alert.message,
        blocks: [
          {
            type: 'header',
            text: {
              type: 'plain_text',
              text: alert.title,
              emoji: true
            }
          },
          {
            type: 'section',
            fields: [
              {
                type: 'mrkdwn',
                text: `*Provider:*\n${alert.provider}`
              },
              {
                type: 'mrkdwn',
                text: `*Severity:*\n${alert.severity}`
              },
              {
                type: 'mrkdwn',
                text: `*Usage:*\n${alert.currentUsage.toFixed(1)}%`
              },
              {
                type: 'mrkdwn',
                text: `*Threshold:*\n${alert.threshold}%`
              }
            ]
          },
          {
            type: 'section',
            text: {
              type: 'mrkdwn',
              text: `*Message:*\n${alert.message}`
            }
          },
          {
            type: 'section',
            text: {
              type: 'mrkdwn',
              text: `*Recommendation:*\n${alert.recommendation}`
            }
          }
        ]
      }]
    };

    return slackPayload;
  }

  if (type === 'discord') {
    // Discord embed format with color
    const color = alert.severity === AlertSeverity.Critical ? 0xdc2626 :
                  alert.severity === AlertSeverity.Warning ? 0xf59e0b :
                  alert.severity === AlertSeverity.Info ? 0x3b82f6 : 0x6b7280;

    const discordPayload: DiscordPayload = {
      content: `**Alert: ${alert.title}**`,
      embeds: [{
        title: alert.title,
        description: alert.message,
        color,
        fields: [
          {
            name: 'Provider',
            value: alert.provider,
            inline: true
          },
          {
            name: 'Severity',
            value: alert.severity,
            inline: true
          },
          {
            name: 'Usage',
            value: `${alert.currentUsage.toFixed(1)}%`,
            inline: true
          },
          {
            name: 'Threshold',
            value: `${alert.threshold}%`,
            inline: true
          },
          {
            name: 'Recommendation',
            value: alert.recommendation,
            inline: false
          }
        ],
        timestamp: alert.createdAt
      }]
    };

    return discordPayload;
  }

  // Generic JSON format
  const genericPayload: GenericPayload = {
    event: 'alert.created',
    timestamp: alert.createdAt,
    data: alert
  };

  return genericPayload;
}

/**
 * Delivers webhooks to configured URLs with retry logic
 *
 * @param alerts - Alerts to deliver
 * @param webhooks - Webhook configurations
 * @returns Delivery results
 */
async function deliverWebhooks(alerts: UsageAlert[], webhooks: WebhookConfig[]): Promise<{
  delivered: number;
  failed: number;
  results: { webhookID: string; success: boolean; error?: string }[];
}> {
  const results: { webhookID: string; success: boolean; error?: string }[] = [];
  let delivered = 0;
  let failed = 0;

  // Filter webhooks that should receive alert events
  const alertWebhooks = webhooks.filter(w =>
    w.enabled && w.events.includes(WebSocketMessageType.AlertCreated)
  );

  for (const webhook of alertWebhooks) {
    for (const alert of alerts) {
      // Determine webhook type from URL
      let webhookType: WebhookType = 'generic';
      if (webhook.url.includes('slack.com')) {
        webhookType = 'slack';
      } else if (webhook.url.includes('discord.com')) {
        webhookType = 'discord';
      }

      // Format payload
      const payload = formatWebhookPayload(alert, webhookType);

      // Generate signature
      const timestamp = Date.now().toString();
      const signatureData = `${timestamp}.${JSON.stringify(payload)}`;
      const signature = createHmac('sha256', webhook.secret)
        .update(signatureData)
        .digest('hex');

      // Attempt delivery with retry (3 attempts)
      let success = false;
      let lastError: string | undefined;

      for (let attempt = 1; attempt <= 3; attempt++) {
        try {
          const response = await fetch(webhook.url, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'X-Runic-Signature': `t=${timestamp},v1=${signature}`,
              'X-Runic-Event': 'alert.created'
            },
            body: JSON.stringify(payload)
          });

          if (response.ok) {
            success = true;
            delivered++;
            break;
          } else {
            lastError = `HTTP ${response.status}: ${response.statusText}`;
          }
        } catch (error) {
          lastError = error instanceof Error ? error.message : 'Unknown error';
        }

        // Wait before retry (exponential backoff)
        if (attempt < 3) {
          await new Promise(resolve => setTimeout(resolve, Math.pow(2, attempt) * 1000));
        }
      }

      if (!success) {
        failed++;
      }

      results.push({
        webhookID: webhook.id,
        success,
        error: success ? undefined : lastError
      });
    }
  }

  return { delivered, failed, results };
}

/**
 * Webhook delivery log entry
 */
interface WebhookDelivery {
  id: string;
  webhookID: string;
  url: string;
  event: WebSocketMessageType;
  payload: any;
  statusCode?: number;
  success: boolean;
  error?: string;
  deliveredAt: string;
  responseTime?: number; // in milliseconds
}

/**
 * Mock webhook configurations
 * In production, this would be stored in the database
 */
const mockWebhooks: Record<string, WebhookConfig> = {
  'webhook-001': {
    id: 'webhook-001',
    url: 'https://api.example.com/webhooks/runic',
    events: [
      WebSocketMessageType.UsageUpdate,
      WebSocketMessageType.AlertCreated
    ],
    secret: 'whsec_' + randomBytes(32).toString('hex'),
    enabled: true,
    createdAt: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString()
  },
  'webhook-002': {
    id: 'webhook-002',
    url: 'https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXX',
    events: [
      WebSocketMessageType.AlertCreated
    ],
    secret: 'whsec_' + randomBytes(32).toString('hex'),
    enabled: true,
    createdAt: new Date(Date.now() - 14 * 24 * 60 * 60 * 1000).toISOString()
  }
};

/**
 * Mock webhook delivery logs
 */
const mockDeliveries: Record<string, WebhookDelivery> = {
  'delivery-001': {
    id: 'delivery-001',
    webhookID: 'webhook-001',
    url: 'https://api.example.com/webhooks/runic',
    event: WebSocketMessageType.UsageUpdate,
    payload: { provider: 'anthropic', usedPercent: 75.3 },
    statusCode: 200,
    success: true,
    deliveredAt: new Date(Date.now() - 3600000).toISOString(),
    responseTime: 245
  },
  'delivery-002': {
    id: 'delivery-002',
    webhookID: 'webhook-001',
    url: 'https://api.example.com/webhooks/runic',
    event: WebSocketMessageType.AlertCreated,
    payload: { provider: 'openai', severity: 'critical' },
    statusCode: 500,
    success: false,
    error: 'Internal server error',
    deliveredAt: new Date(Date.now() - 1800000).toISOString(),
    responseTime: 5230
  }
};

/**
 * POST /api/v1/webhooks
 *
 * Creates a new webhook configuration
 *
 * Request body:
 * - url: string - Webhook delivery URL (required, must be HTTPS)
 * - events: WebSocketMessageType[] - Events to subscribe to (required)
 * - enabled: boolean - Whether the webhook is active (default: true)
 *
 * @returns {ApiResponse<WebhookConfig>} Created webhook configuration
 */
webhooksRouter.post('/', async (req: Request, res: Response) => {
  try {
    const {
      url,
      events,
      enabled = true
    } = req.body;

    // Validate required fields
    if (!url || !events || !Array.isArray(events) || events.length === 0) {
      const response: ApiResponse<WebhookConfig | null> = {
        data: null,
        timestamp: new Date().toISOString(),
        success: false,
        error: {
          message: 'Missing required fields: url, events',
          code: 'VALIDATION_ERROR'
        }
      };
      return res.status(400).json(response);
    }

    // Validate URL (must be HTTPS)
    try {
      const parsedUrl = new URL(url);
      if (parsedUrl.protocol !== 'https:') {
        const response: ApiResponse<WebhookConfig | null> = {
          data: null,
          timestamp: new Date().toISOString(),
          success: false,
          error: {
            message: 'Webhook URL must use HTTPS',
            code: 'VALIDATION_ERROR'
          }
        };
        return res.status(400).json(response);
      }
    } catch (e) {
      const response: ApiResponse<WebhookConfig | null> = {
        data: null,
        timestamp: new Date().toISOString(),
        success: false,
        error: {
          message: 'Invalid URL format',
          code: 'VALIDATION_ERROR'
        }
      };
      return res.status(400).json(response);
    }

    // Validate events
    const validEvents = Object.values(WebSocketMessageType);
    const invalidEvents = events.filter(e => !validEvents.includes(e));
    if (invalidEvents.length > 0) {
      const response: ApiResponse<WebhookConfig | null> = {
        data: null,
        timestamp: new Date().toISOString(),
        success: false,
        error: {
          message: `Invalid event types: ${invalidEvents.join(', ')}`,
          code: 'VALIDATION_ERROR'
        }
      };
      return res.status(400).json(response);
    }

    // Generate webhook secret
    const secret = 'whsec_' + randomBytes(32).toString('hex');

    // Create webhook configuration
    const webhook: WebhookConfig = {
      id: 'webhook-' + randomBytes(8).toString('hex'),
      url,
      events,
      secret,
      enabled,
      createdAt: new Date().toISOString()
    };

    // In production, save to database
    // const savedWebhook = await db.createWebhook(webhook);

    const response: ApiResponse<WebhookConfig> = {
      data: webhook,
      timestamp: new Date().toISOString(),
      success: true
    };

    return res.status(201).json(response);
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    const response: ApiResponse<WebhookConfig | null> = {
      data: null,
      timestamp: new Date().toISOString(),
      success: false,
      error: {
        message: errorMessage,
        code: 'WEBHOOK_CREATE_ERROR'
      }
    };
    return res.status(500).json(response);
  }
});

/**
 * GET /api/v1/webhooks
 *
 * Retrieves all webhook configurations
 *
 * Query parameters:
 * - page: number - Page number for pagination (default: 1)
 * - pageSize: number - Number of items per page (default: 20, max: 100)
 * - enabled: boolean - Filter by enabled status (optional)
 *
 * @returns {ApiResponse<PaginatedResponse<WebhookConfig>>} Paginated list of webhooks
 */
webhooksRouter.get('/', async (req: Request, res: Response) => {
  try {
    const page = Math.max(1, parseInt(req.query.page as string) || 1);
    const pageSize = Math.min(100, Math.max(1, parseInt(req.query.pageSize as string) || 20));
    const enabledFilter = req.query.enabled !== undefined ?
      req.query.enabled === 'true' :
      undefined;

    // Get all webhooks
    let webhooks = Object.values(mockWebhooks);

    // Apply filters
    if (enabledFilter !== undefined) {
      webhooks = webhooks.filter(w => w.enabled === enabledFilter);
    }

    // Sort by creation date (newest first)
    webhooks.sort((a, b) => {
      return new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime();
    });

    // Paginate
    const totalItems = webhooks.length;
    const totalPages = Math.ceil(totalItems / pageSize);
    const startIndex = (page - 1) * pageSize;
    const endIndex = startIndex + pageSize;
    const paginatedWebhooks = webhooks.slice(startIndex, endIndex);

    const paginatedResponse: PaginatedResponse<WebhookConfig> = {
      data: paginatedWebhooks,
      pagination: {
        page,
        pageSize,
        totalPages,
        totalItems
      }
    };

    const response: ApiResponse<PaginatedResponse<WebhookConfig>> = {
      data: paginatedResponse,
      timestamp: new Date().toISOString(),
      success: true
    };

    return res.json(response);
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    const response: ApiResponse<PaginatedResponse<WebhookConfig>> = {
      data: {
        data: [],
        pagination: { page: 1, pageSize: 20, totalPages: 0, totalItems: 0 }
      },
      timestamp: new Date().toISOString(),
      success: false,
      error: {
        message: errorMessage,
        code: 'WEBHOOKS_FETCH_ERROR'
      }
    };
    return res.status(500).json(response);
  }
});

/**
 * GET /api/v1/webhooks/:webhookID
 *
 * Retrieves details for a specific webhook
 *
 * Path parameters:
 * - webhookID: string - Webhook identifier
 *
 * @returns {ApiResponse<WebhookConfig>} Webhook configuration
 */
webhooksRouter.get('/:webhookID', async (req: Request, res: Response) => {
  try {
    const { webhookID } = req.params;

    // Fetch webhook data
    const webhook = mockWebhooks[webhookID];

    if (!webhook) {
      const response: ApiResponse<WebhookConfig | null> = {
        data: null,
        timestamp: new Date().toISOString(),
        success: false,
        error: {
          message: `Webhook '${webhookID}' not found`,
          code: 'WEBHOOK_NOT_FOUND'
        }
      };
      return res.status(404).json(response);
    }

    const response: ApiResponse<WebhookConfig> = {
      data: webhook,
      timestamp: new Date().toISOString(),
      success: true
    };

    return res.json(response);
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    const response: ApiResponse<WebhookConfig | null> = {
      data: null,
      timestamp: new Date().toISOString(),
      success: false,
      error: {
        message: errorMessage,
        code: 'WEBHOOK_FETCH_ERROR'
      }
    };
    return res.status(500).json(response);
  }
});

/**
 * GET /api/v1/webhooks/:webhookID/deliveries
 *
 * Retrieves delivery logs for a specific webhook
 *
 * Path parameters:
 * - webhookID: string - Webhook identifier
 *
 * Query parameters:
 * - page: number - Page number for pagination (default: 1)
 * - pageSize: number - Number of items per page (default: 20, max: 100)
 * - success: boolean - Filter by success status (optional)
 *
 * @returns {ApiResponse<PaginatedResponse<WebhookDelivery>>} Paginated delivery logs
 */
webhooksRouter.get('/:webhookID/deliveries', async (req: Request, res: Response) => {
  try {
    const { webhookID } = req.params;
    const page = Math.max(1, parseInt(req.query.page as string) || 1);
    const pageSize = Math.min(100, Math.max(1, parseInt(req.query.pageSize as string) || 20));
    const successFilter = req.query.success !== undefined ?
      req.query.success === 'true' :
      undefined;

    // Check if webhook exists
    if (!mockWebhooks[webhookID]) {
      const response: ApiResponse<PaginatedResponse<WebhookDelivery>> = {
        data: {
          data: [],
          pagination: { page: 1, pageSize: 20, totalPages: 0, totalItems: 0 }
        },
        timestamp: new Date().toISOString(),
        success: false,
        error: {
          message: `Webhook '${webhookID}' not found`,
          code: 'WEBHOOK_NOT_FOUND'
        }
      };
      return res.status(404).json(response);
    }

    // Get deliveries for this webhook
    let deliveries = Object.values(mockDeliveries).filter(d => d.webhookID === webhookID);

    // Apply filters
    if (successFilter !== undefined) {
      deliveries = deliveries.filter(d => d.success === successFilter);
    }

    // Sort by delivery time (newest first)
    deliveries.sort((a, b) => {
      return new Date(b.deliveredAt).getTime() - new Date(a.deliveredAt).getTime();
    });

    // Paginate
    const totalItems = deliveries.length;
    const totalPages = Math.ceil(totalItems / pageSize);
    const startIndex = (page - 1) * pageSize;
    const endIndex = startIndex + pageSize;
    const paginatedDeliveries = deliveries.slice(startIndex, endIndex);

    const paginatedResponse: PaginatedResponse<WebhookDelivery> = {
      data: paginatedDeliveries,
      pagination: {
        page,
        pageSize,
        totalPages,
        totalItems
      }
    };

    const response: ApiResponse<PaginatedResponse<WebhookDelivery>> = {
      data: paginatedResponse,
      timestamp: new Date().toISOString(),
      success: true
    };

    return res.json(response);
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    const response: ApiResponse<PaginatedResponse<WebhookDelivery>> = {
      data: {
        data: [],
        pagination: { page: 1, pageSize: 20, totalPages: 0, totalItems: 0 }
      },
      timestamp: new Date().toISOString(),
      success: false,
      error: {
        message: errorMessage,
        code: 'DELIVERIES_FETCH_ERROR'
      }
    };
    return res.status(500).json(response);
  }
});

/**
 * POST /api/v1/webhooks/test
 *
 * Tests webhook delivery with a sample payload
 *
 * Request body:
 * - webhookID: string - Webhook to test (required)
 *
 * @returns {ApiResponse<any>} Test delivery result
 */
webhooksRouter.post('/test', async (req: Request, res: Response) => {
  try {
    const { webhookID } = req.body;

    if (!webhookID) {
      const response: ApiResponse<null> = {
        data: null,
        timestamp: new Date().toISOString(),
        success: false,
        error: {
          message: 'Missing required field: webhookID',
          code: 'VALIDATION_ERROR'
        }
      };
      return res.status(400).json(response);
    }

    const webhook = mockWebhooks[webhookID];
    if (!webhook) {
      const response: ApiResponse<null> = {
        data: null,
        timestamp: new Date().toISOString(),
        success: false,
        error: {
          message: `Webhook '${webhookID}' not found`,
          code: 'WEBHOOK_NOT_FOUND'
        }
      };
      return res.status(404).json(response);
    }

    // Create test alert
    const testAlert: UsageAlert = {
      id: 'test-alert-001',
      provider: 'anthropic',
      severity: AlertSeverity.Info,
      title: 'Test Alert',
      message: 'This is a test alert from Runic API',
      threshold: 50,
      currentUsage: 25.0,
      recommendation: 'This is a test - no action required',
      createdAt: new Date().toISOString()
    };

    // Deliver to webhook
    const result = await deliverWebhooks([testAlert], [webhook]);

    const response: ApiResponse<typeof result> = {
      data: result,
      timestamp: new Date().toISOString(),
      success: true
    };

    return res.json(response);
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    const response: ApiResponse<null> = {
      data: null,
      timestamp: new Date().toISOString(),
      success: false,
      error: {
        message: errorMessage,
        code: 'WEBHOOK_TEST_ERROR'
      }
    };
    return res.status(500).json(response);
  }
});
