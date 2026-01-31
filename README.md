# Runic - AI Provider Usage Monitoring

<div align="center">

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20iOS%20%7C%20Windows%20%7C%20Android-lightgrey)
![Tests](https://img.shields.io/badge/tests-35%2F35%20passing-success)
![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![TypeScript](https://img.shields.io/badge/TypeScript-5.7-blue.svg)

### *Persistence. Intuition. Consciousness.*

**Monitor AI provider usage limits across all your devices. Predict when you'll hit rate limits. Optimize costs. Stay in control.**

[Features](#features) • [Installation](#installation) • [Security](#security) • [Documentation](#documentation) • [Contributing](#contributing)

</div>

---

## 🌟 Highlights

- 🔒 **Privacy-First**: Zero telemetry, all data stays on your devices
- 🔐 **Secure**: Tokens stored in macOS Keychain, no hardcoded secrets
- 📊 **Comprehensive Tracking**: Account types, reset timing, model usage, project attribution
- 🌍 **Cross-Platform**: macOS, iOS, Windows, Android, CLI
- 🤖 **AI-Ready**: REST API + MCP servers for AI assistant integration
- ⚡ **Performance**: Minimal CPU/memory usage, 60 FPS animations

---

## 📑 Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Platform Support](#platform-support)
- [Security](#security)
- [Documentation](#documentation)
- [Contributing](#contributing)
- [License](#license)

---

## ✨ Features

### 1. **Native Apps** ✅
- **macOS**: SwiftUI menubar app with live usage tracking
- **iOS**: Native app + Home/Lock Screen widgets + Live Activities
- **Windows**: React Native app with system tray
- **Android**: React Native app with Material You theming

### 2. **Command Line** ✅
- Enhanced CLI with model/project tracking
- Commands: `models`, `projects`, `alerts`, `reset`
- JSON output mode for scripting

### 3. **MCP Servers** ✅ (Enhanced v2.0)
- **Persistence**: SQLite storage with model/project filtering
- **Intuition**: Cost prediction, model recommendations
- **Consciousness**: Real-time health monitoring

### 4. **REST API** ✅
- Full REST API for AI assistant integration
- WebSocket for real-time updates
- Webhook support for notifications

### 5. **Sync Infrastructure** ✅
- iCloud CloudKit sync (macOS ↔ iOS)
- Cross-platform REST API sync
- Background sync with conflict resolution

---

## 🚀 Installation

### Prerequisites

- **macOS/iOS**: Xcode 15.0+, Swift 6.2+
- **Windows/Android**: Node.js 18+, npm 9+
- **CLI**: Swift toolchain
- **API/MCP Servers**: Node.js 18+

### Quick Install

```bash
# Clone the repository
git clone https://github.com/sriinnu/Runic.git
cd Runic

# Setup all platforms (automated)
./Scripts/setup-all.sh
```

### Platform-Specific Setup

<details>
<summary><b>macOS</b></summary>

```bash
# Build from source
swift build -c release

# Or use build script
./Scripts/build-macos.sh
```

The app will be available at `.build/release/Runic`

</details>

<details>
<summary><b>iOS</b></summary>

```bash
./Scripts/setup-ios.sh
./Scripts/build-ios.sh
```

Open the generated Xcode project and build.

</details>

<details>
<summary><b>Windows/Android</b></summary>

```bash
./Scripts/setup-react-native.sh

# For Windows
npm run windows

# For Android
npm run android
```

</details>

<details>
<summary><b>CLI</b></summary>

```bash
swift build -c release
.build/release/RunicCLI --help
```

</details>

<details>
<summary><b>API Server</b></summary>

```bash
cd api-server
npm install
npm run dev
# Server runs on http://localhost:3000
```

</details>

<details>
<summary><b>MCP Servers</b></summary>

```bash
cd mcp-servers
./setup.sh
./verify-all-servers.sh
```

</details>

---

## 🎯 Quick Start

### macOS Menubar App

1. Build and run the app
2. Click the menubar icon
3. View real-time usage for all providers
4. Access preferences to configure providers

### CLI Usage

```bash
# View usage for all providers
RunicCLI usage --json --pretty

# View specific provider
RunicCLI usage --provider claude

# Model usage breakdown
RunicCLI models --provider claude --days 7

# Project tracking
RunicCLI projects --stats runic-ios
```

### For AI Assistant Apps

Start the API server to access usage data:

```bash
cd api-server
npm run dev
```

**Fetch all usage data:**
```typescript
const response = await fetch('http://localhost:3000/api/v1/usage?includeModels=true&includeProjects=true');
const { snapshots } = await response.json();
```

See **[INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md)** for complete API documentation.

---

## Platform Support

| Platform | Status | Technology |
|----------|--------|------------|
| **macOS 14+** | ✅ Complete | Swift/SwiftUI |
| **iOS 17+** | ✅ Complete | SwiftUI + WidgetKit |
| **Windows 11** | ✅ Complete | React Native |
| **Android 14+** | ✅ Complete | React Native |
| **CLI** | ✅ Complete | Swift |
| **REST API** | ✅ Complete | Node.js/Express |

---

## Enhanced Tracking

### What's Tracked

- ✅ **Account type**: subscription vs usage-based
- ✅ **Reset timing**: countdown to when limits reset
- ✅ **Model usage**: which AI models you use (GPT-4, Claude Opus, etc.)
- ✅ **Project attribution**: which projects use which providers
- ✅ **Token breakdown**: by model and by project
- ✅ **Cost estimation**: how much you're spending

### Example Data

```json
{
  "provider": "claude",
  "accountType": "subscription",
  "primary": {
    "usedPercent": 85.5,
    "resetsAt": "2026-01-31T14:00:00Z",
    "resetDescription": "Resets in 3h 30m"
  },
  "primaryModel": {
    "modelName": "claude-3-5-sonnet-20241022",
    "tier": "sonnet"
  },
  "activeProject": {
    "projectID": "runic-ios",
    "projectName": "Runic iOS App"
  },
  "tokenUsage": {
    "totalTokens": 1700000,
    "modelBreakdown": {
      "claude-opus-4": 500000,
      "claude-sonnet-3.5": 1200000
    }
  },
  "estimatedCost": 12.50
}
```

---

## 🔒 Security

**Security Score: ⭐⭐⭐⭐⭐ (5/5)**

Runic follows security best practices and has been audited for token leakage and privacy concerns.

### Security Features

- ✅ **Keychain Storage**: All API tokens stored in macOS Keychain with encryption
- ✅ **No Hardcoded Secrets**: Zero hardcoded tokens or credentials in source code
- ✅ **HTTPS Only**: All network requests use HTTPS
- ✅ **Zero Telemetry**: No analytics, tracking, or crash reporting
- ✅ **Privacy-First**: All data stays on your devices
- ✅ **No Token Logging**: Tokens never logged to console or files
- ✅ **Legitimate Endpoints**: Only connects to official provider APIs

### Security Audit

Full security audit available: **[SECURITY_AUDIT.md](SECURITY_AUDIT.md)**

**Key Findings:**
- ZERO token leakage vectors
- No data exfiltration
- No third-party tracking
- All endpoints verified legitimate

### Verified Safe Domains

All network connections go to official provider APIs:
- `api.github.com` (GitHub Copilot)
- `api.groq.com` (Groq)
- `openrouter.ai` (OpenRouter)
- `platform.minimax.io` (MiniMax)
- `api.factory.ai` (Factory.ai)

**No unexpected network activity. No hidden tracking.**

---

## 📚 Documentation

### Core Documentation

| Document | Description |
|----------|-------------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Multi-platform system architecture |
| [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md) | AI assistant integration guide |
| [SECURITY_AUDIT.md](SECURITY_AUDIT.md) | Comprehensive security audit |
| [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) | Complete project summary |

### Component Documentation

| Component | Documentation |
|-----------|---------------|
| **API Server** | [api-server/README.md](api-server/README.md) |
| **MCP Servers** | [mcp-servers/README.md](mcp-servers/README.md) |
| **Build Scripts** | [Scripts/README-SCRIPTS.md](Scripts/README-SCRIPTS.md) |
| **React Native** | [runic-cross-platform/README.md](runic-cross-platform/README.md) |

### Additional Resources

- [Testing Guide](TESTING.md)
- [Code Review](docs/CODEBASE_REVIEW.md)
- [CLI Commands](docs/cli-commands/README.md)
- [Sync Implementation](docs/sync/README.md)

---

## 🤝 Contributing

We welcome contributions! Here's how you can help:

### Development Setup

```bash
# Clone and setup
git clone https://github.com/sriinnu/Runic.git
cd Runic
./Scripts/setup-all.sh

# Run tests
./test-all.sh
```

### Code Quality Guidelines

- ✅ All files must have JSDoc/Swift documentation
- ✅ No file exceeds 300-400 lines
- ✅ TypeScript strict mode enabled
- ✅ Swift concurrency enabled
- ✅ All tests must pass

### Submitting Changes

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Reporting Issues

- Security issues: See [SECURITY_AUDIT.md](SECURITY_AUDIT.md) for responsible disclosure
- Bug reports: Open an issue with reproduction steps
- Feature requests: Open an issue with use case description

---

## 🙏 Acknowledgments

Built with:
- [Swift](https://swift.org/) - Modern, safe, and fast
- [SwiftUI](https://developer.apple.com/xcode/swiftui/) - Declarative UI framework
- [React Native](https://reactnative.dev/) - Cross-platform mobile development
- [TypeScript](https://www.typescriptlang.org/) - Type-safe JavaScript
- [Sparkle](https://sparkle-project.org/) - Auto-update framework
- [MCP](https://modelcontextprotocol.io/) - Model Context Protocol

Special thanks to the AI agents that built this project following strict quality guidelines.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

```
MIT License

Copyright (c) 2026 Srinivas Pendela

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction...
```

---

## 📞 Support

- 📖 **Documentation**: See [docs/](docs/) directory
- 🐛 **Issues**: [GitHub Issues](https://github.com/sriinnu/Runic/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/sriinnu/Runic/discussions)
- 🔒 **Security**: See [SECURITY_AUDIT.md](SECURITY_AUDIT.md)

---

<div align="center">

**Built with Persistence, Intuition, and Consciousness 🔮**

*Multi-agent AI system - January 31, 2026*

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20iOS%20%7C%20Windows%20%7C%20Android-lightgrey)](https://github.com/sriinnu/Runic)
[![Tests](https://img.shields.io/badge/tests-35%2F35%20passing-success)](./test-all.sh)

</div>
