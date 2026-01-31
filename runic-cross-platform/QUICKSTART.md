# Quick Start Guide

Get Runic Cross-Platform up and running in 5 minutes!

## Prerequisites

Before you begin, ensure you have:

- **Node.js 18+** and **npm 9+** installed
- For **Android**: Android Studio with SDK 24+
- For **Windows**: Visual Studio 2022 with Windows 10 SDK

## Installation

### 1. Clone and Install

```bash
# Clone the repository
git clone https://github.com/yourusername/runic-cross-platform.git
cd runic-cross-platform

# Install dependencies
npm install
```

### 2. Platform Setup

#### For Android Development

```bash
# Ensure Android SDK is installed
# Set ANDROID_HOME environment variable

# Start Metro bundler
npm start

# In a new terminal, run on Android
npm run android
```

#### For Windows Development

```bash
# Ensure Visual Studio 2022 is installed
# Install Windows 10 SDK

# Generate Windows project (first time only)
npx react-native-windows-init

# Run on Windows
npm run windows
```

## First Run

### 1. Launch the App

After running `npm run android` or `npm run windows`, the app will launch on your device/emulator.

### 2. Add Your First Provider

1. Tap the "Add Provider" button on the home screen
2. Select a provider (e.g., OpenAI)
3. Enter your API token
4. Enable auto-sync (optional)
5. Tap "Save"

### 3. View Usage Data

- The home screen shows all your providers
- Tap a provider card to see detailed usage statistics
- Pull down to refresh data
- View charts for historical usage

## Key Features

### Dashboard
- See all providers at a glance
- View aggregated usage statistics
- Quick access to provider details
- Pull-to-refresh for latest data

### Provider Details
- Comprehensive usage charts
- Billing and quota information
- Token usage statistics
- Sync history

### Settings
- Theme selection (Light/Dark/Auto)
- Material You theming (Android)
- Notification preferences
- Sync configuration
- Privacy settings

## Common Commands

```bash
# Development
npm start              # Start Metro bundler
npm run android        # Run on Android
npm run windows        # Run on Windows

# Code Quality
npm run lint           # Run ESLint
npm run type-check     # Run TypeScript checks
npm test               # Run tests

# Production Builds
npm run build:android  # Build Android APK
npm run build:windows  # Build Windows MSIX
```

## Project Structure

```
runic-cross-platform/
├── src/
│   ├── components/      # Reusable UI components
│   ├── screens/         # Main application screens
│   ├── services/        # API clients and services
│   ├── stores/          # State management
│   ├── types/           # TypeScript types
│   ├── hooks/           # Custom React hooks
│   ├── utils/           # Utility functions
│   └── theme/           # Theming and styles
├── android/             # Android-specific code
├── windows/             # Windows-specific code
├── App.tsx             # Main app component
└── index.js            # Entry point
```

## Development Workflow

### 1. Make Changes

Edit files in the `src/` directory. The app will hot-reload automatically.

### 2. Follow Guidelines

- Keep files under 400 lines
- Add JSDoc comments
- Use TypeScript strict mode
- Write tests for new features

### 3. Test Changes

```bash
# Type checking
npm run type-check

# Linting
npm run lint

# Tests
npm test
```

### 4. Commit

```bash
git add .
git commit -m "feat: add new feature"
```

## Troubleshooting

### Metro bundler won't start

```bash
npm start -- --reset-cache
```

### Android build fails

```bash
cd android
./gradlew clean
cd ..
npm run android
```

### Windows build fails

- Ensure Visual Studio 2022 is installed
- Check Windows 10 SDK is installed
- Run terminal as Administrator

### Module not found errors

```bash
# Clear watchman
watchman watch-del-all

# Reset Metro
npm start -- --reset-cache

# Reinstall dependencies
rm -rf node_modules
npm install
```

## Next Steps

- Read [ARCHITECTURE.md](./ARCHITECTURE.md) to understand the codebase
- Check [CONTRIBUTING.md](./CONTRIBUTING.md) for contribution guidelines
- Explore the code in `src/` directories
- Join our community on Discord

## Configuration

### Environment Variables

Create a `.env` file in the root directory:

```env
# API Configuration
API_BASE_URL=https://api.example.com

# Feature Flags
ENABLE_ANALYTICS=false
ENABLE_CRASH_REPORTING=true

# Development
DEV_MODE=true
```

### Provider Tokens

Add provider API tokens in the app settings (not in code!):

1. Open Settings
2. Navigate to Providers
3. Add API token for each provider
4. Save changes

## Tips

### Performance

- Enable Hermes engine for faster startup
- Use Flipper for debugging
- Profile with React DevTools

### Debugging

- Use `console.log` sparingly
- Use React Native Debugger
- Check Metro bundler logs
- Use Flipper network inspector

### Hot Reload

- Shake device to open developer menu
- Enable Fast Refresh in settings
- Use `r` to reload manually in Metro

## Resources

- [React Native Documentation](https://reactnative.dev/)
- [React Navigation](https://reactnavigation.org/)
- [TypeScript Handbook](https://www.typescriptlang.org/docs/)
- [Zustand Documentation](https://github.com/pmndrs/zustand)

## Support

Need help?

- **Issues**: [GitHub Issues](https://github.com/yourusername/runic-cross-platform/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/runic-cross-platform/discussions)
- **Email**: support@runic.app

Happy coding! 🚀
