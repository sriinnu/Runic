/**
 * @file ApiClient.ts
 * @description HTTP client for making API requests to various AI providers.
 * Handles authentication, error handling, and response parsing.
 */

import axios, { AxiosInstance, AxiosRequestConfig, AxiosError } from 'axios';
import type { ProviderId, Provider } from '../types';

import { ErrorMessage, ErrorMessageBuilder } from '../utils/ErrorMessages';
import { ErrorCode } from '../utils/ErrorCodes';

/**
 * API error with additional context and structured error message
 */
export class ApiError extends Error {
  public readonly errorMessage: ErrorMessage;

  constructor(
    message: string,
    public statusCode?: number,
    public providerId?: ProviderId,
    errorMessage?: ErrorMessage
  ) {
    super(message);
    this.name = 'ApiError';

    // Create structured error message if not provided
    if (errorMessage) {
      this.errorMessage = errorMessage;
    } else if (statusCode) {
      this.errorMessage = ErrorMessageBuilder.apiError({
        provider: providerId || 'API',
        statusCode,
        details: message,
      });
    } else {
      this.errorMessage = ErrorMessageBuilder.networkError({
        provider: providerId,
        reason: message,
      });
    }
  }

  /** Get compact error description for UI display */
  get compactDescription(): string {
    return this.errorMessage.reason;
  }

  /** Get full error description with steps */
  get fullDescription(): string {
    return `${this.errorMessage.title}\n${this.errorMessage.reason}\n\nNext Steps:\n${this.errorMessage.steps.map((s, i) => `${i + 1}. ${s}`).join('\n')}\n\nError Code: ${this.errorMessage.code}`;
  }

  /** Check if error is retryable */
  get isRetryable(): boolean {
    return this.errorMessage.retryable;
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
      const errorMessage = this.getErrorMessage(status);
      return new ApiError(
        errorMessage.reason,
        status,
        this.providerId,
        errorMessage
      );
    } else if (error.request) {
      // Request made but no response received
      const networkError = ErrorMessageBuilder.networkError({
        provider: this.providerId,
        reason: 'No response received from server',
      });
      return new ApiError(
        networkError.reason,
        undefined,
        this.providerId,
        networkError
      );
    } else {
      // Error in request configuration
      const configError = ErrorMessageBuilder.genericError({
        title: 'Request configuration error',
        reason: error.message,
        steps: [
          'Check your API endpoint configuration',
          'Verify request parameters are correct',
          'Contact support if issue persists',
        ],
        code: ErrorCode.API_005,
        retryable: false,
        provider: this.providerId,
      });
      return new ApiError(
        configError.reason,
        undefined,
        this.providerId,
        configError
      );
    }
  }

  /**
   * Gets a structured error message based on HTTP status code.
   *
   * @param status - HTTP status code
   * @returns Structured error message
   */
  private getErrorMessage(status: number): ErrorMessage {
    const provider = this.providerId || 'API';

    switch (status) {
      case 401:
        return ErrorMessageBuilder.authenticationError({
          provider,
          reason: 'Invalid API token or unauthorized',
          expired: false,
        });
      case 403:
        return ErrorMessageBuilder.authenticationError({
          provider,
          reason: 'Access forbidden - insufficient permissions',
          expired: false,
        });
      case 404:
        return ErrorMessageBuilder.apiError({
          provider,
          statusCode: 404,
        });
      case 429:
        return ErrorMessageBuilder.rateLimitError({ provider });
      case 500:
      case 502:
      case 503:
      case 504:
        return ErrorMessageBuilder.apiError({
          provider,
          statusCode: status,
        });
      default:
        return ErrorMessageBuilder.apiError({
          provider,
          statusCode: status,
          details: `Request failed with status ${status}`,
        });
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
