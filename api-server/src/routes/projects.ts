/**
 * Projects Routes
 *
 * Provides endpoints for retrieving project information and usage statistics.
 *
 * Endpoints:
 * - GET /api/v1/projects - Get all projects with usage data
 * - GET /api/v1/projects/:projectID - Get detailed information about a specific project
 *
 * @module routes/projects
 */

import { Router, Request, Response } from 'express';
import type {
  ProjectInfo,
  ApiResponse,
  PaginatedResponse
} from '../types/index.js';

export const projectsRouter = Router();

/**
 * Extended project information including usage statistics
 */
interface ProjectUsageStats extends ProjectInfo {
  totalTokens: number;
  totalCost: number;
  providers: string[];
  models: string[];
  lastActive: string;
  requestCount: number;
  averageCostPerRequest: number;
}

/**
 * Mock project data for development
 * In production, this would be aggregated from the database
 */
const mockProjects: Record<string, ProjectUsageStats> = {
  'proj-123': {
    projectID: 'proj-123',
    projectName: 'Runic API Server',
    workspacePath: '/Users/dev/runic/api-server',
    repository: 'github.com/runic/api-server',
    tags: ['api', 'typescript', 'express'],
    displayName: 'Runic API Server',
    totalTokens: 2300000,
    totalCost: 34.50,
    providers: ['anthropic', 'openai'],
    models: ['claude-opus-4.5', 'claude-sonnet-4.5', 'gpt-4-turbo'],
    lastActive: new Date(Date.now() - 1800000).toISOString(),
    requestCount: 234,
    averageCostPerRequest: 0.147
  },
  'proj-456': {
    projectID: 'proj-456',
    projectName: 'Runic iOS App',
    workspacePath: '/Users/dev/runic/ios-app',
    repository: 'github.com/runic/ios-app',
    tags: ['ios', 'swift', 'swiftui'],
    displayName: 'Runic iOS App',
    totalTokens: 1500000,
    totalCost: 18.75,
    providers: ['anthropic'],
    models: ['claude-sonnet-4.5', 'claude-haiku-4.0'],
    lastActive: new Date(Date.now() - 3600000).toISOString(),
    requestCount: 167,
    averageCostPerRequest: 0.112
  },
  'proj-789': {
    projectID: 'proj-789',
    projectName: 'Documentation Generator',
    workspacePath: '/Users/dev/doc-gen',
    repository: 'github.com/tools/doc-gen',
    tags: ['documentation', 'automation', 'python'],
    displayName: 'Documentation Generator',
    totalTokens: 850000,
    totalCost: 12.80,
    providers: ['openai'],
    models: ['gpt-4-turbo', 'gpt-3.5-turbo'],
    lastActive: new Date(Date.now() - 7200000).toISOString(),
    requestCount: 95,
    averageCostPerRequest: 0.135
  }
};

/**
 * GET /api/v1/projects
 *
 * Retrieves all projects with usage statistics
 *
 * Query parameters:
 * - page: number - Page number for pagination (default: 1)
 * - pageSize: number - Number of items per page (default: 20, max: 100)
 * - sortBy: 'name' | 'tokens' | 'cost' | 'lastActive' | 'requests' - Sort field (default: 'lastActive')
 * - order: 'asc' | 'desc' - Sort order (default: 'desc')
 * - tag: string - Filter by tag
 * - provider: string - Filter by provider
 *
 * @returns {ApiResponse<PaginatedResponse<ProjectUsageStats>>} Paginated list of projects
 */
projectsRouter.get('/', async (req: Request, res: Response) => {
  try {
    const page = Math.max(1, parseInt(req.query.page as string) || 1);
    const pageSize = Math.min(100, Math.max(1, parseInt(req.query.pageSize as string) || 20));
    const sortBy = (req.query.sortBy as string) || 'lastActive';
    const order = (req.query.order as string) || 'desc';
    const tagFilter = req.query.tag as string | undefined;
    const providerFilter = req.query.provider as string | undefined;

    // Get all projects
    let projects = Object.values(mockProjects);

    // Apply filters
    if (tagFilter) {
      projects = projects.filter(p => p.tags.includes(tagFilter));
    }
    if (providerFilter) {
      projects = projects.filter(p => p.providers.includes(providerFilter));
    }

    // Sort projects
    projects.sort((a, b) => {
      let comparison = 0;
      switch (sortBy) {
        case 'name':
          comparison = a.projectName?.localeCompare(b.projectName || '') || 0;
          break;
        case 'tokens':
          comparison = a.totalTokens - b.totalTokens;
          break;
        case 'cost':
          comparison = a.totalCost - b.totalCost;
          break;
        case 'lastActive':
          comparison = new Date(a.lastActive).getTime() - new Date(b.lastActive).getTime();
          break;
        case 'requests':
          comparison = a.requestCount - b.requestCount;
          break;
        default:
          comparison = 0;
      }
      return order === 'asc' ? comparison : -comparison;
    });

    // Paginate
    const totalItems = projects.length;
    const totalPages = Math.ceil(totalItems / pageSize);
    const startIndex = (page - 1) * pageSize;
    const endIndex = startIndex + pageSize;
    const paginatedProjects = projects.slice(startIndex, endIndex);

    const paginatedResponse: PaginatedResponse<ProjectUsageStats> = {
      data: paginatedProjects,
      pagination: {
        page,
        pageSize,
        totalPages,
        totalItems
      }
    };

    const response: ApiResponse<PaginatedResponse<ProjectUsageStats>> = {
      data: paginatedResponse,
      timestamp: new Date().toISOString(),
      success: true
    };

    return res.json(response);
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    const response: ApiResponse<PaginatedResponse<ProjectUsageStats>> = {
      data: {
        data: [],
        pagination: { page: 1, pageSize: 20, totalPages: 0, totalItems: 0 }
      },
      timestamp: new Date().toISOString(),
      success: false,
      error: {
        message: errorMessage,
        code: 'PROJECTS_FETCH_ERROR'
      }
    };
    return res.status(500).json(response);
  }
});

