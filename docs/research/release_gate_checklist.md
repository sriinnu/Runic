# Release Gate Checklist

Last updated: 2026-02-23

Use this checklist before promoting a branch to `main` or cutting a tagged release.

## 1) Branch And Scope Hygiene

- [ ] Feature branch is rebased/merged cleanly against target.
- [ ] No unrelated local changes in working tree.
- [ ] All migration notes are included for settings/schema changes.

## 2) Build Gates

- [ ] `swift build` succeeds.
- [ ] `swift test` succeeds.
- [ ] `./Scripts/compile_and_run.sh` succeeds and relaunches app.
- [ ] Release packaging script (if release cut): `./Scripts/package_app.sh`.

## 3) Runtime Validation Gates

- [ ] Core providers fetch successfully in real environment.
- [ ] Menu bar remains responsive under active refresh load.
- [ ] No repeated credential prompts/regressions after rebuild/relaunch.
- [ ] Error states include actionable next steps for user recovery.

## 4) Data Correctness Gates

- [ ] Provider identity isolation verified (no cross-provider leakage).
- [ ] Ledger summaries (daily/models/projects) validated with test fixtures.
- [ ] Budget/forecast/anomaly outputs are deterministic in tests.
- [ ] New exports/ingestion paths have schema tests and sample fixtures.

## 5) Security And Privacy Gates

- [ ] Secrets are stored in secure platform storage (no plaintext persistence).
- [ ] Logs do not include raw API tokens or auth headers.
- [ ] Export payloads avoid sensitive fields by default.
- [ ] Any new network path has explicit timeout/error handling.

## 6) UX And Accessibility Gates

- [ ] Provider settings spacing and layout render correctly in light/dark modes.
- [ ] Primary workflows are reachable via keyboard and VoiceOver labels.
- [ ] Charts/visual summaries expose textual alternatives.

## 7) Docs And Operations Gates

- [ ] Provider docs and research docs updated for behavior changes.
- [ ] Parity matrix updated for feature/platform status shifts.
- [ ] Open TODO checkboxes updated to reflect shipped items.

## 8) Post-Merge Verification

- [ ] Merge commit or fast-forward push confirmed on remote.
- [ ] Fresh pull + build on clean environment succeeds.
- [ ] Known follow-up tasks filed with owners and priority.
