# Error Handling Improvements

This document describes the comprehensive error handling improvements made to the Runic application.

## Overview

We've implemented a structured error messaging system across both Swift (macOS) and TypeScript (React Native) codebases that provides:

1. **Structured error messages** with actionable guidance
2. **Error codes** for support and debugging
3. **Automatic retry** with exponential backoff
4. **User-friendly error displays** in the UI

## Error Code System

### Categories

Error codes follow a hierarchical structure: `CATEGORY_NNN`

| Category | Range | Description |
|----------|-------|-------------|
| NET | 001-099 | Network errors (connection, timeout, DNS) |
| AUTH | 001-099 | Authentication errors (invalid token, expired, OAuth) |
| API | 001-099 | API errors (4xx/5xx responses) |
| RATE | 001-099 | Rate limiting and quota errors |
| PARSE | 001-099 | Data parsing errors |
| CLI | 001-099 | CLI tool errors |
| STORE | 001-099 | Storage errors |
| SYNC | 001-099 | Sync operation errors |
| CONFIG | 001-099 | Configuration errors |

### Common Error Codes

- `NET_001`: Network connection failed
- `NET_003`: Request timeout
- `AUTH_001`: Authentication failed
- `AUTH_003`: API token expired
- `API_001`: Generic API error
- `API_003`: Server error (5xx)
- `RATE_001`: Rate limit exceeded
- `PARSE_001`: JSON parsing failed

## Error Message Structure

Every error message includes:

```swift
struct RunicErrorMessage {
    let title: String           // "Unable to sync with Claude API"
    let reason: String          // "Network connection lost"
    let steps: [String]         // ["Check internet", "Verify endpoint", ...]
    let code: RunicErrorCode    // NET_001
    let retryable: Bool         // true
    let providerName: String?   // "Claude"
}
```

## Usage Examples

### Swift (macOS)

#### Creating Error Messages

```swift
// Network error
let error = ErrorMessageBuilder.networkError(
    provider: "Claude",
    reason: "Connection timeout after 30 seconds"
)

// Authentication error
let error = ErrorMessageBuilder.authenticationError(
    provider: "Codex",
    reason: "API token has expired",
    expired: true
)

// Rate limit error
let error = ErrorMessageBuilder.rateLimitError(
    provider: "OpenAI",
    retryAfter: Date().addingTimeInterval(3600)
)

// API error with status code
let error = ErrorMessageBuilder.apiError(
    provider: "MiniMax",
    statusCode: 503,
    details: "Service temporarily unavailable"
)
```

#### Using Error Messages in Enums

```swift
public enum ClaudeUsageError: LocalizedError {
    case networkError(RunicErrorMessage)
    case parseFailed(RunicErrorMessage)

    public var errorDescription: String? {
        switch self {
        case .networkError(let msg), .parseFailed(let msg):
            return msg.compactDescription
        }
    }

    public var errorMessage: RunicErrorMessage {
        switch self {
        case .networkError(let msg), .parseFailed(let msg):
            return msg
        }
    }
}
```

#### Retry with Exponential Backoff

```swift
import RunicCore

// Use default retry strategy (3 attempts, 1s-8s)
let data = try await RetryStrategy.default.execute(
    operation: {
        try await fetchProviderData()
    },
    onRetry: { attempt, delay in
        print("Retry attempt \(attempt) after \(delay)s")
    }
)

// Use aggressive retry strategy (5 attempts, 2s-16s)
let data = try await RetryStrategy.aggressive.execute {
    try await fetchProviderData()
}

// Custom retry strategy
let strategy = RetryStrategy(
    maxAttempts: 4,
    baseDelay: 2.0,
    maxDelay: 10.0,
    useJitter: true
)
```

#### Displaying Errors in UI

```swift
import SwiftUI

// Full error display with retry
ErrorDisplayView(
    error: errorMessage,
    onRetry: {
        Task { await refreshData() }
    },
    onDismiss: {
        clearError()
    }
)

// Compact error display
CompactErrorView(
    error: errorMessage,
    onRetry: {
        Task { await refreshData() }
    }
)
```

### TypeScript (React Native)

#### Creating Error Messages

```typescript
import { ErrorMessageBuilder } from '@/utils';

// Network error
const error = ErrorMessageBuilder.networkError({
  provider: 'Claude',
  reason: 'Connection timeout',
  timeout: true,
});

// Authentication error
const error = ErrorMessageBuilder.authenticationError({
  provider: 'Codex',
  reason: 'Invalid API token',
  expired: false,
});

// Rate limit error
const error = ErrorMessageBuilder.rateLimitError({
  provider: 'OpenAI',
  retryAfter: new Date(Date.now() + 3600000),
});

// API error
const error = ErrorMessageBuilder.apiError({
  provider: 'MiniMax',
  statusCode: 503,
  details: 'Service unavailable',
});
```

#### Using Retry with Async Operations

```typescript
import { retryWithBackoff, RetryStrategy } from '@/utils';

// Basic retry with default strategy
const data = await retryWithBackoff(
  async () => await fetchProviderData(provider),
  {
    onRetry: (attempt, delay) => {
      console.log(`Retry ${attempt} after ${delay}ms`);
    },
  }
);

// Aggressive retry strategy
const data = await retryWithBackoff(
  async () => await fetchProviderData(provider),
  RetryStrategy.aggressive()
);

// Custom retry logic
const data = await retryWithBackoff(
  async () => await fetchProviderData(provider),
  {
    maxAttempts: 5,
    baseDelay: 2000,
    maxDelay: 16000,
    shouldRetry: (error) => {
      // Custom retry logic
      return error instanceof ApiError && error.isRetryable;
    },
  }
);
```

#### Displaying Errors in React Native

