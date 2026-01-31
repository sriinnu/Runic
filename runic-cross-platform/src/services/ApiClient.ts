/**
 * @file ApiClient.ts
 * @description HTTP client for making API requests to various AI providers.
 * Handles authentication, error handling, and response parsing.
 */

import axios, { AxiosInstance, AxiosRequestConfig, AxiosError } from 'axios';
import type { ProviderId, Provider } from '../types';

/**
 * API error with additional context
 */
export class ApiError extends Error {
  constructor(
    message: string,
    public statusCode?: number,
    public providerId?: ProviderId
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

/**
 * Configuration for API client initialization
 */
interface ApiClientConfig {
  baseUrl: string;
  apiToken?: string;
  timeout?: number;
}

/**
 * Generic API response wrapper
 * @deprecated Not currently used - may be used in future for standardized responses
 */
// interface ApiResponse<T> {
//   data: T;
//   status: number;
//   message?: string;
// }

/**
 * HTTP client for making authenticated API requests.
 * Provides methods for common HTTP operations with error handling.
 */
class ApiClient {
  private client: AxiosInstance;
  private providerId?: ProviderId;

  /**
   * Creates a new API client instance.
   *
   * @param config - Client configuration
   *
   * @example
   * const client = new ApiClient({
   *   baseUrl: 'https://api.openai.com/v1',
   *   apiToken: 'sk-...',
   * });
   */
  constructor(config: ApiClientConfig) {
    this.client = axios.create({
      baseURL: config.baseUrl,
      timeout: config.timeout || 30000,
      headers: {
        'Content-Type': 'application/json',
        ...(config.apiToken && { Authorization: `Bearer ${config.apiToken}` }),
      },
    });

    // Add request interceptor for logging
    this.client.interceptors.request.use(
      (request) => {
        console.log(`[API] ${request.method?.toUpperCase()} ${request.url}`);
        return request;
      },
      (error) => Promise.reject(error)
    );

    // Add response interceptor for error handling
    this.client.interceptors.response.use(
      (response) => response,
      (error: AxiosError) => {
        return Promise.reject(this.handleError(error));
      }
    );
  }

  /**
   * Sets the provider ID for error context.
   *
   * @param id - Provider identifier
   */
  setProviderId(id: ProviderId): void {
    this.providerId = id;
  }

  /**
   * Handles API errors and converts them to ApiError instances.
   *
   * @param error - Axios error object
   * @returns Formatted API error
   */
  private handleError(error: AxiosError): ApiError {
    if (error.response) {
      // Server responded with error status
      const status = error.response.status;
      const message = this.getErrorMessage(status);
      return new ApiError(message, status, this.providerId);
    } else if (error.request) {
      // Request made but no response received
      return new ApiError('No response from server', undefined, this.providerId);
    } else {
      // Error in request configuration
      return new ApiError(error.message, undefined, this.providerId);
    }
  }

  /**
   * Gets a user-friendly error message based on HTTP status code.
   *
   * @param status - HTTP status code
   * @returns Error message
   */
  private getErrorMessage(status: number): string {
    switch (status) {
      case 401:
        return 'Invalid API token or unauthorized';
      case 403:
        return 'Access forbidden';
      case 404:
        return 'Resource not found';
      case 429:
        return 'Rate limit exceeded';
      case 500:
        return 'Internal server error';
      case 503:
        return 'Service unavailable';
      default:
        return `Request failed with status ${status}`;
    }
  }

  /**
   * Makes a GET request.
   *
   * @param url - Request URL
   * @param config - Optional request configuration
   * @returns Promise with response data
   */
  async get<T>(url: string, config?: AxiosRequestConfig): Promise<T> {
    const response = await this.client.get<T>(url, config);
    return response.data;
  }

  /**
   * Makes a POST request.
   *
   * @param url - Request URL
   * @param data - Request body
   * @param config - Optional request configuration
   * @returns Promise with response data
   */
  async post<T>(
    url: string,
    data?: unknown,
    config?: AxiosRequestConfig
  ): Promise<T> {
    const response = await this.client.post<T>(url, data, config);
    return response.data;
  }

  /**
   * Makes a PUT request.
   *
   * @param url - Request URL
   * @param data - Request body
   * @param config - Optional request configuration
   * @returns Promise with response data
   */
  async put<T>(
    url: string,
    data?: unknown,
    config?: AxiosRequestConfig
  ): Promise<T> {
    const response = await this.client.put<T>(url, data, config);
    return response.data;
  }

  /**
   * Makes a DELETE request.
   *
   * @param url - Request URL
   * @param config - Optional request configuration
   * @returns Promise with response data
   */
  async delete<T>(url: string, config?: AxiosRequestConfig): Promise<T> {
    const response = await this.client.delete<T>(url, config);
    return response.data;
  }

  /**
   * Updates the authorization token.
   *
   * @param token - New API token
   */
  setAuthToken(token: string): void {
    this.client.defaults.headers.common['Authorization'] = `Bearer ${token}`;
  }
}

/**
 * Factory function to create provider-specific API clients.
 *
 * @param provider - Provider configuration
 * @returns Configured API client
 *
 * @example
 * const client = createProviderClient(providerData);
 * const usage = await client.get('/usage');
 */
export function createProviderClient(provider: Provider): ApiClient {
  const config: ApiClientConfig = {
    baseUrl: provider.apiEndpoint,
  };

  if (provider.apiToken !== undefined) {
    config.apiToken = provider.apiToken;
  }

  const client = new ApiClient(config);
  client.setProviderId(provider.id);
  return client;
}

export default ApiClient;
