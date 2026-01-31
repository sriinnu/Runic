# Architecture Documentation

## Overview

Runic Cross-Platform is built using React Native with TypeScript, following modern best practices for maintainability, scalability, and performance.

## Design Principles

### 1. Separation of Concerns
- **UI Components**: Pure presentational components in `src/components/`
- **Screens**: Container components that connect to stores in `src/screens/`
- **Business Logic**: Services for API calls and data processing in `src/services/`
- **State Management**: Centralized state with Zustand stores in `src/stores/`

### 2. Type Safety
- Strict TypeScript mode enabled
- Comprehensive type definitions in `src/types/`
- No implicit `any` types allowed
- Type inference where possible

### 3. Code Organization
- Maximum 400 lines per file
- Single responsibility principle
- Clear file naming conventions
- Consistent folder structure

### 4. Performance
- Memoization for expensive computations
- Lazy loading for routes and components
- Efficient list rendering with virtualization
- Debouncing for API calls

## Architecture Layers

```
┌─────────────────────────────────────────┐
│          Presentation Layer             │
│  (Screens, Components, Navigation)      │
├─────────────────────────────────────────┤
│         Application Layer               │
│      (Stores, Hooks, Business Logic)    │
├─────────────────────────────────────────┤
│           Service Layer                 │
│   (API Client, Sync, Notifications)     │
├─────────────────────────────────────────┤
│          Utility Layer                  │
│  (Formatters, Validators, Storage)      │
├─────────────────────────────────────────┤
│         Platform Layer                  │
│    (Native Modules, Platform APIs)      │
└─────────────────────────────────────────┘
```

## State Management

### Zustand Stores

We use Zustand for state management due to its simplicity and performance:

#### Provider Store (`useProviderStore`)
- Manages provider configurations
- Handles usage data and billing information
- Coordinates sync operations
- Persists to AsyncStorage

#### App Store (`useAppStore`)
- Manages application settings
- Handles theme preferences
- Controls notifications
- Manages alerts and sync status

### Data Flow

```
User Action → Screen Component → Store Action → Service Call
                    ↑                               ↓
                    └───────── State Update ←────────┘
```

## Service Layer

### ApiClient
Centralized HTTP client with:
- Automatic error handling
- Request/response interceptors
- Token management
- Timeout configuration

### SyncService
Manages data synchronization:
- Parallel provider sync
- Cache management
- Error recovery
- Offline support

### NotificationService
Cross-platform notifications:
- Local notifications
- Toast messages
- System tray (Windows)
- Quota warnings

## Component Architecture

### Component Hierarchy

```
App
├── NavigationContainer
│   └── Stack.Navigator
│       ├── HomeScreen
│       │   ├── Header
│       │   ├── SummaryCards
│       │   ├── AlertBanner
│       │   └── ProviderCard (multiple)
│       ├── ProviderDetailScreen
│       │   ├── Header
│       │   ├── BillingSection
│       │   ├── UsageStats
│       │   └── UsageChart (multiple)
│       └── SettingsScreen
│           └── SettingsSection (multiple)
```

### Component Patterns

#### Presentational Components
- Stateless when possible
- Accept data via props
- Emit events via callbacks
- No direct store access

#### Container Components (Screens)
- Connect to stores
- Handle business logic
- Coordinate child components
- Manage local UI state

## Data Models

### Provider Model
```typescript
Provider {
  id: ProviderId
  name: string
  status: ProviderStatus
  apiToken?: string
  billing: ProviderBilling
  usage: UsageStats
  lastSyncTime: number
}
```

### Usage Model
```typescript
UsageStats {
  totalTokens: number
  totalCost: number
  requestCount: number
  averageTokensPerRequest: number
  dataPoints: UsageDataPoint[]
}
```

## Platform Integration

### Android
- Material You dynamic colors
- Notification channels
- Background sync with WorkManager
- Adaptive launcher icons

### Windows
- System tray integration
- Toast notifications
- Auto-launch registry entries
- MSIX packaging

## Error Handling

### Layers of Error Handling

1. **API Layer**: Axios interceptors catch HTTP errors
2. **Service Layer**: Services catch and transform errors
3. **Store Layer**: Stores handle errors and update state
4. **UI Layer**: Components display error messages

### Error Types

```typescript
ApiError {
  message: string
  statusCode?: number
  providerId?: ProviderId
}
```

## Performance Optimizations

### React Optimizations
- `useMemo` for expensive computations
- `useCallback` for event handlers
- `React.memo` for pure components
- Virtualized lists with `FlatList`

### Network Optimizations
- Request caching
- Debounced API calls
- Optimistic updates
- Background sync queue

### Storage Optimizations
- Lazy loading from AsyncStorage
- Batch reads/writes
- Cache invalidation
- Compression for large data

## Security Considerations

### Data Protection
- API tokens encrypted at rest
- No sensitive data in logs
- Secure credential storage
- HTTPS-only connections

### Input Validation
- All user input sanitized
- Type checking at boundaries
- API response validation
- URL validation

## Testing Strategy

### Unit Tests
- Utility functions
- Store actions
- Service methods
- Validators and formatters

### Integration Tests
- API client integration
- Store-service integration
- Component-store integration

### E2E Tests
- Critical user flows
- Cross-platform scenarios
- Navigation flows

## Build and Deployment

### Development Build
```bash
npm run android  # Android debug build
npm run windows  # Windows debug build
```

### Production Build
```bash
npm run build:android  # Android release APK
npm run build:windows  # Windows release MSIX
```

### Code Quality
- ESLint for code quality
- Prettier for formatting
- TypeScript for type safety
- Husky for pre-commit hooks

## Future Enhancements

### Planned Features
- [ ] iOS support
- [ ] Web dashboard
- [ ] Export/import settings
- [ ] Advanced analytics
- [ ] Custom provider support
- [ ] Multi-language support

### Technical Improvements
- [ ] Implement React Native New Architecture
- [ ] Add Detox for E2E testing
- [ ] Implement CI/CD pipeline
- [ ] Add performance monitoring
- [ ] Implement feature flags
