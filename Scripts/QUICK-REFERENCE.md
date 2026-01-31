# Runic Build Scripts - Quick Reference Card

## One-Line Commands

### Setup (First Time)

```bash
# Setup everything
./scripts/setup-all.sh

# Setup specific platform
./scripts/setup-all.sh --only-ios
./scripts/setup-all.sh --only-rn
```

### Build (Development)

```bash
# macOS
./scripts/build-macos.sh --configuration debug --skip-signing

# iOS (Simulator)
./scripts/build-ios.sh --simulator --configuration Debug

# Android (Debug)
./scripts/build-android.sh --variant debug

# Windows (Debug)
./scripts/build-windows.sh --configuration Debug
```

### Build (Release)

```bash
# macOS
./scripts/build-macos.sh

# iOS (Archive for TestFlight)
./scripts/build-ios.sh --archive

# Android (AAB for Play Store)
./scripts/build-android.sh --aab

# Windows
./scripts/build-windows.sh
```

## Common Flags

| Flag | Description |
|------|-------------|
| `--dry-run` | Show what would happen (safe) |
| `--verbose` | Detailed output for debugging |
| `--skip-tests` | Skip running tests |
| `--clean` | Clean before building |
| `--help` | Show help message |

## Build Outputs

| Platform | Location |
|----------|----------|
| macOS | `builds/macos/Runic.app` |
| iOS | `builds/ios/` |
| Android | `builds/android/app-*.apk` |
| Windows | `builds/windows/` |

## Troubleshooting One-Liners

```bash
# Check prerequisites
./scripts/setup-all.sh --dry-run --verbose

# Test build without executing
./scripts/build-macos.sh --dry-run

# Clean build
./scripts/build-android.sh --clean --verbose

# Debug specific platform
./scripts/build-ios.sh --verbose --simulator
```

## CI/CD Setup

```bash
# 1. Copy workflow
mkdir -p .github/workflows
cp scripts/ci-config.yml .github/workflows/ci.yml

# 2. Configure secrets in GitHub
# (See README-SCRIPTS.md for complete list)

# 3. Push and watch it build
git add .github/workflows/ci.yml
git commit -m "Add CI/CD"
git push
```

## Code Signing Quick Start

### iOS
```bash
# 1. Open Xcode
open RuniciOS/*.xcodeproj

# 2. Select target > Signing & Capabilities
# 3. Choose team and enable automatic signing
```

### Android
```bash
# 1. Generate keystore
keytool -genkey -v -keystore release.keystore -alias runic -keyalg RSA -keysize 2048 -validity 10000

# 2. Create keystore.properties
cat > runic-cross-platform/android/keystore.properties << 'EOF'
storePassword=YOUR_PASSWORD
keyPassword=YOUR_PASSWORD
keyAlias=runic
storeFile=release.keystore
EOF

# 3. Build signed APK
./scripts/build-android.sh --variant release
```

## Most Common Commands

```bash
# Daily development workflow
./scripts/build-macos.sh --skip-tests --skip-signing
./scripts/build-ios.sh --simulator --skip-tests --configuration Debug

# Release workflow
./scripts/build-macos.sh
./scripts/build-ios.sh --archive
./scripts/build-android.sh --aab

# Debug build issues
./scripts/build-macos.sh --verbose --dry-run
./scripts/build-android.sh --clean --verbose
```

## Help & Documentation

```bash
# Quick help for any script
./scripts/setup-all.sh --help
./scripts/build-macos.sh --help

# Full documentation
cat scripts/README-SCRIPTS.md

# Creation summary
cat scripts/CREATION-SUMMARY.md
```

---

**Tip**: Start with `--dry-run --verbose` to see what a script will do before running it!

**Tip**: Use `--help` on any script to see all available options!

**Tip**: See `README-SCRIPTS.md` for comprehensive documentation and troubleshooting!
