# Integrations

Runic's integrations are local-first. The Preferences > Sync > Integrations pane is a control center for surfaces that already exist in the app rather than a promise that Runic is running a background network service.

## Available today

- **CLI JSON access:** copy `runic usage --format json --pretty` for local scripts, CI, and dashboards.
- **OpenTelemetry GenAI ledger:** view, reveal, and copy the default sanitized JSONL collector path. Add extra JSON/JSONL files or folders through Additional usage log paths.
- **MCP profiles:** save localhost bridge profiles and copy `mcp connect localhost:<port>` commands for external MCP processes that users run themselves.
- **Alert webhooks:** save a default webhook URL, choose Slack/Discord/generic test payloads, and send a test request. New alert rules can reuse the saved default URL.
- **GitHub commit correlation:** validate a repository path and copy `runic insights --with-commits --git-directory "<repo>/.git" --json --pretty`.
- **Kosha registry:** detect and reveal `~/.kosha/registry.json` for local model context metadata.
- **Provider API keys:** link users back to provider documentation and Preferences > Providers, where keys live in macOS Keychain.

## Feature research

- **Runic MCP bridge:** build a small first-party MCP server over the existing `UsageLedger`, provider status, and context-window metadata.
- **Local HTTP API:** expose the same read-only CLI JSON payloads over a localhost-only server with explicit enablement and Keychain-backed token auth.
- **Webhook dispatch history:** record delivery attempts for alert webhooks so failures are visible after the transient test result disappears.
- **GitHub project mapping:** reuse `GitHubIntegration` to enrich project summaries in the app UI, not only `runic insights --with-commits`.
- **Kosha sync health:** surface registry age, stale status, and provider coverage next to the current path detection.