```tsx
import { ErrorDisplay, CompactErrorDisplay } from '@/components';

// Full error display
<ErrorDisplay
  error={errorMessage}
  onRetry={handleRetry}
  onDismiss={handleDismiss}
  defaultExpanded={false}
/>

// Compact inline error
<CompactErrorDisplay
  error={errorMessage}
  onRetry={handleRetry}
/>
```

## Before and After Examples

### Example 1: Network Error

**Before:**
```swift
throw URLError(.timedOut)
// UI shows: "The request timed out."
```

**After:**
```swift
throw ClaudeUsageError.networkError(
    ErrorMessageBuilder.networkError(
        provider: "Claude",
        reason: "Request timed out after 30 seconds",
        timeout: true
    )
)

// UI shows:
// Title: "Unable to sync with Claude API"
// Reason: "Request timed out after 30 seconds"
// Next Steps:
// 1. Check your internet connection
// 2. Verify the API endpoint is accessible
// 3. Try again in a few moments
// 4. Check if your firewall is blocking the connection
// Error Code: NET_003
// [Retry Button]
```

### Example 2: Authentication Error

**Before:**
```typescript
throw new Error('Invalid API token or unauthorized');
// UI shows: "Invalid API token or unauthorized"
```

**After:**
```typescript
throw new ApiError(
  'Authentication failed',
  401,
  'openai',
  ErrorMessageBuilder.authenticationError({
    provider: 'OpenAI',
    reason: 'API token has expired',
    expired: true,
  })
);

// UI shows:
// Title: "Authentication failed for OpenAI"
// Reason: "API token has expired"
// Next Steps:
// 1. Refresh your authentication token
// 2. Verify your API credentials are correct
// 3. Check if your API key is active
// 4. Contact OpenAI support if the issue persists
// Error Code: AUTH_003
```

### Example 3: Rate Limit Error

**Before:**
```swift
// UI shows: "Rate limit exceeded"
```

**After:**
```swift
throw UsageError.rateLimitError(
    ErrorMessageBuilder.rateLimitError(
        provider: "Anthropic",
        retryAfter: Date().addingTimeInterval(1800)
    )
)

// UI shows:
// Title: "Rate limit exceeded"
// Reason: "Anthropic API rate limit exceeded"
// Next Steps:
// 1. Rate limit resets at 3:30 PM
// 2. Reduce your request frequency
// 3. Check your Anthropic plan limits
// 4. Consider upgrading your plan for higher limits
// Error Code: RATE_001
// [Retry Button]
```

## Integration Checklist

### For New Provider Implementations

- [ ] Define provider-specific error enum with `RunicErrorMessage`
- [ ] Use `ErrorMessageBuilder` for all error cases
- [ ] Implement retry logic for transient errors
- [ ] Add error display in provider UI
- [ ] Test all error scenarios

### For Existing Code Updates

- [ ] Replace generic errors with structured error messages
- [ ] Add error codes to all error paths
- [ ] Implement retry for network/API calls
- [ ] Update UI to show detailed error information
- [ ] Add unit tests for error handling

## Files Modified/Created

### Swift (macOS)

**Created:**
- `Sources/RunicCore/Errors/RunicErrorCode.swift` - Error code definitions
- `Sources/RunicCore/Errors/RunicErrorMessage.swift` - Error message structures
- `Sources/RunicCore/Utilities/RetryStrategy.swift` - Retry with exponential backoff
- `Sources/Runic/Views/Menu/ErrorDisplayView.swift` - Error UI components

**Modified:**
- `Sources/RunicCore/UsageFetcher.swift` - Updated error handling
- `Sources/RunicCore/Providers/Claude/ClaudeUsageFetcher.swift` - Improved errors
- `Sources/RunicCore/Providers/MiniMax/MiniMaxUsageFetcher.swift` - Improved errors
- `Sources/RunicCore/Providers/Groq/GroqUsageFetcher.swift` - Improved errors

### TypeScript (React Native)

**Created:**
- `runic-cross-platform/src/utils/ErrorCodes.ts` - Error code enum
- `runic-cross-platform/src/utils/ErrorMessages.ts` - Error message builders
- `runic-cross-platform/src/utils/retry.ts` - Retry utilities
- `runic-cross-platform/src/components/ErrorDisplay.tsx` - Error UI components

**Modified:**
- `runic-cross-platform/src/services/ApiClient.ts` - Enhanced error handling
- `runic-cross-platform/src/services/SyncService.ts` - Added retry logic
- `runic-cross-platform/src/utils/index.ts` - Export new utilities
- `runic-cross-platform/src/components/index.ts` - Export new components

## Summary Statistics

### Error Messages Improved

- **Total error types updated**: 15+
- **Providers with improved errors**: 5 (Claude, Codex, MiniMax, Groq, Copilot)
- **Error codes defined**: 30+
- **New UI components**: 4 (2 Swift, 2 TypeScript)

### Before vs After

| Aspect | Before | After |
|--------|--------|-------|
| Error specificity | Generic "failed" messages | Specific reason with context |
| Actionability | No guidance | 3-5 specific steps |
| Debugging | No error codes | Unique error codes |
| Retry capability | Manual only | Automatic with backoff |
| User experience | Confusing | Clear and helpful |

## Testing Recommendations

1. **Network errors**: Disconnect internet and test sync
2. **Authentication errors**: Use invalid API tokens
3. **Rate limits**: Trigger rate limits and verify retry logic
4. **Parsing errors**: Send malformed API responses
5. **Retry logic**: Verify exponential backoff timing
6. **UI display**: Check error display on different screen sizes

## Future Improvements

- [ ] Add telemetry for error tracking
- [ ] Implement error recovery suggestions based on error patterns
- [ ] Add localization support for error messages
- [ ] Create error analytics dashboard
- [ ] Add automated error reporting to support
