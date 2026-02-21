# Core Feature Research Log

Date: 2026-02-21
Branch: feat/core

## Goal

Collect concrete, source-backed feature ideas for Runic core roadmap from:
- GitHub projects (production patterns)
- arXiv papers (state-of-the-art approaches)

This file is updated incrementally during research to avoid context loss.

## Status

- [x] Research file created
- [x] Gather current GitHub evidence
- [x] Gather current arXiv evidence
- [x] Synthesize feature candidates with implementation notes
- [x] Prioritize roadmap (Now / Next / Later)

## External Evidence Snapshot

### arXiv evidence (routing, caching, cost/quality)

1. FrugalGPT (2023)
- Link: https://arxiv.org/abs/2305.05176
- Signal: Cascaded LLM usage can cut cost heavily while maintaining quality (paper reports very large cost savings in their setup).
- Relevance to Runic: Runic can add cost-quality simulation and routing recommendations over existing provider usage logs.

2. RouteLLM (2024)
- Link: https://arxiv.org/abs/2406.18665
- Signal: Learned routers can route between strong/weak models with significant cost reduction while preserving much of strong-model quality.
- Relevance to Runic: Add "Routing Advisor" that proposes per-project provider/model policies from real usage history.

3. LLMRouterBench (2026)
- Link: https://arxiv.org/abs/2601.07206
- Signal: Large benchmark shows routing is useful, but many methods are brittle and simple baselines are often hard to beat.
- Relevance to Runic: Favor robust baseline policies first (fallback + threshold + guardrails) before heavier ML routing.

4. vCache (2025)
- Link: https://arxiv.org/abs/2502.03771
- Signal: Semantic caching with error-bound control can reduce redundant LLM calls.
- Relevance to Runic: Add cacheability analytics and "likely cache hit" opportunity scoring per project/workflow.

5. Generative Caching (2025)
- Link: https://arxiv.org/abs/2503.17603
- Signal: Cache systems that generate compact responses for similar prompts improve cost/latency.
- Relevance to Runic: Track prompt similarity buckets and estimate avoidable spend from repeated prompt patterns.

### GitHub and docs evidence (production implementation patterns)

1. LiteLLM
- Repo: https://github.com/BerriAI/litellm
- Reliability docs: https://docs.litellm.ai/docs/proxy/reliability
- Signal: Production-grade patterns include retries, fallbacks, cooldowns, and routing controls.
- Relevance: Runic should expose policy diagnostics and recommend fallback policy quality from observed failures.

2. Helicone AI Gateway
- Repo: https://github.com/Helicone/ai-gateway
- Signal: Unified gateway pattern with routing, load balancing, caching, tracing, and limits.
- Relevance: Runic can add "Gateway Readiness Score" for teams deciding when to adopt a gateway.

3. Langfuse
- Repo: https://github.com/langfuse/langfuse
- Signal: Prompt management, tracing, evals, datasets, and collaborative AI ops workflows.
- Relevance: Runic should support prompt/version correlation and eval score overlays in usage charts.

4. Promptfoo
- Repo: https://github.com/promptfoo/promptfoo
- Signal: Eval + red-team workflows integrated into CI.
- Relevance: Runic can ingest eval outputs and show quality regressions next to spend spikes.

5. OpenAI Evals
- Repo: https://github.com/openai/evals
- Docs link from repo: https://platform.openai.com/docs/guides/evals
- Signal: Evals are a core mechanism to measure model/version quality impact.
- Relevance: Runic can include first-class "Eval Health" alongside budget health.

6. OpenTelemetry GenAI semantic conventions
- Metrics: https://opentelemetry.io/docs/specs/semconv/gen-ai/gen-ai-metrics/
- Spans: https://opentelemetry.io/docs/specs/semconv/gen-ai/gen-ai-spans/
- Signal: Standard fields for provider/model/operation/timing are now defined for GenAI telemetry.
- Relevance: Runic should export normalized telemetry so dashboards/tools interoperate cleanly.

7. MCP specification (tools/prompts)
- Tools: https://modelcontextprotocol.io/specification/2025-06-18/server/tools
- Prompts: https://modelcontextprotocol.io/specification/2025-06-18/server/prompts
- Signal: Standardized tool invocation and prompt serving surface for agentic systems.
- Relevance: Runic can add MCP-specific analytics (tool error rate, latency, prompt-template performance).

## Feature Candidates (for Runic core)

### A) Routing Advisor + Cost-Quality Simulator

What:
- Simulate alternative model/provider routing policies against historical usage ledger data.
- Show projected delta for cost, latency proxy, and quality proxy.

Why now:
- Directly aligned to FrugalGPT + RouteLLM evidence.
- Low dependency because Runic already has usage ledger + provider cost paths.

Implementation sketch:
- Extend `Sources/RunicCore/UsageLedger/UsageLedgerAggregator.swift` with simulation inputs/outputs.
- Add policy models in `Sources/RunicCore/Performance/PerformanceModels.swift`.
- Add menu card in `Sources/Runic/Views/Menu/` (new `RoutingAdvisorMenuView.swift`).

