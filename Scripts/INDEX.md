# Runic Build Scripts - Complete Index

**Welcome to the Runic build automation system!** This index helps you navigate all scripts and documentation.

## 🚀 Start Here

| Document | Purpose | Read Time |
|----------|---------|-----------|
| [GETTING-STARTED-CHECKLIST.md](GETTING-STARTED-CHECKLIST.md) | Step-by-step setup guide | 10 min |
| [QUICK-REFERENCE.md](QUICK-REFERENCE.md) | Quick command lookup | 2 min |
| [README-SCRIPTS.md](README-SCRIPTS.md) | Complete documentation | 30 min |

**First time?** Start with [GETTING-STARTED-CHECKLIST.md](GETTING-STARTED-CHECKLIST.md)

**Need a quick command?** Check [QUICK-REFERENCE.md](QUICK-REFERENCE.md)

**Want details?** Read [README-SCRIPTS.md](README-SCRIPTS.md)

---

## 📁 All Files at a Glance

### Setup Scripts (One-time)

| Script | Purpose | Platforms | Size |
|--------|---------|-----------|------|
| **setup-all.sh** ⭐ | Setup everything | All | 9.4K |
| setup-ios.sh | Setup iOS project | iOS | 11K |
| setup-react-native.sh | Setup React Native | Android, Windows | 14K |

**Quick Start**: `./scripts/setup-all.sh --verbose`

### Build Scripts (Daily use)

