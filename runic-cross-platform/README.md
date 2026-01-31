# Runic Cross-Platform

A production-ready React Native application for monitoring AI provider usage across Windows and Android platforms.

## Features

### Core Functionality
- **Multi-Provider Support**: Track usage for OpenAI, Anthropic, Google, Mistral, and more
- **Real-time Sync**: Automatic synchronization of usage data and quotas
- **Usage Analytics**: Comprehensive charts and statistics for token usage and costs
- **Quota Monitoring**: Real-time quota tracking with configurable alerts
- **Offline Mode**: Full functionality with cached data when offline

### Platform-Specific Features

#### Windows
- Native toast notifications
- Auto-launch on startup
- Background synchronization while minimized
- **Note**: System tray functionality is not yet implemented

#### Android
- Material You dynamic theming (Android 12+)
- Native push notifications
- Battery-optimized background sync
- Adaptive icons and splash screen

## Architecture

### Project Structure

```
runic-cross-platform/
├── src/
│   ├── components/         # Reusable UI components
│   │   ├── ProviderCard.tsx
│   │   ├── UsageChart.tsx
│   │   ├── AlertBanner.tsx
│   │   └── LoadingSpinner.tsx
│   ├── screens/           # Main application screens
│   │   ├── HomeScreen.tsx
│   │   ├── ProviderDetailScreen.tsx
│   │   └── SettingsScreen.tsx
│   ├── services/          # Business logic and API clients
│   │   ├── ApiClient.ts
│   │   ├── SyncService.ts
│   │   └── NotificationService.ts
│   ├── stores/            # State management (Zustand)
│   │   ├── useProviderStore.ts
│   │   └── useAppStore.ts
│   ├── types/             # TypeScript type definitions
│   ├── hooks/             # Custom React hooks
│   ├── utils/             # Utility functions
│   └── theme/             # Theme and styling
├── android/               # Android-specific code
├── windows/               # Windows-specific code
├── App.tsx               # Main application component
└── index.js              # Entry point
```

### Technology Stack

- **Framework**: React Native 0.73.2
- **Language**: TypeScript (strict mode)
- **State Management**: Zustand
- **Navigation**: React Navigation v6
- **HTTP Client**: Axios
- **Charts**: React Native Chart Kit
- **Notifications**: React Native Push Notification
- **Storage**: AsyncStorage

## Getting Started

### Prerequisites

- Node.js 18+ and npm 9+
- For Android: Android Studio with SDK 24+
- For Windows: Visual Studio 2022 with Windows 10 SDK

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd runic-cross-platform

# Install dependencies
npm install

# For Android development
npm run android

# For Windows development
npm run windows
```

### Development

```bash
# Start Metro bundler
npm start

# Run on Android
npm run android

# Run on Windows
npm run windows

# Run tests
npm test

# Type checking
npm run type-check

# Linting
npm run lint
```

## Configuration

### Environment Setup

1. Copy `.env.example` to `.env`
2. Configure API endpoints and tokens
3. Update provider configurations in settings

### Provider Setup

Add provider API tokens in the app settings:
1. Open Settings screen
2. Navigate to Providers section
3. Add API token for each provider
4. Enable auto-sync if desired

## Code Guidelines

### File Organization

- **Maximum 400 lines per file**: Split large files into smaller, focused modules
- **JSDoc comments**: Every file and exported function must have JSDoc comments
- **Type safety**: Use TypeScript strict mode with no implicit any

### Component Structure

```typescript
/**
 * @file ComponentName.tsx
 * @description Brief description of component purpose.
 * Detailed explanation of functionality and usage.
 */

import React from 'react';
// ... imports

/**
 * Props for ComponentName
 */
interface ComponentNameProps {
  /** Prop description */
  propName: string;
}

/**
 * Component description.
 * Explains what the component does and how to use it.
 *
 * @example
 * <ComponentName propName="value" />
 */
export function ComponentName({ propName }: ComponentNameProps) {
  // Implementation
}
```

### Naming Conventions

- **Components**: PascalCase (e.g., `ProviderCard`)
- **Hooks**: camelCase with `use` prefix (e.g., `useTheme`)
- **Utils**: camelCase (e.g., `formatCurrency`)
- **Types**: PascalCase (e.g., `Provider`, `AppSettings`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `STORAGE_KEYS`)

## Testing

```bash
# Run all tests
npm test

# Watch mode
npm test -- --watch

# Coverage report
npm test -- --coverage
```

## Building for Production

### Android

```bash
# Build release APK
npm run build:android

# Output: android/app/build/outputs/apk/release/app-release.apk
```

### Windows

```bash
# Build release MSIX
npm run build:windows

# Output: windows/AppPackages/
```

## Performance Optimization

### Bundle Size
- Code splitting for routes
- Lazy loading for heavy components
- Tree shaking enabled

### Memory Management
- Proper cleanup in useEffect hooks
- Memoization for expensive computations
- Efficient list rendering with FlatList

### Network
- Request debouncing
- Cache-first strategy
- Optimistic updates

## Accessibility

- Semantic HTML/Native components
- Screen reader support
- Keyboard navigation
- High contrast mode support
- Scalable text sizes

## Security

- API tokens encrypted at rest
- HTTPS-only connections
- No sensitive data in logs
- Secure credential storage
- Regular dependency updates

## Troubleshooting

### Common Issues

**Metro bundler won't start**
```bash
npm start -- --reset-cache
```

**Android build fails**
```bash
cd android && ./gradlew clean
cd .. && npm run android
```

**Windows build fails**
- Ensure Visual Studio 2022 is installed
- Check Windows 10 SDK version
- Run as administrator

## Contributing

1. Follow code style guidelines
2. Add JSDoc comments
3. Keep files under 400 lines
4. Write unit tests
5. Update documentation

## License

MIT License - see LICENSE file for details

## Support

For issues and questions:
- GitHub Issues: [repository-url]/issues
- Documentation: [docs-url]
- Email: support@runic.app
