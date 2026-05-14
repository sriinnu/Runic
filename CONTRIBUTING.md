# Contributing To Runic

Thanks for helping improve Runic. This repo is currently SwiftPM-first and macOS-focused.

## Development Setup

Requirements:

- macOS 14+
- Xcode 26+ command line tools
- Swift 6.2+

Build and test:

```bash
swift build
swift test
```

Run a local app build:

```bash
./Scripts/compile_and_run.sh --wait
```

Package a release-style app bundle:

```bash
./Scripts/package_app.sh release
```

## Repo Map

- `Sources/RunicCore`: provider fetchers, parsers, usage ledger, status probes, pricing, sync models.
- `Sources/Runic`: macOS app, menu bar controller, preferences, settings, icon rendering, SwiftUI views.
- `Sources/RunicCLI`: bundled `runic` command.
- `Sources/RunicWidget`: WidgetKit extension.
- `Tests/RunicTests`: macOS app/core tests.
- `TestsLinux`: Linux-compatible core/CLI tests.

Read `SKILL.md` before making larger changes.

## Code Standards

- Prefer existing patterns and helper APIs.
- Keep provider identity siloed: do not mix emails, org IDs, plans, tokens, cookies, or login methods across providers.
- Store user-entered secrets in macOS Keychain.
- Never log tokens, cookies, auth headers, passwords, account emails, org IDs, dashboard HTML, or local private-key paths.
- Keep UI work visually verified in `/Applications/Runic.app` when possible.
- Add focused tests for parser, exporter, provider, and usage math changes.

## Provider Changes

1. Read `docs/provider.md` and `docs/providers.md`.
2. Update the provider implementation under `Sources/RunicCore/Providers/<Provider>/`.
3. Add app settings through provider descriptors under `Sources/Runic/Providers/<Provider>/`.
4. Add sanitized tests and fixtures.
5. Update user-facing docs only when behavior changes.

## Pull Requests

Before opening a PR:

```bash
swift build
swift test
git diff --check
```

Also scan staged changes for secrets or personal data:

```bash
git diff --cached | rg -n "api.?key|token|secret|password|Bearer |cookie|@|/Users/"
```

Checklist:

- Code builds.
- Relevant tests pass.
- UI changes include screenshots when useful.
- README/docs are updated for user-visible behavior.
- No local paths, generated reports, private auth internals, secrets, or personal account details are committed.

## Security Reports

Do not open public issues for vulnerabilities or credential leaks. Use a private GitHub security advisory or contact the maintainer privately through GitHub.
