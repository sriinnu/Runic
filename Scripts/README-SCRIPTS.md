# Runic Build Scripts Documentation

Complete collection of setup and build scripts for all Runic platforms.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Setup Scripts](#setup-scripts)
- [Build Scripts](#build-scripts)
- [CI/CD Configuration](#cicd-configuration)
- [Platform-Specific Guides](#platform-specific-guides)
- [Troubleshooting](#troubleshooting)
- [Advanced Usage](#advanced-usage)

---

## Overview

This directory contains comprehensive scripts for setting up and building Runic across all supported platforms:

- **macOS** - Native Swift/SwiftUI application
- **iOS** - Native iOS application
- **Android** - React Native application
- **Windows** - React Native Windows application

All scripts include:
- ✅ Prerequisite checking
- ✅ Error handling with clear messages
- ✅ Color-coded output for better UX
- ✅ Dry-run mode for safety
- ✅ Verbose mode for debugging
- ✅ Comprehensive logging

---

## Quick Start

### One-Command Setup (All Platforms)

```bash
# Setup everything
./scripts/setup-all.sh

# Setup with dry-run to see what would happen
./scripts/setup-all.sh --dry-run

# Setup with verbose output
./scripts/setup-all.sh --verbose
```

### One-Command Build (All Platforms)

```bash
# Build all platforms
./scripts/build-all.sh

# Build specific platform
./scripts/build-macos.sh
./scripts/build-ios.sh
./scripts/build-android.sh
./scripts/build-windows.sh
```

---

## Setup Scripts

### setup-all.sh

**Purpose**: One-command setup for all platforms

**Usage**:
```bash
./scripts/setup-all.sh [OPTIONS]
```

**Options**:
- `--dry-run` - Show what would be done without executing
- `--verbose` - Enable verbose output
- `--only-macos` - Only setup macOS
- `--only-ios` - Only setup iOS
- `--only-rn` - Only setup React Native (Android/Windows)
- `--skip-macos` - Skip macOS setup
- `--skip-ios` - Skip iOS setup
- `--skip-rn` - Skip React Native setup
- `--help` - Show help message

**Examples**:
```bash
# Setup everything
./scripts/setup-all.sh

# Setup only iOS
./scripts/setup-all.sh --only-ios

# Setup everything except React Native
./scripts/setup-all.sh --skip-rn

# Dry-run to see what would happen
./scripts/setup-all.sh --dry-run --verbose
```

---

### setup-ios.sh

**Purpose**: Setup iOS Xcode project

**Prerequisites**:
- macOS 14.0+
- Xcode 15.0+
- Command Line Tools
- Ruby (for CocoaPods)

**Usage**:
```bash
./scripts/setup-ios.sh [OPTIONS]
```

**Options**:
- `--dry-run` - Show what would be done
- `--verbose` - Enable verbose output
- `--skip-pods` - Skip CocoaPods installation
- `--help` - Show help message

**What it does**:
1. Checks for Xcode and required tools
2. Verifies iOS project structure
3. Installs CocoaPods dependencies (if Podfile exists)
4. Resolves Swift Package dependencies
5. Creates configuration template
6. Provides code signing instructions

**Examples**:
```bash
# Standard setup
./scripts/setup-ios.sh

# Skip CocoaPods
./scripts/setup-ios.sh --skip-pods

# Verbose output for debugging
./scripts/setup-ios.sh --verbose
```

---

### setup-react-native.sh

**Purpose**: Setup React Native project for Windows and Android

**Prerequisites**:
- Node.js 18+
- npm or yarn
- Java Development Kit 17+ (for Android)
- Android SDK (for Android)
- Windows 10+ with Visual Studio (for Windows)

**Usage**:
```bash
./scripts/setup-react-native.sh [OPTIONS]
```

**Options**:
- `--dry-run` - Show what would be done
- `--verbose` - Enable verbose output
- `--skip-android` - Skip Android setup
- `--skip-windows` - Skip Windows setup
- `--help` - Show help message

**What it does**:
1. Checks for Node.js, npm, Java, Android SDK
2. Installs npm dependencies
3. Sets up Android SDK configuration
4. Initializes React Native Windows (if needed)
5. Creates environment configuration files
6. Checks for code quality tools (ESLint, Prettier)

**Examples**:
```bash
# Setup both Android and Windows
./scripts/setup-react-native.sh

# Setup only Android
./scripts/setup-react-native.sh --skip-windows

# Setup only Windows
./scripts/setup-react-native.sh --skip-android
```

---

## Build Scripts

### build-macos.sh

**Purpose**: Build macOS application using Swift Package Manager

**Usage**:
```bash
./scripts/build-macos.sh [OPTIONS]
```

**Options**:
- `--dry-run` - Show what would be done
- `--verbose` - Enable verbose output
- `--skip-tests` - Skip running tests
- `--skip-signing` - Skip code signing
- `--configuration` - Build configuration (debug|release) [default: release]
- `--output-dir` - Output directory for build artifacts
- `--clean` - Clean build directory before building
- `--help` - Show help message

**What it does**:
1. Runs SwiftLint and SwiftFormat checks
2. Executes Swift tests
3. Builds the application
4. Creates .app bundle with Info.plist
5. Signs the application (if certificates available)
6. Creates ZIP archive for distribution

**Output**:
- `builds/macos/Runic.app` - Application bundle
- `builds/macos/Runic-*.zip` - Distributable archive

**Examples**:
```bash
# Standard release build
./scripts/build-macos.sh

# Debug build without tests
./scripts/build-macos.sh --configuration debug --skip-tests

# Clean build with verbose output
./scripts/build-macos.sh --clean --verbose

# Dry-run to see what would happen
./scripts/build-macos.sh --dry-run
```

---

### build-ios.sh

**Purpose**: Build iOS application using Xcode

**Usage**:
```bash
./scripts/build-ios.sh [OPTIONS]
```

**Options**:
- `--dry-run` - Show what would be done
- `--verbose` - Enable verbose output
- `--skip-tests` - Skip running tests
- `--configuration` - Build configuration (Debug|Release) [default: Release]
- `--scheme` - Build scheme [default: RuniciOS]
- `--output-dir` - Output directory for build artifacts
- `--simulator` - Build for iOS Simulator
- `--device` - Build for iOS Device [default]
- `--archive` - Create archive and IPA
- `--clean` - Clean build directory before building
- `--help` - Show help message

**What it does**:
1. Runs iOS tests (optional)
2. Builds for simulator or device
3. Creates archive (optional)
4. Exports IPA (requires code signing)

**Output**:
- `builds/ios/DerivedData/` - Build products
- `builds/ios/RuniciOS.xcarchive` - Archive (if --archive)
- `builds/ios/Export/*.ipa` - IPA file (if --archive and signed)

**Examples**:
```bash
# Build for device
./scripts/build-ios.sh --device

# Build for simulator
./scripts/build-ios.sh --simulator

# Create archive and IPA
./scripts/build-ios.sh --archive

# Debug build for simulator without tests
./scripts/build-ios.sh --simulator --configuration Debug --skip-tests
```

**Code Signing Note**:
- Device builds and archives require valid code signing certificates
- See [iOS Code Signing](#ios-code-signing) section

---

### build-android.sh

**Purpose**: Build Android application using Gradle

**Usage**:
```bash
./scripts/build-android.sh [OPTIONS]
```

**Options**:
- `--dry-run` - Show what would be done
- `--verbose` - Enable verbose output
- `--skip-tests` - Skip running tests
- `--skip-lint` - Skip lint checks
- `--variant` - Build variant (debug|release) [default: release]
- `--output-dir` - Output directory for build artifacts
- `--aab` - Build Android App Bundle (AAB) instead of APK
- `--clean` - Clean build directory before building
- `--help` - Show help message

**What it does**:
1. Checks for Java and Android SDK
2. Installs npm dependencies
3. Runs Android lint checks
4. Executes tests
5. Builds APK or AAB
6. Copies artifacts to output directory

**Output**:
- `builds/android/app-debug.apk` - Debug APK
- `builds/android/app-release.apk` - Release APK (unsigned without keystore)
- `builds/android/app-release.aab` - Release AAB (if --aab)

**Examples**:
```bash
# Build debug APK
./scripts/build-android.sh --variant debug

# Build release APK
./scripts/build-android.sh --variant release

# Build AAB for Play Store
./scripts/build-android.sh --aab

# Build without tests and lint
./scripts/build-android.sh --skip-tests --skip-lint
```

**Code Signing Note**:
- Release builds require a keystore for signing
- See [Android Code Signing](#android-code-signing) section

---

### build-windows.sh

**Purpose**: Build Windows application using React Native Windows

**Usage**:
```bash
./scripts/build-windows.sh [OPTIONS]
```

**Options**:
- `--dry-run` - Show what would be done
- `--verbose` - Enable verbose output
- `--skip-tests` - Skip running tests
- `--configuration` - Build configuration (Debug|Release) [default: Release]
- `--arch` - Target architecture (x64|x86|ARM64) [default: x64]
- `--output-dir` - Output directory for build artifacts
- `--clean` - Clean build directory before building
- `--help` - Show help message

**What it does**:
1. Checks for Node.js and MSBuild
2. Installs npm dependencies
3. Runs tests
4. Builds Windows application
5. Copies build artifacts
6. Creates distribution package

**Output**:
- `builds/windows/` - Build artifacts and executable
- `builds/windows/Runic-*.zip` - Distribution package

**Examples**:
```bash
# Build release for x64
./scripts/build-windows.sh

# Build debug for x64
./scripts/build-windows.sh --configuration Debug

# Build for ARM64
./scripts/build-windows.sh --arch ARM64

# Clean build
./scripts/build-windows.sh --clean
```

**Platform Note**:
- This script works best on native Windows
- Can run on macOS/Linux via Git Bash but may have limitations

---

## CI/CD Configuration

### ci-config.yml

**Purpose**: GitHub Actions workflow for automated builds and deployments

**Location**: Copy to `.github/workflows/ci.yml`

**Features**:
- ✅ Build matrix for all platforms
- ✅ Automated testing on each platform
- ✅ Code quality checks (SwiftLint, ESLint)
- ✅ Artifact uploading
- ✅ Optional deployment to TestFlight/Play Store
- ✅ Build status summary

**Triggers**:
- Push to `main` or `develop` branches
- Pull requests to `main`
- Manual workflow dispatch

**Jobs**:
1. **code-quality** - ESLint, Prettier, TypeScript checks
2. **build-macos** - Build and test macOS application
3. **build-ios** - Build and test iOS application
4. **build-android** - Build and test Android application
5. **build-windows** - Build and test Windows application
6. **deploy** - Optional deployment to distribution platforms
7. **build-summary** - Generate build status summary

**Required Secrets**:

See the [GitHub Secrets Configuration](#github-secrets-configuration) section.

**Setup**:
```bash
# Copy to workflows directory
mkdir -p .github/workflows
cp scripts/ci-config.yml .github/workflows/ci.yml

# Commit and push
git add .github/workflows/ci.yml
git commit -m "Add CI/CD workflow"
git push
```

---

## Platform-Specific Guides

### macOS Development

**Setup**:
```bash
./scripts/setup-all.sh --only-macos
```

**Build**:
```bash
# Development build
swift build

# Release build with script
./scripts/build-macos.sh

# Run application
open builds/macos/Runic.app
```

**Testing**:
```bash
# Run all tests
swift test

# Run specific test
swift test --filter RunicTests
```

**Code Quality**:
```bash
# SwiftLint
swiftlint lint

# SwiftFormat
swiftformat .
```

---

### iOS Development

**Setup**:
```bash
./scripts/setup-ios.sh
```

**Build**:
```bash
# Simulator build
./scripts/build-ios.sh --simulator

# Device build (requires code signing)
./scripts/build-ios.sh --device

# Create IPA for distribution
./scripts/build-ios.sh --archive
```

**Testing**:
```bash
# Run tests
./scripts/build-ios.sh --simulator --skip-signing
```

**Code Signing**:

1. **Development**:
   - Open `RuniciOS/*.xcodeproj` or `*.xcworkspace` in Xcode
   - Select target → Signing & Capabilities
   - Choose your team and enable automatic signing

2. **Distribution**:
   - Create App ID in Apple Developer Portal
   - Create provisioning profile
   - Update `RuniciOS/Config.xcconfig` with your team ID

---

### Android Development

**Setup**:
```bash
./scripts/setup-react-native.sh --skip-windows

# Set ANDROID_HOME
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/platform-tools
```

**Build**:
```bash
# Debug build
./scripts/build-android.sh --variant debug

# Release build
./scripts/build-android.sh --variant release

# AAB for Play Store
./scripts/build-android.sh --aab
```

**Testing**:
```bash
# Run tests
cd runic-cross-platform/android
./gradlew test

# Run on emulator
npm run android
```

**Code Signing**:

1. **Generate Keystore**:
```bash
keytool -genkey -v -keystore runic-release.keystore \
  -alias runic-key -keyalg RSA -keysize 2048 -validity 10000
```

2. **Create `android/keystore.properties`**:
```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=runic-key
storeFile=runic-release.keystore
```

3. **Update `android/app/build.gradle`**:
```gradle
// Load keystore
def keystorePropertiesFile = rootProject.file("keystore.properties")
def keystoreProperties = new Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            if (keystorePropertiesFile.exists()) {
                storeFile file(keystoreProperties['storeFile'])
                storePassword keystoreProperties['storePassword']
                keyAlias keystoreProperties['keyAlias']
                keyPassword keystoreProperties['keyPassword']
            }
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

---

### Windows Development

**Setup**:
```bash
./scripts/setup-react-native.sh --skip-android
```

**Prerequisites**:
- Windows 10+
- Visual Studio 2022 with:
  - Desktop development with C++
  - Windows 10 SDK (10.0.19041.0 or higher)

**Build**:
```bash
# Release build
./scripts/build-windows.sh

# Debug build
./scripts/build-windows.sh --configuration Debug

# Different architecture
./scripts/build-windows.sh --arch ARM64
```

**Testing**:
```bash
# Run tests
cd runic-cross-platform
npm test

# Run in development
npm run windows
```

**Deployment**:
- Create installer with WiX Toolset or Inno Setup
- Sign executable with code signing certificate

---

## GitHub Secrets Configuration

Configure these secrets in your GitHub repository settings (Settings → Secrets and variables → Actions):

### iOS Secrets

| Secret Name | Description | How to Generate |
|------------|-------------|-----------------|
| `IOS_CERTIFICATE_P12` | Base64-encoded P12 certificate | `base64 -i certificate.p12 -o cert.txt` |
| `IOS_CERTIFICATE_PASSWORD` | Certificate password | Password used when exporting certificate |
| `IOS_PROVISIONING_PROFILE` | Base64-encoded provisioning profile | `base64 -i profile.mobileprovision -o profile.txt` |
| `APP_STORE_CONNECT_API_KEY` | API key for TestFlight | Create in App Store Connect → Users and Access → Keys |

### Android Secrets

| Secret Name | Description | How to Generate |
|------------|-------------|-----------------|
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded keystore file | `base64 -i runic-release.keystore -o keystore.txt` |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password | Password from keystore creation |
| `ANDROID_KEY_ALIAS` | Key alias | Alias from keystore creation |
| `ANDROID_KEY_PASSWORD` | Key password | Password from keystore creation |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | Service account JSON | Create in Google Play Console → API access |

---

## Troubleshooting

### Common Issues

#### macOS Build Issues

**Problem**: `swift build` fails with "missing package"

**Solution**:
```bash
# Clean and resolve
rm -rf .build
swift package resolve
swift package clean
swift build
```

**Problem**: Code signing fails

**Solution**:
```bash
# Check signing identities
security find-identity -v -p codesigning

# Build without signing
./scripts/build-macos.sh --skip-signing
```

---

#### iOS Build Issues

**Problem**: "No provisioning profile found"

**Solution**:
1. Open project in Xcode
2. Select target → Signing & Capabilities
3. Enable "Automatically manage signing"
4. Select your team

**Problem**: Tests fail on simulator

**Solution**:
```bash
# List available simulators
xcrun simctl list devices

# Specify simulator in build script
# Edit build-ios.sh and change simulator name
```

---

#### Android Build Issues

**Problem**: "ANDROID_HOME is not set"

**Solution**:
```bash
# macOS/Linux
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/platform-tools
export PATH=$PATH:$ANDROID_HOME/tools

# Add to ~/.bashrc or ~/.zshrc to persist

# Windows
setx ANDROID_HOME "%LOCALAPPDATA%\Android\Sdk"
```

**Problem**: Gradle build fails

**Solution**:
```bash
# Clean Gradle cache
cd runic-cross-platform/android
./gradlew clean
./gradlew --stop

# Clear global Gradle cache
rm -rf ~/.gradle/caches/
```

---

#### Windows Build Issues

**Problem**: "MSBuild not found"

**Solution**:
- Install Visual Studio 2022 with C++ development tools
- Add MSBuild to PATH:
  ```
  C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin
  ```

**Problem**: React Native Windows initialization fails

**Solution**:
```bash
# Reinstall React Native Windows
cd runic-cross-platform
npm install react-native-windows --save
npx react-native-windows-init --overwrite
```

---

### Getting Help

**Check build logs**:
```bash
# Verbose output
./scripts/build-macos.sh --verbose
./scripts/build-ios.sh --verbose
./scripts/build-android.sh --verbose
./scripts/build-windows.sh --verbose
```

**Dry-run mode**:
```bash
# See what would happen without executing
./scripts/build-macos.sh --dry-run
```

**Platform-specific diagnostics**:
```bash
# macOS/iOS
xcodebuild -version
swift --version

# Android
./gradlew --version
adb devices

# React Native
npx react-native doctor
```

---

## Advanced Usage

### Custom Build Configurations

**macOS with custom output**:
```bash
./scripts/build-macos.sh \
  --configuration release \
  --output-dir /path/to/output \
  --clean
```

**iOS archive with custom scheme**:
```bash
./scripts/build-ios.sh \
  --scheme MyCustomScheme \
  --configuration Release \
  --archive
```

**Android with multiple variants**:
```bash
# Debug build
./scripts/build-android.sh --variant debug

# Release APK
./scripts/build-android.sh --variant release

# Release AAB
./scripts/build-android.sh --variant release --aab
```

### Continuous Integration

**Local CI testing**:
```bash
# Simulate CI environment
export CI=true

# Run builds as CI would
./scripts/build-macos.sh --skip-signing
./scripts/build-ios.sh --simulator --skip-signing
./scripts/build-android.sh --variant release
```

**Custom CI workflows**:
- Copy `scripts/ci-config.yml` to `.github/workflows/`
- Modify as needed for your workflow
- Configure required secrets

### Automated Versioning

**Update version across all platforms**:
```bash
# Update version.env
echo "VERSION=1.2.3" > version.env

# Builds will automatically use this version
./scripts/build-macos.sh
./scripts/build-ios.sh
./scripts/build-android.sh
```

---

## Script Maintenance

All scripts follow these conventions:

- ✅ Bash shebang: `#!/usr/bin/env bash`
- ✅ Strict mode: `set -e -u`
- ✅ Color output with terminal detection
- ✅ Comprehensive help via `--help`
- ✅ Dry-run mode via `--dry-run`
- ✅ Verbose mode via `--verbose`
- ✅ Error handling with clear messages
- ✅ Prerequisite checking
- ✅ Build summaries

**Make scripts executable**:
```bash
chmod +x scripts/*.sh
```

**Update all scripts**:
```bash
# Pull latest changes
git pull

# Make executable
chmod +x scripts/*.sh
```

---

## License

These scripts are part of the Runic project and follow the same license.

---

## Support

For issues, questions, or contributions:
- Open an issue on GitHub
- Check existing documentation
- Run scripts with `--verbose` for debugging

**Happy Building! 🚀**
