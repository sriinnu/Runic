# Cross-Platform Parity Matrix

Last updated: 2026-02-23  
Owner: Runic core team

## Status Legend

- `done`: implemented and validated
- `partial`: available with notable gaps
- `planned`: roadmap item, not implemented yet
- `blocked`: cannot proceed until dependency/platform issue is resolved

## Product Surface Parity

| Capability | macOS | Windows | Linux | Web |
|---|---|---|---|---|
| Provider usage fetch (Codex/Claude/Gemini/Copilot/etc.) | done | planned | planned | planned |
| Usage ledger aggregation (daily/session/models/projects) | done | planned | planned | planned |
| Forecast confidence bands (`p50/p80/p95`) | done | planned | planned | planned |
| Anomaly explainability (severity + rationale) | done | planned | planned | planned |
| Policy engine (warn/soft-limit/hard-stop core model) | done | planned | planned | planned |
| Team showback/chargeback export model (JSON/CSV) | done | planned | planned | planned |
| OTel GenAI ingestion adapter (feature-flagged) | done | planned | planned | planned |
| Menu bar status icon + animated refresh states | done | blocked | blocked | blocked |
| Provider settings pane + diagnostics | done | planned | planned | planned |
| Calendar history view (provider activity) | done | planned | planned | planned |
| Secure secret storage (API tokens) | partial | planned | planned | planned |
| CLI usage/cost/insights | done | planned | planned | planned |
| Widget extension | done | blocked | blocked | blocked |

## Provider-Detail Granularity Parity

| Provider | Model detail | Token detail | Project attribution | Notes |
|---|---|---|---|---|
| Claude | done | done | done | Local ledger-backed |
| Codex | done | done | done | Local ledger-backed |
| Copilot | partial | partial | planned | Quota-category windows, no full project-level attribution |
| Gemini | partial | partial | planned | Model quota windows, no full project-level attribution |
| Antigravity | partial | partial | planned | Model quota windows, no full project-level attribution |
| Cursor | partial | partial | planned | Depends on provider data exposure |
| API providers (OpenRouter/Azure/Bedrock/etc.) | partial | partial | planned | Varies by provider API payload |

## Gate To Mark A Platform As `done`

1. Build and test pipeline is green on that platform for core + CLI.
2. Usage ledger summaries and provider identity isolation are validated.
3. Secrets are stored using platform-appropriate secure storage.
4. Forecast/anomaly/policy insights pass deterministic snapshot tests.
5. Release gate checklist is fully passed for that platform.
