# Security

## Reporting a vulnerability

Report it privately through GitHub: **Security → Report a vulnerability** on this repository. Please don't open a public issue, discussion or pull request for it.

Include what you found, the version (Runic → About, or `runic --version`), and steps to reproduce. Leave out real API keys, cookies, tokens or account files; a redacted sample is enough.

You'll get an acknowledgement within a few days. Fixes ship in a patch release, and the changelog credits you unless you'd rather it didn't.

## Supported versions

Only the latest release gets security fixes. Runic updates itself through Sparkle, and Homebrew and npm follow the same release.

## How releases are protected

- Release builds are signed with a Developer ID certificate and notarized by Apple. Sparkle updates are verified with an EdDSA key.
- Every release has a signed tag, and tags can't be moved or deleted. Published GitHub releases are immutable: their tag and assets can't be changed afterwards.
- `main` changes only through pull requests with passing CI and signed commits.
- The npm package is staged from GitHub Actions through npm trusted publishing (no stored token), with a provenance attestation that links it to the tagged source. It goes live only after the maintainer approves it with two-factor authentication.
