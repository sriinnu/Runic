# Security

## Reporting a vulnerability

Report it privately through GitHub: **Security → Report a vulnerability** on this repository. Please don't open a public issue, discussion or pull request for it.

Include what you found, the version (Runic → About, or `runic --version`), and steps to reproduce. Leave out real API keys, cookies, tokens or account files; a redacted sample is enough.

You'll get an acknowledgement within a few days. Fixes ship in a patch release, and the changelog credits you unless you'd rather it didn't.

## Supported versions

Only the latest release gets security fixes. Runic updates itself through Sparkle, and Homebrew and npm follow the same release.

## How releases are protected

- Release builds are signed with a Developer ID certificate and notarized by Apple. Sparkle updates are verified with an EdDSA key.
- Release tags are signed and can't be moved or deleted. `main` changes only through pull requests.
- The npm package is published from GitHub Actions with a provenance attestation that links it to the tagged source.
