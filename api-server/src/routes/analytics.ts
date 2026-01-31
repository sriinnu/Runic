/**
 * Analytics Routes
 *
 * Provides endpoints for cost analytics and usage trends.
 *
 * Endpoints:
 * - GET /api/v1/analytics/cost - Get cost analytics and breakdowns
 * - GET /api/v1/analytics/trends - Get usage trends and predictions
 *
 * @module routes/analytics
 */

import { Router, Request, Response } from 'express';
import type { ApiResponse } from '../types/index.js';

export const analyticsRouter = Router();

/**
 * Cost breakdown by provider
 */
interface ProviderCost {
  provider: string;
  totalCost: number;
  percentage: number;
  tokens: number;
  requests: number;
}

/**
 * Cost breakdown by model
 */
interface ModelCost {
  model: string;
  provider: string;
  totalCost: number;
  percentage: number;
  tokens: number;
  requests: number;
}

/**
 * Cost breakdown by project
 */
interface ProjectCost {
  projectID: string;
  projectName: string;
  totalCost: number;
  percentage: number;
  tokens: number;
  requests: number;
}

/**
 * Cost analytics response
 */
interface CostAnalytics {
  totalCost: number;
  currency: string;
  period: {
    startDate: string;
    endDate: string;
  };
  byProvider: ProviderCost[];
  byModel: ModelCost[];
  byProject: ProjectCost[];
  dailyAverage: number;
  projectedMonthlyCost: number;
}

/**
 * Usage trend data point
 */
interface TrendDataPoint {
  timestamp: string;
  tokens: number;
  cost: number;
  requests: number;
}

/**
 * Usage trends response
 */
interface UsageTrends {
  period: {
    startDate: string;
    endDate: string;
    granularity: string;
  };
  trends: TrendDataPoint[];
  statistics: {
    averageTokensPerDay: number;
    averageCostPerDay: number;
    averageRequestsPerDay: number;
    peakUsageDate: string;
    peakUsageTokens: number;
    lowestUsageDate: string;
    lowestUsageTokens: number;
  };
  predictions?: {
    nextWeekEstimate: number;
    nextMonthEstimate: number;
    confidenceLevel: number;
  };
}

/**
 * GET /api/v1/analytics/cost
 *
 * Retrieves cost analytics and breakdowns
 *
 * Query parameters:
 * - startDate: string - ISO 8601 start date (default: 30 days ago)
 * - endDate: string - ISO 8601 end date (default: now)
 * - groupBy: 'provider' | 'model' | 'project' | 'all' - Grouping dimension (default: 'all')
 * - currency: string - Currency code (default: 'USD')
 *
 * @returns {ApiResponse<CostAnalytics>} Cost analytics data
 */
analyticsRouter.get('/cost', async (req: Request, res: Response) => {
  try {
    const startDate = req.query.startDate as string || new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();
    const endDate = req.query.endDate as string || new Date().toISOString();
    // const groupBy = (req.query.groupBy as string) || 'all';
    const currency = (req.query.currency as string) || 'USD';

    // In production, calculate from database
    // const analytics = await db.getCostAnalytics(startDate, endDate, groupBy, currency);

    // Mock cost analytics
    const byProvider: ProviderCost[] = [
      {
        provider: 'anthropic',
        totalCost: 45.80,
        percentage: 52.3,
        tokens: 3500000,
        requests: 456
      },
      {
        provider: 'openai',
        totalCost: 35.20,
        percentage: 40.2,
        tokens: 2800000,
        requests: 389
      },
      {
        provider: 'google',
        totalCost: 6.50,
        percentage: 7.5,
        tokens: 1200000,
        requests: 145
      }
    ];

    const byModel: ModelCost[] = [
      {
        model: 'claude-opus-4.5',
        provider: 'anthropic',
        totalCost: 28.50,
        percentage: 32.5,
        tokens: 1800000,
        requests: 234
      },
      {
        model: 'gpt-4-turbo',
        provider: 'openai',
        totalCost: 25.30,
        percentage: 28.9,
        tokens: 1600000,
        requests: 267
      },
      {
        model: 'claude-sonnet-4.5',
        provider: 'anthropic',
        totalCost: 17.30,
        percentage: 19.7,
        tokens: 1700000,
        requests: 222
      },
      {
        model: 'gpt-3.5-turbo',
        provider: 'openai',
        totalCost: 9.90,
        percentage: 11.3,
        tokens: 1200000,
        requests: 122
      },
      {
        model: 'gemini-pro',
        provider: 'google',
        totalCost: 6.50,
        percentage: 7.5,
        tokens: 1200000,
        requests: 145
      }
    ];

    const byProject: ProjectCost[] = [
      {
        projectID: 'proj-123',
        projectName: 'Runic API Server',
        totalCost: 48.70,
        percentage: 55.6,
        tokens: 3800000,
        requests: 567
      },
      {
        projectID: 'proj-456',
        projectName: 'Runic iOS App',
        totalCost: 26.30,
        percentage: 30.0,
        tokens: 2100000,
        requests: 345
      },
      {
        projectID: 'proj-789',
        projectName: 'Documentation Generator',
        totalCost: 12.50,
        percentage: 14.4,
        tokens: 1600000,
        requests: 178
      }
    ];

    const totalCost = byProvider.reduce((sum, p) => sum + p.totalCost, 0);
    const daysDiff = Math.max(1, Math.ceil((new Date(endDate).getTime() - new Date(startDate).getTime()) / (1000 * 60 * 60 * 24)));
    const dailyAverage = totalCost / daysDiff;
    const projectedMonthlyCost = dailyAverage * 30;

    const analytics: CostAnalytics = {
      totalCost,
      currency,
      period: {
        startDate,
        endDate
      },
      byProvider,
      byModel,
      byProject,
      dailyAverage,
      projectedMonthlyCost
    };

    const response: ApiResponse<CostAnalytics> = {
      data: analytics,
      timestamp: new Date().toISOString(),
      success: true
    };

    return res.json(response);
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    const response: ApiResponse<CostAnalytics | null> = {
      data: null,
      timestamp: new Date().toISOString(),
      success: false,
      error: {
        message: errorMessage,
        code: 'COST_ANALYTICS_ERROR'
      }
    };
    return res.status(500).json(response);
  }
});

