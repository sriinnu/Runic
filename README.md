# Runic

<div align="center">

<img src="runic.png" alt="Runic" width="128" />

**AI usage monitoring for your Mac menubar.**

Track usage, costs, and quotas across 26 AI providers in real time.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-000?logo=apple)
![Swift 6.2](https://img.shields.io/badge/Swift-6.2-F05138?logo=swift&logoColor=white)
![License MIT](https://img.shields.io/badge/license-MIT-blue)

</div>

---

## What it does

Runic lives in your menubar and shows you how much of your AI subscription you've used, what it's costing, and when your limits reset. One click gives you charts, breakdowns, and forecasts across all your providers.

## Providers

| Provider | Provider | Provider |
|----------|----------|----------|
| Claude | Codex | Cursor |
| Gemini | Copilot | z.ai |
| OpenRouter | Groq | DeepSeek |
| Fireworks | Mistral | Perplexity |
| Kimi | Together | Cohere |
| xAI | Cerebras | SambaNova |
| Azure OpenAI | Bedrock | Vertex AI |
| Qwen | MiniMax | Auggie |
| Antigravity | Factory (Droid) | |

## Features

**Menu dropdown**
- Provider tab bar with brand icons for quick switching
- Hero stat showing today's token count and cost
- Inline line chart with 1h / 6h / 1d / 7d / 30d range picker
- Glassmorphism stat cards (Peak Hour, This Week) with sparklines
- Live "Updated Xs ago" timestamp
- Usage progress bars with sheen animation and glow effects

**Charts** (submenus)
- Usage timeline (area + line, Catmull-Rom interpolated)
- Today by hour (24-bar chart with peak highlight)
- Last 7 days (weekly bar chart)
- Subscription utilization (Daily / Weekly / Monthly)
- Usage window comparison (dual-line session vs weekly)
- Model breakdown (donut chart)
- Project breakdown (horizontal bar chart)

**Analytics**
- Token usage tracking (input, output, cache)
- Cost estimation with per-model pricing
- Spend forecasting with budget breach detection
- Project and model attribution
- Anomaly detection

**Data**
- Export as CSV or JSON
- Budget alerts via macOS notifications
- macOS widgets (usage, history, compact, switcher)
- CLI tool (`RunicCLI`)

**Design**
- Dark / Light / System theme
- Liquid UI: glass materials, gradient borders, animated progress bars
- SF Rounded typography with design tokens (spacing, color, animation)
- VoiceOver accessible
- Sparkle auto-updates

## Install

```bash
git clone https://github.com/sriinnu/Runic.git
cd Runic
./Scripts/compile_and_run.sh
```

This builds the app, signs it, and launches it. The Runic icon appears in your menubar.

To install to Applications:

```bash
cp -R builds/dev/dev-current/Runic.app /Applications/
```

## Build

```bash
# Dev build + run
./Scripts/compile_and_run.sh

# Just build (no launch)
swift build --target Runic

# Build CLI
swift build --target RunicCLI

# Release build
swift build -c release --target Runic
```

Requires macOS 14+ and Swift 6.2+. Sparkle framework is bundled automatically.

## Configure

Open Preferences from the menubar dropdown. Each provider has its own settings:

- **API-based providers** (Groq, Mistral, etc.): Paste your API key
- **CLI-based providers** (Claude, Codex): Detected automatically from local CLI
- **Cloud providers** (Bedrock, Vertex AI): Configure via environment variables

Environment variables:
- `DASHSCOPE_API_KEY` — Qwen / Alibaba DashScope
- `VERTEX_AI_PROJECT`, `VERTEX_AI_LOCATION` — Google Vertex AI
- `AWS_PROFILE` or `AWS_ACCESS_KEY_ID` — AWS Bedrock

All tokens are stored in macOS Keychain with `SecAccess` self-trust (no password prompts).

## Privacy

- Zero telemetry. No analytics. No crash reporting.
- All data stays on your Mac.
- Tokens stored in Keychain, never logged.
- Only connects to official provider APIs.

## License

MIT. See [LICENSE](LICENSE).

---

<div align="center">

Built by [Srinivas Pendela](https://github.com/sriinnu)

</div>
