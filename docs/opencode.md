---
summary: "opencode provider data sources: local message JSON log files (BYOK, history-only, no live API)."
read_when:
  - Debugging opencode usage parsing or missing data
  - Updating opencode message log schema or discovery
---

# opencode provider

opencode is BYOK (bring your own key) and history-only. There is no subscription API, no live usage gauge, and no login flow. All usage comes from parsing local JSON message files written by the opencode CLI.

## Data sources + fallback order

1. **Local message log files** — the only data source. No API endpoints, no cookies, no tokens.
   - Root directory: `$OPENCODE_DATA/storage/message/` or `~/.local/share/opencode/storage/message/`
   - File layout: `message/<sessionID>/<messageID>.json` (one JSON file per message)
   - Only `"role": "assistant"` messages with a `tokens` block and `time.created` are parsed.
   - Messages without tokens, or with zero total tokens (input + output + reasoning + cache), are skipped.

2. **No live snapshot** — `providesLiveSnapshot` is `false`. The menu gauge shows nothing for opencode. Usage is visible only in the Analytics timeline and cost/breakdown views.

3. **No fetch strategies** — the `fetchPlan.pipeline` returns an empty strategy array. There is nothing to call an API for.

## Credentials

None. opencode is BYOK — the user configures their own API keys in the opencode CLI config. Runic does not manage any opencode credentials.

## API endpoints

None. Usage is derived entirely from local files.

## Parsing + mapping

### Message JSON schema (OpencodeMessage)
```json
{
  "id": "msg_abc123",
  "sessionID": "sess_xyz",
  "role": "assistant",
  "time": { "created": 1700000000000 },
  "modelID": "anthropic/claude-sonnet-4-6",
  "cost": 0.0123,
  "path": { "cwd": "/Users/sriinnu/projects/my-app" },
  "tokens": {
    "input": 1500,
    "output": 800,
    "reasoning": 0,
    "cache": { "read": 200, "write": 0 }
  }
}
```

### Field mapping to UsageLedgerEntry
- **timestamp:** `time.created` (epoch ms -- `Date`)
- **provider:** `.opencode`
- **sessionID:** `sessionID`
- **projectID / projectName:** `path.cwd` -- `lastPathComponent` (empty or "/" yields `nil`)
- **model:** `modelID`
- **inputTokens:** `tokens.input` (default 0)
- **outputTokens:** `tokens.output + tokens.reasoning` (summed; reasoning is output-side)
- **cacheCreationTokens:** `tokens.cache.write` (default 0)
- **cacheReadTokens:** `tokens.cache.read` (default 0)
- **costUSD:** `cost` (optional)
- **requestID / messageID:** `id` (falls back to filename)
- **source:** `.opencodeLog`

### Token provenance
- `MetricProvenance(confidence: .exact, source: .localLog)` for tokens -- opencode writes exact token counts per message.
- `MetricProvenance(confidence: .providerReported, source: .localLog)` for cost -- when the message includes a cost field.

### Deduplication
Messages are deduplicated by `message.id`. Files that fail to decode as `OpencodeMessage` are silently skipped (not treated as errors -- they may be non-message JSON or half-written files).

### Scan behavior (mirrors Codex/Claude relay)
- **refreshToday (default):** only files with modification time >= start of today (or catch-up window) are opened. Session directories older than the window are pruned whole.
- **rebuildHistory:** all files are scanned regardless of mtime; used for initial seeding and repair.
- **Catch-up:** additive daily scan that covers gaps between the last scan and today, up to `maxAgeDays` (default 3).
- **Busy-file tolerance:** if an active opencode session rewrites a message file mid-scan and parsing fails, the scan continues. Only fails outright if *no* entries could be parsed.
- **Relay / cache:** daily materialized cache at `~/Library/Application Support/Runic/ledger-cache/opencode-daily.json`.

### Model and project breakdowns
- `supportsModelBreakdown: true`
- `supportsProjectAttribution: true`
- `supportsTokenMetrics: true`

## Key files
- `Sources/RunicCore/Providers/Opencode/OpencodeProviderDescriptor.swift` — descriptor (no fetch strategies, no live snapshot, BYOK metadata)
- `Sources/RunicCore/UsageLedger/OpencodeUsageLogSource.swift` — message log discovery, parsing, relay, scan window management
- `Sources/Runic/Providers/Opencode/OpencodeProviderImplementation.swift` — empty implementation (no login flow, no settings fields)
