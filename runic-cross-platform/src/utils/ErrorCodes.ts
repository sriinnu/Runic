/**
 * @file ErrorCodes.ts
 * @description Centralized error codes for the Runic cross-platform app.
 * Error codes follow a hierarchical structure: CATEGORY_NNN
 */

/**
 * Error code enum matching Swift implementation
 */
export enum ErrorCode {
  // Network Errors (NET_001-NET_099)
  NET_001 = 'NET_001', // Network connection failed
  NET_002 = 'NET_002', // No internet connection
  NET_003 = 'NET_003', // Request timeout
  NET_004 = 'NET_004', // DNS resolution failed
  NET_005 = 'NET_005', // SSL/TLS certificate error

  // Authentication Errors (AUTH_001-AUTH_099)
  AUTH_001 = 'AUTH_001', // Authentication failed
  AUTH_002 = 'AUTH_002', // API token missing
  AUTH_003 = 'AUTH_003', // API token expired
  AUTH_004 = 'AUTH_004', // OAuth flow failed
  AUTH_005 = 'AUTH_005', // Session expired
  AUTH_006 = 'AUTH_006', // Missing required scope
  AUTH_007 = 'AUTH_007', // CLI not authenticated

  // API Errors (API_001-API_099)
  API_001 = 'API_001', // API error response
  API_002 = 'API_002', // API endpoint not found
  API_003 = 'API_003', // API server error
  API_004 = 'API_004', // API method not allowed
  API_005 = 'API_005', // Invalid API request
  API_006 = 'API_006', // API service unavailable

  // Rate Limit Errors (RATE_001-RATE_099)
  RATE_001 = 'RATE_001', // Rate limit exceeded
  RATE_002 = 'RATE_002', // Quota exceeded
  RATE_003 = 'RATE_003', // Too many requests

  // Parsing Errors (PARSE_001-PARSE_099)
  PARSE_001 = 'PARSE_001', // JSON parsing failed
  PARSE_002 = 'PARSE_002', // Invalid response format
  PARSE_003 = 'PARSE_003', // Missing required field
  PARSE_004 = 'PARSE_004', // Data type mismatch
  PARSE_005 = 'PARSE_005', // HTML parsing failed

  // Storage Errors (STORE_001-STORE_099)
  STORE_001 = 'STORE_001', // Failed to read storage
  STORE_002 = 'STORE_002', // Failed to write storage
  STORE_003 = 'STORE_003', // Storage quota exceeded
  STORE_004 = 'STORE_004', // Invalid storage format

  // Sync Errors (SYNC_001-SYNC_099)
  SYNC_001 = 'SYNC_001', // Sync operation failed
  SYNC_002 = 'SYNC_002', // Sync conflict detected
  SYNC_003 = 'SYNC_003', // Cloud sync unavailable
}

/**
 * Gets a user-friendly description for an error code
 */
export function getErrorCodeDescription(code: ErrorCode): string {
  const descriptions: Record<ErrorCode, string> = {
    [ErrorCode.NET_001]: 'Network connection failed or timeout',
    [ErrorCode.NET_002]: 'No internet connection available',
    [ErrorCode.NET_003]: 'Request timeout',
    [ErrorCode.NET_004]: 'DNS resolution failed',
    [ErrorCode.NET_005]: 'SSL/TLS certificate validation failed',

    [ErrorCode.AUTH_001]: 'Authentication credentials invalid',
    [ErrorCode.AUTH_002]: 'API token missing',
    [ErrorCode.AUTH_003]: 'API token expired',
    [ErrorCode.AUTH_004]: 'OAuth flow failed',
    [ErrorCode.AUTH_005]: 'Session expired',
    [ErrorCode.AUTH_006]: 'Missing required authorization scope',
    [ErrorCode.AUTH_007]: 'CLI not authenticated',

    [ErrorCode.API_001]: 'API returned error response',
    [ErrorCode.API_002]: 'API endpoint not found',
    [ErrorCode.API_003]: 'API server error',
    [ErrorCode.API_004]: 'API method not allowed',
    [ErrorCode.API_005]: 'Invalid API request',
    [ErrorCode.API_006]: 'API service unavailable',

    [ErrorCode.RATE_001]: 'Rate limit exceeded',
    [ErrorCode.RATE_002]: 'Usage quota exceeded',
    [ErrorCode.RATE_003]: 'Too many requests',

    [ErrorCode.PARSE_001]: 'JSON parsing failed',
    [ErrorCode.PARSE_002]: 'Invalid response format',
    [ErrorCode.PARSE_003]: 'Missing required field in response',
    [ErrorCode.PARSE_004]: 'Data type mismatch',
    [ErrorCode.PARSE_005]: 'HTML parsing failed',

    [ErrorCode.STORE_001]: 'Failed to read from storage',
    [ErrorCode.STORE_002]: 'Failed to write to storage',
    [ErrorCode.STORE_003]: 'Storage quota exceeded',
    [ErrorCode.STORE_004]: 'Invalid storage format',

    [ErrorCode.SYNC_001]: 'Sync operation failed',
    [ErrorCode.SYNC_002]: 'Sync conflict detected',
    [ErrorCode.SYNC_003]: 'Cloud sync unavailable',
  };

  return descriptions[code] || 'Unknown error';
}
