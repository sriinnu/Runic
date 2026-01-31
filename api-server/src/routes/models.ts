/**
 * Models Routes
 *
 * Provides endpoints for retrieving model usage information and statistics.
 *
 * Endpoints:
 * - GET /api/v1/models - Get all models used across providers
 * - GET /api/v1/models/:modelName - Get detailed information about a specific model
 *
 * @module routes/models
 */

import { Router, Request, Response } from 'express';
import {
  ModelFamily,
  ModelTier
} from '../types/index.js';
import type {
  ModelUsageInfo,
  ApiResponse,
  PaginatedResponse
} from '../types/index.js';

export const modelsRouter = Router();

/**
 * Extended model information including usage statistics
 */
interface ModelUsageStats extends ModelUsageInfo {
  totalTokens: number;
  totalCost: number;
  providers: string[];
  lastUsed: string;
  usageCount: number;
}

/**
 * Mock model data for development
 * In production, this would be aggregated from the database
 */
const mockModels: Record<string, ModelUsageStats> = {
  'claude-opus-4.5': {
    modelName: 'claude-opus-4.5',
    modelFamily: ModelFamily.Claude4,
    version: '4.5',
    tier: ModelTier.Opus,
    displayName: 'Claude Opus 4.5',
    totalTokens: 1500000,
    totalCost: 24.50,
    providers: ['anthropic'],
    lastUsed: new Date(Date.now() - 3600000).toISOString(),
    usageCount: 145
  },
  'claude-sonnet-4.5': {
    modelName: 'claude-sonnet-4.5',
    modelFamily: ModelFamily.Claude4,
    version: '4.5',
    tier: ModelTier.Sonnet,
    displayName: 'Claude Sonnet 4.5',
    totalTokens: 850000,
    totalCost: 8.50,
    providers: ['anthropic'],
    lastUsed: new Date(Date.now() - 7200000).toISOString(),
    usageCount: 89
  },
  'gpt-4-turbo': {
    modelName: 'gpt-4-turbo',
    modelFamily: ModelFamily.GPT4,
    version: 'turbo',
    tier: ModelTier.Turbo,
    displayName: 'GPT-4 Turbo',
    totalTokens: 2200000,
    totalCost: 33.00,
    providers: ['openai'],
    lastUsed: new Date(Date.now() - 1800000).toISOString(),
    usageCount: 203
  },
  'gpt-3.5-turbo': {
    modelName: 'gpt-3.5-turbo',
    modelFamily: ModelFamily.GPT35,
    version: 'turbo',
    tier: ModelTier.Turbo,
    displayName: 'GPT-3.5 Turbo',
    totalTokens: 5000000,
    totalCost: 10.00,
    providers: ['openai'],
    lastUsed: new Date(Date.now() - 900000).toISOString(),
    usageCount: 567
  },
  'gemini-pro': {
    modelName: 'gemini-pro',
    modelFamily: ModelFamily.Gemini,
    version: '1.0',
    tier: ModelTier.Standard,
    displayName: 'Gemini Pro',
    totalTokens: 1200000,
    totalCost: 6.00,
    providers: ['google'],
    lastUsed: new Date(Date.now() - 5400000).toISOString(),
    usageCount: 78
  }
};

/**
 * GET /api/v1/models
 *
 * Retrieves all models used across providers with usage statistics
 *
 * Query parameters:
 * - page: number - Page number for pagination (default: 1)
 * - pageSize: number - Number of items per page (default: 20, max: 100)
 * - sortBy: 'name' | 'usage' | 'cost' | 'lastUsed' - Sort field (default: 'lastUsed')
 * - order: 'asc' | 'desc' - Sort order (default: 'desc')
 * - family: ModelFamily - Filter by model family
 * - tier: ModelTier - Filter by model tier
 * - provider: string - Filter by provider
 *
 * @returns {ApiResponse<PaginatedResponse<ModelUsageStats>>} Paginated list of models with usage stats
 */
