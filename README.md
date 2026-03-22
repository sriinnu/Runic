# Runic

<div align="center">

<img src="runic.png" alt="Runic — infinity symbol with usage bars" width="160" />

**AI usage monitoring for your Mac menubar.**

Track usage, costs, and quotas across 26 AI providers in real time.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-000?logo=apple)
![Swift 6.2](https://img.shields.io/badge/Swift-6.2-F05138?logo=swift&logoColor=white)
![License MIT](https://img.shields.io/badge/license-MIT-blue)

</div>

---

## What it does

Runic sits in your menubar and shows how much of your AI subscription you've used, what it's costing, and when your limits reset. One click gives you charts, breakdowns, and forecasts across all your providers.

## Supported Providers

| | | |
|---|---|---|
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
- Provider tab bar with brand icons
- Hero stat with today's token count and cost
- Inline line chart (1h / 6h / 1d / 7d / 30d)
- Glassmorphism stat cards with sparklines
- Usage progress bars with sheen animation
- Live "Updated Xs ago" timestamp

**Charts**
- Usage timeline (area + line)
- Today by hour (24-bar)
- Last 7 days (weekly bars)
- Subscription utilization (Daily / Weekly / Monthly)
- Usage window comparison (session vs weekly)
- Model breakdown (donut)
- Project breakdown (bar)

**Analytics**
- Token usage (input, output, cache)
- Cost estimation with per-model pricing
- Spend forecasting and budget alerts
- Project and model attribution

**Export & Notifications**
- Export as CSV or JSON
- Budget breach alerts via macOS notifications
- macOS widgets
- CLI tool (`RunicCLI`)

**Design**
- Dark / Light / System theme
- Liquid UI with glass materials and animated progress bars
- SF Rounded typography
- VoiceOver accessible
- Sparkle auto-updates

## Install

**Download** the latest release from [GitHub Releases](https://github.com/sriinnu/Runic/releases/latest), unzip, and drag `Runic.app` to Applications. Signed and notarized — no Gatekeeper warnings.

**Or build from source:**

```bash
git clone https://github.com/sriinnu/Runic.git
cd Runic
./Scripts/compile_and_run.sh
```

## Configure

Open **Preferences** from the menubar. Each provider has its own settings:

- **API-based** (Groq, Mistral, z.ai, etc.): Paste your API key
- **CLI-based** (Claude, Codex): Detected automatically
- **Cloud** (Bedrock, Vertex AI): Set environment variables

All tokens stored in macOS Keychain — no password prompts.

## Privacy

Zero telemetry. No analytics. No crash reporting. All data stays on your Mac.

## License

MIT. See [LICENSE](LICENSE).

---

<div align="center">

Built by [Srinivas Pendela](https://github.com/sriinnu)

</div>
