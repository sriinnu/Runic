# Runic Feature And UI/UX Roadmap (2026-02-22)

Branch: `feat/research-uiux-core-next`

## Objective

Identify high-impact features and UI/UX upgrades for Runic's macOS-first product and cross-platform roadmap, using:

- Current codebase direction (`RunicCore` + menu insights + budgets/forecast/anomaly work)
- External product signals (GitHub OSS LLM observability/gateway stacks)
- Research signals (forecasting and anomaly detection papers)

## External Signals (Primary Sources)

1. Langfuse: LLM observability, prompt management, evaluations, datasets, and OTel integrations.
   - https://github.com/langfuse/langfuse
2. Helicone: AI gateway + observability, metrics (including cost), prompt/version workflows, and 100+ model access.
   - https://github.com/Helicone/helicone
   - https://github.com/Helicone/ai-gateway
3. LiteLLM features: spend tracking by model/key/user/team and budget/rate-limit controls.
   - https://www.litellm.ai/features
4. Portkey gateway: reliability primitives (fallbacks/retries/load balancing), cost management (smart caching, usage analytics, provider optimization).
   - https://github.com/Portkey-AI/gateway
5. OpenLIT: OTel-native observability with cost tracking for custom/fine-tuned models.
   - https://github.com/openlit/openlit
6. OpenTelemetry GenAI/OpenAI semantic conventions (`Status: Development`; migration opt-in flags).
   - https://opentelemetry.io/docs/specs/semconv/gen-ai/openai/
7. Chronos (2024): pretrained probabilistic forecasting on 42 datasets; strong zero-shot behavior.
   - https://arxiv.org/abs/2403.07815
   - https://github.com/amazon-science/chronos-forecasting
8. TimesFM (ICML 2024): decoder-only time-series foundation model with zero-shot forecasting focus.
   - https://arxiv.org/abs/2310.10688
   - https://github.com/google-research/timesfm
9. TimeEval: anomaly detection benchmarking toolkit with 700+ datasets.
   - https://github.com/TimeEval/TimeEval
10. SigLLM: two anomaly pipelines (prompt-based and forecast-residual detector).
   - https://github.com/sintel-dev/sigllm
11. Apple VoiceOver evaluation guidance for complete task coverage and accurate labels, including chart accessibility guidance.
   - https://developer-mdn.apple.com/help/app-store-connect/manage-app-accessibility/voiceover-evaluation-criteria

## What This Means For Runic (Inference)

Inference from the above sources:

- The market baseline is moving from "usage display" to "control plane": budgets, policy, routing, reliability, and explainability.
- Forecasting is shifting from single deterministic projections to probabilistic forecasts with confidence bands.
- Anomaly systems are becoming multi-signal (tokens, spend, request patterns) and benchmarked/validated.
- UI quality expectation is now "operator-ready": fast triage, actionable next-step copy, and reliable accessibility.

## Priority Feature Tracks

### P0: Cost Control Center (Operator-Grade)

Add a policy engine that can do more than alert:

- Budget scopes: provider, model, project, team, user
- Enforcement modes: warn, soft-limit, hard-stop, cooldown
- Automatic actions:
  - downgrade model recommendation
  - route to cheaper provider/model
  - temporary key throttling
- Audit log for every enforcement decision

Why:

- Aligns with LiteLLM/Portkey/OpenMeter direction.
- Turns Runic from observer to controller.

### P0: Probabilistic Forecasts (Not Single-Point)

Upgrade forecast insight lines to include confidence:

- Show `p50`, `p80`, `p95` month-end forecast
- Visualize confidence band in menu detail popover/card
- Add "risk of budget breach by date" as probability

Why:

- Chronos/TimesFM emphasize robust zero-shot forecasting; practical value is uncertainty-aware decisions.

### P0: Explainable Anomaly Engine v2

Current anomaly support exists; extend it:

- Detect across tokens, spend, request count, cost-per-1k, burstiness
- Add root-cause hints:
  - top model delta
  - top project delta
  - top provider shift
- Severity with rationale:
  - "High due to +182% tokens and +74% cost vs 7d baseline"

Why:

- Improves trust and operator response speed.
- Matches SigLLM/TimeEval-style evaluation mindset.

### P1: Unified Telemetry Import (OTel GenAI)

Add ingest path for OTel GenAI events/spans:

- Parse selected semantic fields (model, operation, token usage, errors)
- Normalize into Runic ledger schema
- Keep compatibility flag around OTel semconv instability (`gen_ai_latest_experimental` migration concerns)

Why:

- Vendor-neutral ingest path.
- Enables cross-tool interoperability (Langfuse/OpenLIT ecosystems).

### P1: Team FinOps Layer

Add internal chargeback/showback views:

- Team/org/project rollups
- Cost allocation percentages
- Shared budget pools with split ownership
- Monthly export (CSV/JSON)

Why:

- Natural extension of existing provider/project logic and budget store.
- Strong fit for organizations with multi-provider AI spend.

### P1: Cross-Platform Feature Parity Tracker

For Windows/Linux/web direction, define explicit parity matrix:

- Feature rows: menu insights, alerting, budgets, anomaly, forecast, keychain/secret handling
- Platform columns: macOS, Windows, Linux, web
- Status: done / partial / blocked (with owner)

Why:

- Reduces roadmap drift.
- Makes release quality measurable.

## UI/UX Upgrades (Focused, Non-Boilerplate)

### 1. Three-Layer Insight Density

Use progressive disclosure consistently:

- Glance: 1-line health + spend trend arrow + risk chip
- Analyst: model/project deltas + anomaly and forecast confidence
- Operator: policy state, throttles, budget enforcement history

### 2. Action-First Error Copy

Every failure line should provide:

- what failed
- likely cause
- immediate recovery action
- copyable diagnostic key

### 3. Contextual Sparkline + Delta Chips

For each provider card:

- 7-day sparkline for tokens and spend
- chips: `+/- % vs 7d avg`, `burn/hr`, `budget risk`

### 4. Accessibility Hardening (Ship Quality)

Explicitly verify:

- all actionable controls have concise accessibility labels
- common user tasks are possible using only VoiceOver
- data visualizations include text alternatives

### 5. Notification Hygiene

- Suppress redundant alerts during known cooldown windows
- Group related anomalies into one actionable notification
- Include one-click route to relevant menu section

## Suggested Implementation Sequence

1. Forecast confidence bands (low-medium complexity, high user value)
2. Anomaly explainability v2
3. Cost Control Center policy engine (warn + soft-limit first)
4. OTel import beta (feature flag)
5. Team FinOps rollups and exports
6. Cross-platform parity gating in CI/docs

## Concrete Next Coding Tasks

1. Extend `UsageLedgerSpendForecast` to carry quantiles and confidence metadata.
2. Add `UsageLedgerAnomalyExplanation` model and formatter surface for menu cards.
3. Introduce `PolicyDecision` and `PolicyEngine` in `RunicCore` (platform-agnostic).
4. Add UI chips and operator detail row in `MenuCardView` and menu helpers.
5. Add tests:
   - forecast quantile formatting
   - anomaly explanation precedence
   - policy decision routing logic
6. Add `docs/research/parity_matrix.md` template for platform rollout governance.

## Notes

- This document intentionally mixes external evidence + implementation inference.
- External evidence is linked above; internal recommendations are adapted to the current Runic architecture and recent branch history.
