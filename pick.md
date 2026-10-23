# Security pickup

## Current state (2026-10-23)

- Branch: `sriinnu/appcast-2.13.3`, clean at `e51d0e0` before this handoff file.
- Open PR to `main`: [#224](https://github.com/sriinnu/Runic/pull/224). Do not call it merged or released.
- Commits: `18f40cb` (local telemetry, sensitive files, plugins, sync), `e51d0e0` (provider redirect boundary).
- The user's goal is defense through every trust boundary, in the spirit of Lakshmana Rekha. Do not claim the app is hackproof based on this PR.

## Completed and verified

- Local OTLP collector binds to loopback, requires a fresh bearer token for ingestion and event streams, checks Host and Origin, enforces JSON/size limits, and restricts sensitive output permissions.
- Custom provider and account diagnostic files are owner-only. Custom provider URLs require HTTPS without userinfo and reject redirects.
- Discovered MCP packages start disabled; enabled plugin processes receive an environment allowlist rather than inherited provider tokens.
- Team-sync encryption fails if its Keychain key cannot be read or persisted; decryption never generates a replacement key.
- Provider API, OAuth, browser-cookie, and local model requests now reject redirects. The Antigravity loopback CSRF request rejects redirects too.
- `swift test --quiet`: 776 Runic tests and 3 platform tests passed. Focused redirect tests passed. Strict SwiftLint on changed Swift files and `git diff --check` passed.
- Built CLI smoke check using a temporary ledger: no token returned 403, foreign Origin returned 403, authorized invalid payload returned 422. The token was not saved in the test output.
- PR #224's Cloudflare and macOS lint/build/test checks passed on `e51d0e0`.

- Redirect follow-up (2.13.4): an unauthenticated sweep of every provider URL found two fetchers that detected sign-out by following the login bounce (SiliconFlow console, Ollama Cloud web). They now read the rejected redirect's `Location` via `ProviderRequestSession.redirectTarget(of:)`. MiniMax's coding-plan page moved to `/console/plan`. Remaining 3xx hits are browser-only dashboard links.

## Still open

1. **MCP execution boundary:** An explicitly enabled plugin is a native executable with the user's filesystem and network access. Environment filtering and consent do not confine it. Review `Sources/RunicCore/RunicMCPPlugins.swift` and `Sources/RunicCLI/RunicMCPCommand.swift`; design an enforceable capability or isolation boundary before promising untrusted plugins are safe. Account for package changes after enablement.
2. **Team sync design:** The encryption key is local to one Keychain. Cross-device/user key distribution, recovery, and actual sync behavior were not validated. Trace whether this code is active before changing its contract; see `Sources/RunicCore/Sync/TeamSyncEncryption.swift` and `TeamMembershipRecord.swift`.
3. **Installed and live acceptance:** Source tests and a CLI smoke check are not proof for the installed macOS app or live provider sessions. Validate those separately with sanitized artifacts; do not expose real tokens, cookies, or account files.
4. **Broader review:** The last pass focused on telemetry, sensitive storage, provider redirects, plugins, and sync key handling. Continue through update/release, browser session, subprocess, logging, and dependency/CI boundaries. Record specific findings with reachable paths and tests; avoid blanket security claims.

## Next agent

Start with the MCP execution boundary and trace actual call sites and user consent. Pick one enforceable design, implement and test it if feasible, and state remaining limits. Check PR #224 and branch state before editing. Keep the PR description and verification current. Do not merge or release without the user's direction.