/**
 * GET /api/v1/analytics/trends
 *
 * Retrieves usage trends and predictions
 *
 * Query parameters:
 * - startDate: string - ISO 8601 start date (default: 30 days ago)
 * - endDate: string - ISO 8601 end date (default: now)
 * - granularity: 'hour' | 'day' | 'week' | 'month' - Data granularity (default: 'day')
 * - provider: string - Filter by provider (optional)
 * - includePredictions: boolean - Include future predictions (default: false)
 *
 * @returns {ApiResponse<UsageTrends>} Usage trends data
 */
analyticsRouter.get('/trends', async (req: Request, res: Response) => {
  try {
    const startDate = req.query.startDate as string || new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();
    const endDate = req.query.endDate as string || new Date().toISOString();
    const granularity = (req.query.granularity as string) || 'day';
    // const provider = req.query.provider as string | undefined;
    const includePredictions = req.query.includePredictions === 'true';

    // In production, calculate from database
    // const trends = await db.getUsageTrends(startDate, endDate, granularity, provider);

    // Mock trend data (last 7 days)
    const trends: TrendDataPoint[] = [];
    for (let i = 6; i >= 0; i--) {
      const date = new Date(Date.now() - i * 24 * 60 * 60 * 1000);
      trends.push({
        timestamp: date.toISOString(),
        tokens: Math.floor(200000 + Math.random() * 100000),
        cost: Math.floor((2.5 + Math.random() * 1.5) * 100) / 100,
        requests: Math.floor(30 + Math.random() * 20)
      });
    }

    const totalTokens = trends.reduce((sum, t) => sum + t.tokens, 0);
    const totalCost = trends.reduce((sum, t) => sum + t.cost, 0);
    const totalRequests = trends.reduce((sum, t) => sum + t.requests, 0);
    const days = trends.length;

    const peakUsage = trends.reduce((max, t) => t.tokens > max.tokens ? t : max, trends[0]);
    const lowestUsage = trends.reduce((min, t) => t.tokens < min.tokens ? t : min, trends[0]);

    const statistics = {
      averageTokensPerDay: Math.floor(totalTokens / days),
      averageCostPerDay: Math.floor((totalCost / days) * 100) / 100,
      averageRequestsPerDay: Math.floor(totalRequests / days),
      peakUsageDate: peakUsage.timestamp,
      peakUsageTokens: peakUsage.tokens,
      lowestUsageDate: lowestUsage.timestamp,
      lowestUsageTokens: lowestUsage.tokens
    };

    const usageTrends: UsageTrends = {
      period: {
        startDate,
        endDate,
        granularity
      },
      trends,
      statistics
    };

    // Add predictions if requested
    if (includePredictions) {
      const avgDailyCost = statistics.averageCostPerDay;
      usageTrends.predictions = {
        nextWeekEstimate: Math.floor(avgDailyCost * 7 * 100) / 100,
        nextMonthEstimate: Math.floor(avgDailyCost * 30 * 100) / 100,
        confidenceLevel: 0.75 // 75% confidence based on historical data
      };
    }

    const response: ApiResponse<UsageTrends> = {
      data: usageTrends,
      timestamp: new Date().toISOString(),
      success: true
    };

    return res.json(response);
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    const response: ApiResponse<UsageTrends | null> = {
      data: null,
      timestamp: new Date().toISOString(),
      success: false,
      error: {
        message: errorMessage,
        code: 'TRENDS_ANALYTICS_ERROR'
      }
    };
    return res.status(500).json(response);
  }
});
