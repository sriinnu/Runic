# Concrete TODO (Execution List)

Branch: `feat/research-uiux-core-next`
Last updated: 2026-02-22

## Sprint Goal

Ship operator-grade insights in small, verifiable slices without destabilizing current menu behavior.

## P0 (Now)

- [x] Create research-backed roadmap document  
  File: `docs/research/feature_uiux_roadmap_2026-02-22.md`
- [x] Add probabilistic month-end forecast confidence bands (`p50/p80/p95`) to core forecast model
- [x] Render confidence bands in menu Insights line when available
- [x] Add/extend tests for confidence-band generation and menu formatting

## P1 (Next)

- [x] Anomaly explainability v2
  - [x] Add explanation object for why severity was chosen
  - [x] Surface primary and secondary contributing factors in menu copy
- [x] Policy engine foundation (warn / soft-limit / hard-stop)
  - [x] Core model in `RunicCore`
  - [x] Deterministic decision tests

## P2 (After P1)

- [x] OTel GenAI ingestion adapter (feature-flagged)
- [x] Team showback/chargeback summary exports
- [x] Cross-platform parity matrix and release gate checklist

## Immediate Work Plan (This Branch)

1. Extend `UsageLedgerSpendForecast` with optional confidence outputs.
2. Compute quantiles from observed daily cost distribution in `UsageLedgerAggregator`.
3. Preserve these fields in `UsageStore` projection-resolution path.
4. Update menu forecast rendering to show `p50/p80/p95` when available.
5. Validate with targeted tests and full rebuild script.

## Definition Of Done (Current Slice)

- Forecast model compiles with backward-compatible optional fields.
- Existing forecast tests pass.
- New quantile test passes.
- Menu model test confirms confidence string appears.
- `./Scripts/compile_and_run.sh` completes successfully.
