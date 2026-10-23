# Agents

Rules for any coding agent working in this repo. Release mechanics live in `docs/releasing.md`; this file covers the guarantees an agent must not break.

## Git

- `main` takes changes only through pull requests with passing CI ("Lint, build and test (macOS)") and signed commits. Nothing bypasses it. Work on a branch, open a PR, squash-merge.
- Sign every commit and tag. Never pass `-c commit.gpgsign=false` or create an unsigned tag.
- Never force-push, delete or move a tag or a branch you didn't create without the maintainer's explicit go.

## Releases

- `Scripts/release.sh` is the only release path, run from a clean `main`. A release bumps `version.env` (`MARKETING_VERSION` and `BUILD_NUMBER`), `Sources/RunicCore/RunicVersion.swift`, `package.json` and the dated `CHANGELOG.md` heading in one commit.
- Every shipped version has a signed annotated tag `vX.Y.Z`. Tags matching `v*` can't be updated or deleted.
- GitHub releases are **immutable once published**: their tag and assets are frozen. `release.sh` creates the release as a draft, attaches the zip, dSYM and deltas, checks them, and publishes last. Never plan to upload to a published release; fix it in a new patch release.
- After `release.sh`: merge the appcast PR it opens (CI must pass first), confirm the Homebrew tap PR merged, and verify the live appcast and asset URLs.

## npm (`@sriinnu/runic`)

- Publishing the GitHub release runs `.github/workflows/publish-npm.yml`, which **stages** the package with `npm stage publish --provenance` through npm trusted publishing (OIDC, no token anywhere).
- A staged version goes live only when the maintainer approves it with their security key: npmjs.com → `@sriinnu/runic`, or `npm stage list @sriinnu/runic` and `npm stage approve <id>`. **After every release, remind the maintainer to approve.** An agent can't and shouldn't approve.
- The trusted publisher is configured once on npmjs.com (repository `sriinnu/Runic`, case-sensitive; workflow `publish-npm.yml`; environment `npm`; staging only). Don't recreate a token or add an `NPM_TOKEN` secret.

## GitHub Actions

- Only GitHub-owned actions are allowed, pinned to a full commit SHA with the version in a comment. Dependabot keeps the pins current.
- Downloaded tools are checked against a pinned sha256 before they run.
- Workflows default to read-only permissions; grant more per job, and only what that job needs.

## Secrets

- Never print, log or commit credentials: API keys, cookies, tokens, `~/.config/runic/local.env`, the Sparkle key, App Store Connect keys. Filter release logs for `APP_STORE_CONNECT|SPARKLE_PRIVATE|PRIVATE KEY` before showing them.
- Report vulnerabilities through private vulnerability reporting (see `SECURITY.md`), never in a public issue.
