/**
 * Resets Routes
 *
 * Provides endpoints for retrieving usage reset information across providers.
 *
 * Endpoints:
 * - GET /api/v1/resets - Get reset schedules for all providers
 *
 * @module routes/resets
 */

import { Router, Request, Response } from 'express';
import {
  ResetType
} from '../types/index.js';
import type {
  UsageResetInfo,
  ApiResponse
} from '../types/index.js';

export const resetsRouter = Router();

/**
 * Provider reset schedule information
 */
interface ProviderResetSchedule {
  provider: string;
  primaryReset: UsageResetInfo;
  secondaryReset?: UsageResetInfo;
  tertiaryReset?: UsageResetInfo;
  timezone: string;
  nextResetAt: string;
}

/**
 * Mock reset schedule data for development
 * In production, this would be fetched from the database
 */
const mockResetSchedules: Record<string, ProviderResetSchedule> = {
  anthropic: {
    provider: 'anthropic',
    primaryReset: {
      resetType: ResetType.Daily,
      resetAt: new Date(Date.now() + 18 * 60 * 60 * 1000).toISOString(), // 18 hours from now
      windowDuration: 86400, // 24 hours
      resetsAutomatically: true,
      timeUntilReset: 18 * 60 * 60, // 18 hours in seconds
      resetDescription: 'Daily token limit resets at midnight UTC'
    },
    secondaryReset: {
      resetType: ResetType.Hourly,
      resetAt: new Date(Date.now() + 45 * 60 * 1000).toISOString(), // 45 minutes from now
      windowDuration: 3600, // 1 hour
      resetsAutomatically: true,
      timeUntilReset: 45 * 60, // 45 minutes in seconds
      resetDescription: 'Hourly rate limit resets every hour'
    },
    timezone: 'UTC',
    nextResetAt: new Date(Date.now() + 45 * 60 * 1000).toISOString() // Next hourly reset
  },
  openai: {
    provider: 'openai',
    primaryReset: {
      resetType: ResetType.Daily,
      resetAt: new Date(Date.now() + 16 * 60 * 60 * 1000).toISOString(), // 16 hours from now
      windowDuration: 86400, // 24 hours
      resetsAutomatically: true,
      timeUntilReset: 16 * 60 * 60, // 16 hours in seconds
      resetDescription: 'Daily token limit resets at midnight UTC'
    },
    timezone: 'UTC',
    nextResetAt: new Date(Date.now() + 16 * 60 * 60 * 1000).toISOString()
  },
  google: {
    provider: 'google',
    primaryReset: {
      resetType: ResetType.Monthly,
      resetAt: new Date(Date.now() + 15 * 24 * 60 * 60 * 1000).toISOString(), // 15 days from now
      windowDuration: 30 * 24 * 60 * 60, // 30 days
      resetsAutomatically: true,
      timeUntilReset: 15 * 24 * 60 * 60, // 15 days in seconds
      resetDescription: 'Monthly quota resets on the 1st of each month'
    },
    secondaryReset: {
      resetType: ResetType.Daily,
      resetAt: new Date(Date.now() + 20 * 60 * 60 * 1000).toISOString(), // 20 hours from now
      windowDuration: 86400, // 24 hours
      resetsAutomatically: true,
      timeUntilReset: 20 * 60 * 60, // 20 hours in seconds
      resetDescription: 'Daily rate limit resets at midnight UTC'
    },
    timezone: 'UTC',
    nextResetAt: new Date(Date.now() + 20 * 60 * 60 * 1000).toISOString() // Next daily reset
  },
  minimax: {
    provider: 'minimax',
    primaryReset: {
      resetType: ResetType.Weekly,
      resetAt: new Date(Date.now() + 4 * 24 * 60 * 60 * 1000).toISOString(), // 4 days from now
      windowDuration: 7 * 24 * 60 * 60, // 7 days
      resetsAutomatically: true,
      timeUntilReset: 4 * 24 * 60 * 60, // 4 days in seconds
      resetDescription: 'Weekly quota resets every Monday at 00:00 UTC'
    },
    timezone: 'UTC',
    nextResetAt: new Date(Date.now() + 4 * 24 * 60 * 60 * 1000).toISOString()
  },
  cursor: {
    provider: 'cursor',
    primaryReset: {
      resetType: ResetType.SessionBased,
      windowDuration: 0, // No fixed window
      resetsAutomatically: false,
      timeUntilReset: undefined,
      resetDescription: 'Session-based usage tracking. No automatic reset.'
    },
    timezone: 'UTC',
    nextResetAt: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString() // Far future for session-based
  }
};

