/**
 * Usage Routes
 *
 * Provides endpoints for retrieving usage data across all providers or for specific providers.
 *
 * Endpoints:
 * - GET /api/v1/usage - Get usage snapshots for all providers
 * - GET /api/v1/usage/:provider - Get usage snapshot for a specific provider
 *
 * @module routes/usage
 */

import { Router, Request, Response } from 'express';
import {
  AccountType,
  ResetType,
  ModelFamily,
  ModelTier
} from '../types/index.js';
import type {
  EnhancedUsageSnapshot,
  ApiResponse
} from '../types/index.js';

export const usageRouter = Router();

/**
 * Mock usage data for development
 * In production, this would be fetched from the database
 */
const mockUsageData: Record<string, EnhancedUsageSnapshot> = {
  anthropic: {
    provider: 'anthropic',
    primary: {
      usedPercent: 45.5,
      resetsAt: new Date(Date.now() + 86400000).toISOString(),
      resetDescription: 'Resets daily at midnight UTC'
    },
    secondary: {
      usedPercent: 30.2,
      windowMinutes: 60,
      resetsAt: new Date(Date.now() + 3600000).toISOString(),
      resetDescription: 'Hourly limit'
    },
    accountType: AccountType.UsageBased,
    accountEmail: 'user@example.com',
    primaryReset: {
      resetType: ResetType.Daily,
      resetAt: new Date(Date.now() + 86400000).toISOString(),
      resetsAutomatically: true,
      timeUntilReset: 86400,
      resetDescription: 'Resets daily at midnight UTC'
    },
    recentModels: [
      {
        modelName: 'claude-opus-4.5',
        modelFamily: ModelFamily.Claude4,
        version: '4.5',
        tier: ModelTier.Opus,
        displayName: 'Claude Opus 4.5'
      },
      {
        modelName: 'claude-sonnet-4.5',
        modelFamily: ModelFamily.Claude4,
        version: '4.5',
        tier: ModelTier.Sonnet,
        displayName: 'Claude Sonnet 4.5'
      }
    ],
    primaryModel: {
      modelName: 'claude-opus-4.5',
      modelFamily: ModelFamily.Claude4,
      version: '4.5',
      tier: ModelTier.Opus,
      displayName: 'Claude Opus 4.5'
    },
    activeProject: {
      projectID: 'proj-123',
      projectName: 'Runic API Server',
      workspacePath: '/Users/dev/runic/api-server',
      repository: 'github.com/runic/api-server',
      tags: ['api', 'typescript', 'express'],
      displayName: 'Runic API Server'
    },
    recentProjects: [
      {
        projectID: 'proj-123',
        projectName: 'Runic API Server',
        workspacePath: '/Users/dev/runic/api-server',
        repository: 'github.com/runic/api-server',
        tags: ['api', 'typescript', 'express'],
        displayName: 'Runic API Server'
      }
    ],
    sessionID: 'session-abc-123',
    sessionStartedAt: new Date(Date.now() - 7200000).toISOString(),
    tokenUsage: {
      inputTokens: 125000,
      outputTokens: 45000,
      cacheCreationTokens: 10000,
      cacheReadTokens: 50000,
      totalTokens: 230000,
      modelBreakdown: {
        'claude-opus-4.5': 150000,
        'claude-sonnet-4.5': 80000
      },
      projectBreakdown: {
        'proj-123': 230000
      }
    },
    estimatedCost: 2.45,
    costCurrency: 'USD',
    updatedAt: new Date().toISOString(),
    fetchSource: 'oauth'
  },
  openai: {
    provider: 'openai',
    primary: {
      usedPercent: 62.8,
      resetsAt: new Date(Date.now() + 86400000).toISOString(),
      resetDescription: 'Resets daily at midnight UTC'
    },
    accountType: AccountType.UsageBased,
    accountEmail: 'user@example.com',
    primaryReset: {
      resetType: ResetType.Daily,
      resetAt: new Date(Date.now() + 86400000).toISOString(),
      resetsAutomatically: true,
      timeUntilReset: 86400,
      resetDescription: 'Resets daily at midnight UTC'
    },
    recentModels: [
      {
        modelName: 'gpt-4-turbo',
        modelFamily: ModelFamily.GPT4,
        version: 'turbo',
        tier: ModelTier.Turbo,
        displayName: 'GPT-4 Turbo'
      }
    ],
    primaryModel: {
      modelName: 'gpt-4-turbo',
      modelFamily: ModelFamily.GPT4,
      version: 'turbo',
      tier: ModelTier.Turbo,
      displayName: 'GPT-4 Turbo'
    },
    recentProjects: [],
    estimatedCost: 3.67,
    costCurrency: 'USD',
    updatedAt: new Date().toISOString(),
    fetchSource: 'oauth'
  }
};

