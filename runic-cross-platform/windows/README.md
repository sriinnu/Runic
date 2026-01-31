# React Native for Windows

This directory contains Windows-specific code for the Runic application.

## Features

- **System Tray Integration**: App runs in system tray with icon and menu
- **Toast Notifications**: Native Windows notifications
- **Auto-launch**: Option to start with Windows
- **Background Sync**: Periodic data synchronization while minimized

## Building for Windows

### Prerequisites

- Windows 10 SDK (10.0.19041.0 or higher)
- Visual Studio 2022 with:
  - Desktop development with C++
  - Windows 10 SDK
  - MSBuild

### Build Commands

```bash
# Install dependencies
npm install

# Generate Windows project files
npx react-native-windows-init --overwrite

# Run in development mode
npx react-native run-windows

# Build release version
npx react-native run-windows --release
```

## System Tray Implementation

The Windows build includes a native system tray implementation:

1. **TrayIcon.cs**: Manages system tray icon and menu
2. **NotificationManager.cs**: Handles Windows toast notifications
3. **BackgroundSyncService.cs**: Manages background data synchronization

## Configuration

Windows-specific settings are stored in:
- `App.xaml`: Application resources and theming
- `MainPage.xaml`: Main window configuration
- `Package.appxmanifest`: App capabilities and permissions

## Debugging

Use Visual Studio to debug the Windows application:

1. Open `windows/runic-cross-platform.sln`
2. Set breakpoints in C# or C++ code
3. Press F5 to start debugging

## Distribution

Build an MSIX package for Microsoft Store submission:

```bash
npx react-native run-windows --release --bundle
```

The output will be in `windows/AppPackages/`.