/**
 * GET /api/v1/projects/:projectID
 *
 * Retrieves detailed information about a specific project
 *
 * Path parameters:
 * - projectID: string - Project identifier
 *
 * Query parameters:
 * - includeHistory: boolean - Include usage history (default: false)
 * - historyDays: number - Number of days of history to include (default: 30)
 *
 * @returns {ApiResponse<ProjectUsageStats>} Detailed project information and statistics
 */
projectsRouter.get('/:projectID', async (req: Request, res: Response) => {
  try {
    const { projectID } = req.params;
    // const includeHistory = req.query.includeHistory === 'true';
    // const historyDays = parseInt(req.query.historyDays as string) || 30;

    // Fetch project data
    const projectData = mockProjects[projectID];

    if (!projectData) {
      const response: ApiResponse<ProjectUsageStats | null> = {
        data: null,
        timestamp: new Date().toISOString(),
        success: false,
        error: {
          message: `Project '${projectID}' not found`,
          code: 'PROJECT_NOT_FOUND'
        }
      };
      return res.status(404).json(response);
    }

    // In production, fetch historical data if requested
    // if (includeHistory) {
    //   const history = await db.getProjectHistory(projectID, historyDays);
    //   projectData.history = history;
    // }

    const response: ApiResponse<ProjectUsageStats> = {
      data: projectData,
      timestamp: new Date().toISOString(),
      success: true
    };

    return res.json(response);
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    const response: ApiResponse<ProjectUsageStats | null> = {
      data: null,
      timestamp: new Date().toISOString(),
      success: false,
      error: {
        message: errorMessage,
        code: 'PROJECT_FETCH_ERROR'
      }
    };
    return res.status(500).json(response);
  }
});

/**
 * GET /api/v1/projects/:projectID/usage
 *
 * Retrieves usage statistics for a specific project over time
 *
 * Path parameters:
 * - projectID: string - Project identifier
 *
 * Query parameters:
 * - startDate: string - ISO 8601 start date (default: 30 days ago)
 * - endDate: string - ISO 8601 end date (default: now)
 * - granularity: 'hour' | 'day' | 'week' | 'month' - Data granularity (default: 'day')
 * - groupBy: 'model' | 'provider' | 'total' - How to group the data (default: 'total')
 *
 * @returns {ApiResponse<any[]>} Usage statistics over time
 */
projectsRouter.get('/:projectID/usage', async (req: Request, res: Response) => {
  try {
    const { projectID } = req.params;
    // const startDate = req.query.startDate as string || new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();
    // const endDate = req.query.endDate as string || new Date().toISOString();
    // const granularity = req.query.granularity as string || 'day';
    const groupBy = req.query.groupBy as string || 'total';

    // Check if project exists
    if (!mockProjects[projectID]) {
      const response: ApiResponse<any[]> = {
        data: [],
        timestamp: new Date().toISOString(),
        success: false,
        error: {
          message: `Project '${projectID}' not found`,
          code: 'PROJECT_NOT_FOUND'
        }
      };
      return res.status(404).json(response);
    }

    // In production, fetch usage history from database
    // const usageHistory = await db.getProjectUsageHistory(projectID, startDate, endDate, granularity, groupBy);

    // Mock usage history
    const project = mockProjects[projectID];
    const usageHistory = [
      {
        timestamp: new Date().toISOString(),
        tokens: project.totalTokens,
        cost: project.totalCost,
        requestCount: project.requestCount,
        breakdown: groupBy === 'model' ?
          { [project.models[0]]: project.totalTokens } :
          groupBy === 'provider' ?
          { [project.providers[0]]: project.totalTokens } :
          { total: project.totalTokens }
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