/**
 * GET /api/v1/resets
 *
 * Retrieves reset schedules for all providers
 *
 * Query parameters:
 * - provider: string - Filter by specific provider (optional)
 * - upcomingOnly: boolean - Only show providers with upcoming resets (default: false)
 * - sortBy: 'provider' | 'nextReset' - Sort field (default: 'nextReset')
 * - order: 'asc' | 'desc' - Sort order (default: 'asc')
 *
 * @returns {ApiResponse<ProviderResetSchedule[]>} Reset schedules for providers
 */
resetsRouter.get('/', async (req: Request, res: Response) => {
  try {
    const providerFilter = req.query.provider as string | undefined;
    const upcomingOnly = req.query.upcomingOnly === 'true';
    const sortBy = (req.query.sortBy as string) || 'nextReset';
    const order = (req.query.order as string) || 'asc';

    // Get all reset schedules
    let schedules = Object.values(mockResetSchedules);

    // Apply filters
    if (providerFilter) {
      schedules = schedules.filter(s => s.provider === providerFilter);
    }

    if (upcomingOnly) {
      const now = Date.now();
      schedules = schedules.filter(s => {
        const nextResetTime = new Date(s.nextResetAt).getTime();
        return nextResetTime > now && nextResetTime < now + 24 * 60 * 60 * 1000; // Within 24 hours
      });
    }

    // Sort schedules
    schedules.sort((a, b) => {
      let comparison = 0;
      switch (sortBy) {
        case 'provider':
          comparison = a.provider.localeCompare(b.provider);
          break;
        case 'nextReset':
          comparison = new Date(a.nextResetAt).getTime() - new Date(b.nextResetAt).getTime();
          break;
        default:
          comparison = 0;
      }
      return order === 'asc' ? comparison : -comparison;
    });

    const response: ApiResponse<ProviderResetSchedule[]> = {
      data: schedules,
      timestamp: new Date().toISOString(),
      success: true
    };

    return res.json(response);
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    const response: ApiResponse<ProviderResetSchedule[]> = {
      data: [],
      timestamp: new Date().toISOString(),
      success: false,
      error: {
        message: errorMessage,
        code: 'RESETS_FETCH_ERROR'
      }
    };
    return res.status(500).json(response);
  }
});

/**
 * GET /api/v1/resets/:provider
 *
 * Retrieves reset schedule for a specific provider
 *
 * Path parameters:
 * - provider: string - Provider identifier
 *
 * @returns {ApiResponse<ProviderResetSchedule>} Reset schedule for the provider
 */
resetsRouter.get('/:provider', async (req: Request, res: Response) => {
  try {
    const { provider } = req.params;

    // Fetch reset schedule for the specific provider
    const schedule = mockResetSchedules[provider];

    if (!schedule) {
      const response: ApiResponse<ProviderResetSchedule | null> = {
        data: null,
        timestamp: new Date().toISOString(),
        success: false,
        error: {
          message: `Reset schedule for provider '${provider}' not found`,
          code: 'PROVIDER_NOT_FOUND'
        }
      };
      return res.status(404).json(response);
    }

    const response: ApiResponse<ProviderResetSchedule> = {
      data: schedule,
      timestamp: new Date().toISOString(),
      success: true
    };

    return res.json(response);
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    const response: ApiResponse<ProviderResetSchedule | null> = {
      data: null,
      timestamp: new Date().toISOString(),
      success: false,
      error: {
        message: errorMessage,
        code: 'RESET_FETCH_ERROR'
      }
    };
    return res.status(500).json(response);
  }
});

/**
 * GET /api/v1/resets/upcoming
 *
 * Retrieves all upcoming resets within the next 24 hours
 *
 * @returns {ApiResponse<ProviderResetSchedule[]>} Upcoming reset schedules
 */
resetsRouter.get('/upcoming/all', async (_req: Request, res: Response) => {
  try {
    const now = Date.now();
    const in24Hours = now + 24 * 60 * 60 * 1000;

    // Filter for upcoming resets
    const upcomingResets = Object.values(mockResetSchedules).filter(s => {
      const nextResetTime = new Date(s.nextResetAt).getTime();
      return nextResetTime > now && nextResetTime <= in24Hours;
    });

    // Sort by time until reset (ascending)
    upcomingResets.sort((a, b) => {
      return new Date(a.nextResetAt).getTime() - new Date(b.nextResetAt).getTime();
    });

    const response: ApiResponse<ProviderResetSchedule[]> = {
      data: upcomingResets,
      timestamp: new Date().toISOString(),
      success: true
    };

    return res.json(response);
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    const response: ApiResponse<ProviderResetSchedule[]> = {
      data: [],
      timestamp: new Date().toISOString(),
      success: false,
      error: {
        message: errorMessage,
        code: 'UPCOMING_RESETS_ERROR'
      }
    };
    return res.status(500).json(response);
  }
});