/**
 * GET /api/v1/usage
 *
 * Retrieves usage snapshots for all providers
 *
 * Query parameters:
 * - limit: number - Maximum number of providers to return (default: 10)
 * - offset: number - Offset for pagination (default: 0)
 *
 * @returns {ApiResponse<Record<string, EnhancedUsageSnapshot>>} Usage data for all providers
 */
usageRouter.get('/', async (req: Request, res: Response) => {
  try {
    const limit = parseInt(req.query.limit as string) || 10;
    const offset = parseInt(req.query.offset as string) || 0;

    // In production, fetch from database with pagination
    const allProviders = Object.keys(mockUsageData);
    const paginatedProviders = allProviders.slice(offset, offset + limit);

    const usageData = paginatedProviders.reduce((acc, provider) => {
      acc[provider] = mockUsageData[provider];
      return acc;
    }, {} as Record<string, EnhancedUsageSnapshot>);

    const response: ApiResponse<Record<string, EnhancedUsageSnapshot>> = {
      data: usageData,
      timestamp: new Date().toISOString(),
      success: true
    };

    return res.json(response);
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    const response: ApiResponse<Record<string, EnhancedUsageSnapshot>> = {
      data: {},
      timestamp: new Date().toISOString(),
      success: false,
      error: {
        message: errorMessage,
        code: 'USAGE_FETCH_ERROR'
      }
    };
    return res.status(500).json(response);
  }
});

/**
 * GET /api/v1/usage/:provider
 *
 * Retrieves usage snapshot for a specific provider
 *
 * Path parameters:
 * - provider: string - Provider identifier (e.g., 'anthropic', 'openai', 'google')
 *
 * Query parameters:
 * - includeHistory: boolean - Include historical usage data (default: false)
 *
 * @returns {ApiResponse<EnhancedUsageSnapshot>} Usage data for the specified provider
 */
usageRouter.get('/:provider', async (req: Request, res: Response) => {
  try {
    const { provider } = req.params;
    // const includeHistory = req.query.includeHistory === 'true';

    // Fetch usage data for the specific provider
    const usageData = mockUsageData[provider];

    if (!usageData) {
      const response: ApiResponse<EnhancedUsageSnapshot | null> = {
        data: null,
        timestamp: new Date().toISOString(),
        success: false,
        error: {
          message: `Provider '${provider}' not found`,
          code: 'PROVIDER_NOT_FOUND'
        }
      };
      return res.status(404).json(response);
    }

    // In production, fetch historical data if requested
    // const history = includeHistory ? await db.getUsageHistory(provider) : undefined;

    const response: ApiResponse<EnhancedUsageSnapshot> = {
      data: usageData,
      timestamp: new Date().toISOString(),
      success: true
    };

    return res.json(response);
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    const response: ApiResponse<EnhancedUsageSnapshot | null> = {
      data: null,
      timestamp: new Date().toISOString(),
      success: false,
      error: {
        message: errorMessage,
        code: 'USAGE_FETCH_ERROR'
      }
    };
    return res.status(500).json(response);
  }
});

/**
 * GET /api/v1/usage/:provider/history
 *
 * Retrieves historical usage data for a specific provider
 *
 * Path parameters:
 * - provider: string - Provider identifier
 *
 * Query parameters:
 * - startDate: string - ISO 8601 start date (default: 30 days ago)
 * - endDate: string - ISO 8601 end date (default: now)
 * - granularity: 'hour' | 'day' | 'week' | 'month' - Data granularity (default: 'day')
 *
 * @returns {ApiResponse<EnhancedUsageSnapshot[]>} Historical usage data
 */
usageRouter.get('/:provider/history', async (req: Request, res: Response) => {
  try {
    const { provider } = req.params;
    // const startDate = req.query.startDate as string || new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();
    // const endDate = req.query.endDate as string || new Date().toISOString();
    // const granularity = req.query.granularity as string || 'day';

    // Check if provider exists
    if (!mockUsageData[provider]) {
      const response: ApiResponse<EnhancedUsageSnapshot[]> = {
        data: [],
        timestamp: new Date().toISOString(),
        success: false,
        error: {
          message: `Provider '${provider}' not found`,
          code: 'PROVIDER_NOT_FOUND'
        }
      };
      return res.status(404).json(response);
    }

    // In production, fetch historical data from database
    // const history = await db.getUsageHistory(provider, startDate, endDate, granularity);

    // Mock historical data
    const history: EnhancedUsageSnapshot[] = [mockUsageData[provider]];

    const response: ApiResponse<EnhancedUsageSnapshot[]> = {
      data: history,
      timestamp: new Date().toISOString(),
      success: true
    };

    return res.json(response);
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    const response: ApiResponse<EnhancedUsageSnapshot[]> = {
      data: [],
      timestamp: new Date().toISOString(),
      success: false,
      error: {
        message: errorMessage,
        code: 'HISTORY_FETCH_ERROR'
      }
    };
    return res.status(500).json(response);
  }
});