### B) Reliability Policy Score (Fallback/Retry/Cooldown quality)

What:
- Per provider/project score for policy robustness:
  - failure-rate trends
  - fallback coverage
  - timeout/retry efficiency
  - observed "hard fail with no fallback" incidents

Why now:
- Practical baseline recommended by LLMRouterBench-style findings.
- Matches LiteLLM/Helicone operational patterns.

Implementation sketch:
- Persist policy signals in `Sources/RunicCore/Performance/PerformanceStorageImpl.swift`.
- Add scoring service in `Sources/RunicCore/Performance/`.
- Render in `Sources/Runic/Views/Menu/AlertsMenuView.swift` and a dedicated card.

### C) Eval-Linked Spend Analytics

What:
- Ingest eval outputs (Promptfoo/OpenAI Evals style) and align with cost/usage windows.
- Show "quality down + spend up" and "quality stable + cost down" events.

Why now:
- Moves Runic from pure accounting to decision support.

Implementation sketch:
- New ingest model (JSON/YAML adapter) in `Sources/RunicCore/`.
- Cross-join with provider/day/project aggregates in usage ledger pipeline.
- Add view in `Sources/Runic/Views/Performance/PerformanceDashboardView.swift`.

### D) Semantic Cache Opportunity Analyzer

What:
- Detect repeated or near-duplicate prompt patterns and estimate avoidable token cost.
- Flag cache-friendly workflows per project.

Why now:
- Backed by vCache/generative-caching direction and gateway practices.

Implementation sketch:
- Add prompt fingerprint stats in usage ledger models.
- Keep first version lightweight: hash + normalized prompt-template fingerprint, not full semantic embeddings.
- UI card in menu + performance dashboard.

### E) OpenTelemetry GenAI Export

What:
- Export Runic telemetry in OTel GenAI-compatible fields.
- Include provider, request model, response model, operation, and latency buckets.

Why now:
- Standardization unlocks external dashboards and enterprise integrations.

Implementation sketch:
- Add mapper in `Sources/RunicCore/Logging/` or `Sources/RunicCore/Performance/`.
- Optional sink to JSON/OTLP compatible format.

### F) MCP Tool and Prompt Analytics

What:
- Track MCP tool-call rates, latency, error classes, and prompt-template success trends.
- Show per-project MCP "tool reliability heatmap."

Why now:
- Agentic workflows are increasingly MCP-centric.

Implementation sketch:
- Add MCP event model in `RunicCore`.
- New menu views under `Sources/Runic/Views/Menu/`.

## Data Product Improvements (directly for your current concern)

Your concern:
- "Insights do not show actual project names reliably."

Likely core issue:
- Project identity is fragmented across providers/log formats (`projectID` present but often not normalized).

Concrete fixes:
1. Add project identity normalization pipeline:
- Canonical key = provider + normalized project slug + optional workspace path hash.
- Keep alias table for renamed projects.

2. Improve extraction heuristics:
- Parse project name from known fields and fallback to path/repo hints.
- Add confidence score per inferred project name.

3. Preserve provenance:
- Store source field map that produced each project name, to debug mismatches quickly.

4. UI safety:
- Show "Unknown project" only when confidence is low, with hover details and quick relabel action.

Suggested file touchpoints:
- `Sources/RunicCore/UsageLedger/UsageLedgerModels.swift`
- `Sources/RunicCore/UsageLedger/UsageLedgerAggregator.swift`
- `Sources/Runic/Core/Stores/UsageStore.swift`
- `Sources/Runic/Views/Menu/ProjectBreakdownMenuView.swift`

## Prioritized Roadmap

### Now (1-2 weeks)

1. Project identity normalization and project-name confidence
2. Reliability Policy Score (fallback/retry/cooldown diagnostics)
3. Routing Advisor v1 (baseline simulation only, no ML training)

Acceptance criteria:
- Insights show stable project names across refresh cycles.
- At least one actionable routing recommendation per active project.
- Policy score visible for each enabled provider.

### Next (2-4 weeks)

1. Eval-Linked Spend Analytics (Promptfoo/OpenAI Evals import)
2. Semantic Cache Opportunity Analyzer (fingerprint-based)
3. OTel GenAI export (file or endpoint sink)

Acceptance criteria:
- Can correlate eval deltas with cost deltas per project and time window.
- Can quantify estimated avoidable spend from repeated prompt patterns.
- External tools can ingest standardized Runic telemetry fields.

### Later (4+ weeks)

1. MCP tool/prompt analytics and heatmaps
2. Advanced routing policies (bandit/learned router plugins)
3. Team-level governance pack (policy presets, compliance reports)

Acceptance criteria:
- MCP-heavy teams can see tool reliability and prompt effectiveness trends.
- Multi-provider routing decisions can be tuned with measurable outcomes.

## Notes on methodology

- Preference was given to primary sources (paper pages, official repos/docs).
- Claims are interpreted conservatively; recommendations emphasize robust baselines first.
- Research intent here is product-directional, not a claim of guaranteed gain in every workload.