modelsRouter.get('/', async (req: Request, res: Response) => {
  try {
    const page = Math.max(1, parseInt(req.query.page as string) || 1);
    const pageSize = Math.min(100, Math.max(1, parseInt(req.query.pageSize as string) || 20));
    const sortBy = (req.query.sortBy as string) || 'lastUsed';
    const order = (req.query.order as string) || 'desc';
    const familyFilter = req.query.family as ModelFamily | undefined;
    const tierFilter = req.query.tier as ModelTier | undefined;
    const providerFilter = req.query.provider as string | undefined;

    // Get all models
    let models = Object.values(mockModels);

    // Apply filters
    if (familyFilter) {
      models = models.filter(m => m.modelFamily === familyFilter);
    }
    if (tierFilter) {
      models = models.filter(m => m.tier === tierFilter);
    }
    if (providerFilter) {
      models = models.filter(m => m.providers.includes(providerFilter));
    }

    // Sort models
    models.sort((a, b) => {
      let comparison = 0;
      switch (sortBy) {
        case 'name':
          comparison = a.modelName.localeCompare(b.modelName);
          break;
        case 'usage':
          comparison = a.totalTokens - b.totalTokens;
          break;
        case 'cost':
          comparison = a.totalCost - b.totalCost;
          break;
        case 'lastUsed':
          comparison = new Date(a.lastUsed).getTime() - new Date(b.lastUsed).getTime();
          break;
        default:
          comparison = 0;
      }
      return order === 'asc' ? comparison : -comparison;
    });

    // Paginate
    const totalItems = models.length;
    const totalPages = Math.ceil(totalItems / pageSize);
    const startIndex = (page - 1) * pageSize;
    const endIndex = startIndex + pageSize;
    const paginatedModels = models.slice(startIndex, endIndex);

    const paginatedResponse: PaginatedResponse<ModelUsageStats> = {
      data: paginatedModels,
      pagination: {
        page,
        pageSize,
        totalPages,
        totalItems
      }
    };

    const response: ApiResponse<PaginatedResponse<ModelUsageStats>> = {
      data: paginatedResponse,
      timestamp: new Date().toISOString(),
      success: true
    };

    return res.json(response);
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    const response: ApiResponse<PaginatedResponse<ModelUsageStats>> = {
      data: {
        data: [],
        pagination: { page: 1, pageSize: 20, totalPages: 0, totalItems: 0 }
      },
      timestamp: new Date().toISOString(),
      success: false,
      error: {
        message: errorMessage,
        code: 'MODELS_FETCH_ERROR'
      }
    };
    return res.status(500).json(response);
  }
});

/**
 * GET /api/v1/models/:modelName
 *
 * Retrieves detailed information about a specific model
 *
 * Path parameters:
 * - modelName: string - Model identifier (e.g., 'claude-opus-4.5', 'gpt-4-turbo')
 *
 * Query parameters:
 * - includeHistory: boolean - Include usage history (default: false)
 * - historyDays: number - Number of days of history to include (default: 30)
 *
 * @returns {ApiResponse<ModelUsageStats>} Detailed model information and statistics
 */
modelsRouter.get('/:modelName', async (req: Request, res: Response) => {
  try {
    const { modelName } = req.params;
    // const includeHistory = req.query.includeHistory === 'true';
    // const historyDays = parseInt(req.query.historyDays as string) || 30;

    // Fetch model data
    const modelData = mockModels[modelName];

    if (!modelData) {
      const response: ApiResponse<ModelUsageStats | null> = {
        data: null,
        timestamp: new Date().toISOString(),
        success: false,
        error: {
          message: `Model '${modelName}' not found`,
          code: 'MODEL_NOT_FOUND'
        }
      };
      return res.status(404).json(response);
    }

    // In production, fetch historical data if requested
    // if (includeHistory) {
    //   const history = await db.getModelHistory(modelName, historyDays);
    //   modelData.history = history;
    // }

    const response: ApiResponse<ModelUsageStats> = {
      data: modelData,
      timestamp: new Date().toISOString(),
      success: true
    };

    return res.json(response);
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    const response: ApiResponse<ModelUsageStats | null> = {
      data: null,
      timestamp: new Date().toISOString(),
      success: false,
      error: {
        message: errorMessage,
        code: 'MODEL_FETCH_ERROR'
      }
    };
    return res.status(500).json(response);
  }
});

/**
 * GET /api/v1/models/:modelName/usage
 *
 * Retrieves usage statistics for a specific model over time
 *
 * Path parameters:
 * - modelName: string - Model identifier
 *
 * Query parameters:
 * - startDate: string - ISO 8601 start date (default: 30 days ago)
 * - endDate: string - ISO 8601 end date (default: now)
 * - granularity: 'hour' | 'day' | 'week' | 'month' - Data granularity (default: 'day')
 *
 * @returns {ApiResponse<any[]>} Usage statistics over time
 */
modelsRouter.get('/:modelName/usage', async (req: Request, res: Response) => {
  try {
    const { modelName } = req.params;
    // const startDate = req.query.startDate as string || new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();
    // const endDate = req.query.endDate as string || new Date().toISOString();
    // const granularity = req.query.granularity as string || 'day';

    // Check if model exists
    if (!mockModels[modelName]) {
      const response: ApiResponse<any[]> = {
        data: [],
        timestamp: new Date().toISOString(),
        success: false,
        error: {
          message: `Model '${modelName}' not found`,
          code: 'MODEL_NOT_FOUND'
        }
      };
      return res.status(404).json(response);
    }

    // In production, fetch usage history from database
    // const usageHistory = await db.getModelUsageHistory(modelName, startDate, endDate, granularity);

    // Mock usage history
    const usageHistory = [
      {
        timestamp: new Date().toISOString(),
        tokens: mockModels[modelName].totalTokens,
        cost: mockModels[modelName].totalCost,
        requestCount: mockModels[modelName].usageCount
      }
    ];

    const response: ApiResponse<any[]> = {
      data: usageHistory,
      timestamp: new Date().toISOString(),
      success: true
    };

    return res.json(response);
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    const response: ApiResponse<any[]> = {
      data: [],
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
