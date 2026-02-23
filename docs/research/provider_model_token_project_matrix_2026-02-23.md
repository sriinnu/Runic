# provider model/token/project coverage matrix (2026-02-23)

## question addressed

Can Runic show per-model usage, token counts, and project-level attribution for providers like Copilot, OpenRouter, Azure OpenAI, and AWS Bedrock?

## capability summary

| provider | model usage | token metrics | project attribution | notes |
| --- | --- | --- | --- | --- |
| copilot | yes | no (not exposed in official usage metrics) | no (no explicit repo/project field in metrics schema) | org/admin usage metrics can still show model mix |
| openrouter | yes | yes | partial (needs caller-side project tagging) | usage/cost endpoints expose model and token/cost data |
| azure openai | yes | yes | yes (resource/project scope + custom telemetry) | best source is Azure Monitor metrics + project resources |
| aws bedrock | yes | yes | partial (via request metadata + logs) | CloudWatch tokens by model; project mapping requires metadata/log strategy |

## current Runic status

- Added UI coverage badges for providers through `ProviderUsageCoverage`.
- Marked current coverage in metadata:
  - `codex`: models + tokens + projects
  - `claude`: models + tokens + projects
  - `openrouter`: models + tokens
  - `copilot`: models

## implementation plan (cross-platform)

1. OpenRouter deep usage:
   - Add per-model aggregation from generation/usage API into `UsageLedger`-compatible summaries.
   - Expose project attribution through optional request metadata key (for example `X-Runic-Project`).

2. Azure OpenAI provider:
   - Add provider with `endpoint + api key` settings and Azure Monitor pull path.
   - Ingest `InputTokens`, `OutputTokens`, `TotalTokens` by model/deployment.
   - Add optional Entra auth mode later for enterprise setups.

3. Bedrock provider:
   - Add provider with `region + profile` settings.
   - Pull model/token metrics from CloudWatch (`ModelId` dimension).
   - Add optional project grouping from invocation log metadata.

4. Unified data contract:
   - Normalize provider outputs into one cross-platform schema:
     - `model_usage[]`
     - `token_totals`
     - `project_usage[]`
   - Keep all logic in `RunicCore` so macOS/Linux/Windows reuse the same pipeline.