| Script | Purpose | Output | Size |
|--------|---------|--------|------|
| build-macos.sh | Build macOS app | builds/macos/Runic.app | 14K |
| build-ios.sh | Build iOS app | builds/ios/*.ipa | 13K |
| build-android.sh | Build Android app | builds/android/*.apk | 13K |
| build-windows.sh | Build Windows app | builds/windows/*.exe | 14K |

**Quick Build**: `./scripts/build-macos.sh`

### CI/CD Configuration

| File | Purpose | Location | Size |
|------|---------|----------|------|
| ci-config.yml | GitHub Actions | Copy to .github/workflows/ | 15K |

**Setup CI**: `cp scripts/ci-config.yml .github/workflows/ci.yml`

### Documentation

| Document | Focus | Best For |
|----------|-------|----------|
| README-SCRIPTS.md ⭐ | Complete guide | Everything |
| QUICK-REFERENCE.md | Commands | Daily use |
| GETTING-STARTED-CHECKLIST.md | Setup steps | First time |
| CREATION-SUMMARY.md | What was built | Overview |
| DIRECTORY-STRUCTURE.md | File organization | Navigation |
| INDEX.md | This file | Finding things |

---

## 🎯 Common Tasks

### First-Time Setup
1. Read: [GETTING-STARTED-CHECKLIST.md](GETTING-STARTED-CHECKLIST.md)
2. Run: `./scripts/setup-all.sh --verbose`
3. Configure code signing (see checklist)

### Daily Development
- macOS: `./scripts/build-macos.sh --skip-tests --skip-signing`
- iOS: `./scripts/build-ios.sh --simulator --skip-tests`
- Android: `./scripts/build-android.sh --variant debug`
- Windows: `./scripts/build-windows.sh --configuration Debug`

### Release Build
- macOS: `./scripts/build-macos.sh`
- iOS: `./scripts/build-ios.sh --archive`
- Android: `./scripts/build-android.sh --aab`
- Windows: `./scripts/build-windows.sh`

### Troubleshooting
1. Try: `./scripts/build-macos.sh --dry-run --verbose`
2. Read: [README-SCRIPTS.md](README-SCRIPTS.md) → Troubleshooting
3. Check: Script output with `--verbose` flag

### CI/CD Setup
1. Copy: `cp scripts/ci-config.yml .github/workflows/ci.yml`
2. Configure: GitHub Secrets (see [README-SCRIPTS.md](README-SCRIPTS.md))
3. Push: `git push` to trigger workflow

---

## 📚 Documentation by Topic

### Setup & Installation
- **First-time setup**: [GETTING-STARTED-CHECKLIST.md](GETTING-STARTED-CHECKLIST.md) → Prerequisites
- **macOS setup**: [README-SCRIPTS.md](README-SCRIPTS.md) → macOS Development
- **iOS setup**: [README-SCRIPTS.md](README-SCRIPTS.md) → iOS Development
- **Android setup**: [README-SCRIPTS.md](README-SCRIPTS.md) → Android Development
- **Windows setup**: [README-SCRIPTS.md](README-SCRIPTS.md) → Windows Development

### Building
- **Quick commands**: [QUICK-REFERENCE.md](QUICK-REFERENCE.md)
- **macOS builds**: [README-SCRIPTS.md](README-SCRIPTS.md) → build-macos.sh
- **iOS builds**: [README-SCRIPTS.md](README-SCRIPTS.md) → build-ios.sh
- **Android builds**: [README-SCRIPTS.md](README-SCRIPTS.md) → build-android.sh
- **Windows builds**: [README-SCRIPTS.md](README-SCRIPTS.md) → build-windows.sh

### Code Signing
- **iOS signing**: [README-SCRIPTS.md](README-SCRIPTS.md) → iOS Code Signing
- **Android signing**: [README-SCRIPTS.md](README-SCRIPTS.md) → Android Code Signing
- **Quick setup**: [GETTING-STARTED-CHECKLIST.md](GETTING-STARTED-CHECKLIST.md) → Code Signing

### CI/CD
- **GitHub Actions**: [README-SCRIPTS.md](README-SCRIPTS.md) → CI/CD Configuration
- **Secrets setup**: [README-SCRIPTS.md](README-SCRIPTS.md) → GitHub Secrets
- **Workflow file**: [ci-config.yml](ci-config.yml)

### Troubleshooting
- **Common issues**: [README-SCRIPTS.md](README-SCRIPTS.md) → Troubleshooting
- **macOS issues**: [README-SCRIPTS.md](README-SCRIPTS.md) → macOS Build Issues
- **iOS issues**: [README-SCRIPTS.md](README-SCRIPTS.md) → iOS Build Issues
- **Android issues**: [README-SCRIPTS.md](README-SCRIPTS.md) → Android Build Issues
- **Windows issues**: [README-SCRIPTS.md](README-SCRIPTS.md) → Windows Build Issues

---

## 🔧 Script Features

All scripts include:
- ✅ `--help` flag for usage information
- ✅ `--dry-run` flag for safe testing
- ✅ `--verbose` flag for detailed output
- ✅ Color-coded output for better UX
- ✅ Prerequisite checking
- ✅ Error handling with clear messages
- ✅ Build summaries

**Example**: `./scripts/build-macos.sh --help`

---

## 🏗️ Project Structure

```
Runic/
├── scripts/                    # ← You are here
│   ├── Setup Scripts
│   ├── Build Scripts
│   ├── CI/CD Config
│   └── Documentation
│
├── builds/                     # Build output
│   ├── macos/
│   ├── ios/
│   ├── android/
│   └── windows/
│
├── Sources/                    # Source code
├── RuniciOS/                   # iOS project
└── runic-cross-platform/       # React Native
```

See [DIRECTORY-STRUCTURE.md](DIRECTORY-STRUCTURE.md) for complete structure.

---

## 📊 Statistics

| Metric | Value |
|--------|-------|
| Setup Scripts | 3 |
| Build Scripts | 4 |
| Documentation Files | 6 |
| Total New Files | 12 |
| Lines of Code | ~7,500 |
| Platforms Supported | 4 |
| Time Saved | Countless hours! |

---

## 🎓 Learning Path

### Beginner
1. ✅ Read [GETTING-STARTED-CHECKLIST.md](GETTING-STARTED-CHECKLIST.md)
2. ✅ Run `./scripts/setup-all.sh --dry-run --verbose`
3. ✅ Run `./scripts/setup-all.sh`
4. ✅ Try `./scripts/build-macos.sh --help`
5. ✅ Build your first app: `./scripts/build-macos.sh`

### Intermediate
1. ✅ Bookmark [QUICK-REFERENCE.md](QUICK-REFERENCE.md)
2. ✅ Set up code signing for iOS/Android
3. ✅ Build all platforms
4. ✅ Customize build flags
5. ✅ Read platform-specific sections in [README-SCRIPTS.md](README-SCRIPTS.md)

### Advanced
1. ✅ Set up CI/CD with GitHub Actions
2. ✅ Configure deployment to TestFlight/Play Store
3. ✅ Customize scripts for your workflow
4. ✅ Contribute improvements back to project
5. ✅ Read full [README-SCRIPTS.md](README-SCRIPTS.md)

---

## ⚡ Quick Reference

### Most Common Commands
```bash
# Setup (first time)
./scripts/setup-all.sh

# Build macOS
./scripts/build-macos.sh

# Build iOS (simulator)
./scripts/build-ios.sh --simulator

# Build Android (debug)
./scripts/build-android.sh --variant debug

# Get help
./scripts/build-macos.sh --help

# Test without executing
./scripts/build-macos.sh --dry-run --verbose
```

### Where to Find Things
- **Command syntax**: [QUICK-REFERENCE.md](QUICK-REFERENCE.md)
- **Detailed guide**: [README-SCRIPTS.md](README-SCRIPTS.md)
- **Setup steps**: [GETTING-STARTED-CHECKLIST.md](GETTING-STARTED-CHECKLIST.md)
- **File locations**: [DIRECTORY-STRUCTURE.md](DIRECTORY-STRUCTURE.md)
- **What was created**: [CREATION-SUMMARY.md](CREATION-SUMMARY.md)

---

## 🆘 Getting Help

### 1. Built-in Help
```bash
./scripts/setup-all.sh --help
./scripts/build-macos.sh --help
```

### 2. Dry-Run Mode
```bash
./scripts/build-macos.sh --dry-run --verbose
```

### 3. Check Documentation
- Quick answers: [QUICK-REFERENCE.md](QUICK-REFERENCE.md)
- Detailed help: [README-SCRIPTS.md](README-SCRIPTS.md)
- Setup issues: [GETTING-STARTED-CHECKLIST.md](GETTING-STARTED-CHECKLIST.md)

### 4. Troubleshooting Section
See [README-SCRIPTS.md](README-SCRIPTS.md) → Troubleshooting

### 5. Verbose Output
```bash
./scripts/build-macos.sh --verbose
```

---

## ✨ Pro Tips

1. **Always try `--dry-run` first** to see what a script will do
2. **Use `--verbose`** when debugging issues
3. **Read error messages carefully** - they include solutions
4. **Bookmark QUICK-REFERENCE.md** for daily use
5. **Keep README-SCRIPTS.md open** when troubleshooting
6. **Use `--help`** to discover all options
7. **Start simple** - build one platform at a time
8. **Configure CI/CD early** - catch issues faster

---

## 🎯 Success Checklist

You know you're set up correctly when:
- ✅ `./scripts/setup-all.sh` completes without errors
- ✅ `./scripts/build-macos.sh` produces `builds/macos/Runic.app`
- ✅ `./scripts/build-ios.sh --simulator` runs successfully
- ✅ `./scripts/build-android.sh --variant debug` creates APK
- ✅ CI/CD workflow passes on GitHub
- ✅ You can build all platforms locally

---

## 📖 Full Documentation Map

```
scripts/
├── INDEX.md ⭐                        # This file - Start here
│
├── GETTING-STARTED-CHECKLIST.md      # Step-by-step setup
│   ├── Prerequisites
│   ├── First-time setup
│   ├── Code signing
│   ├── First builds
│   ├── CI/CD setup
│   └── Daily workflow
│
├── QUICK-REFERENCE.md                # Quick command lookup
│   ├── One-line commands
│   ├── Common flags
│   ├── Build outputs
│   └── Troubleshooting
│
├── README-SCRIPTS.md                 # Complete documentation
│   ├── Overview
│   ├── Quick Start
│   ├── Setup Scripts (detailed)
│   ├── Build Scripts (detailed)
│   ├── CI/CD Configuration
│   ├── Platform-Specific Guides
│   ├── GitHub Secrets
│   ├── Troubleshooting
│   └── Advanced Usage
│
├── CREATION-SUMMARY.md               # What was created
│   ├── File list
│   ├── Features
│   ├── Statistics
│   └── Usage examples
│
└── DIRECTORY-STRUCTURE.md            # File organization
    ├── Directory tree
    ├── Execution flow
    ├── Artifact structure
    └── Navigation guide
```

---

## 🚀 Ready to Build?

**Quickest start:**
```bash
# 1. Setup
./scripts/setup-all.sh

# 2. Build
./scripts/build-macos.sh

# 3. Run
open builds/macos/Runic.app
```

**Need help?** Check [GETTING-STARTED-CHECKLIST.md](GETTING-STARTED-CHECKLIST.md)

**Already set up?** See [QUICK-REFERENCE.md](QUICK-REFERENCE.md)

**Want to learn more?** Read [README-SCRIPTS.md](README-SCRIPTS.md)

---

**Happy Building! 🎉**

For questions, issues, or contributions, see the main Runic repository.
