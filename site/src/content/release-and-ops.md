---
title: "Release and ops"
---

# Release and ops

How a Runic release ships. It is one script, `Scripts/release.sh`, run from a clean `main`.

## The flow

1. **Preflight**: working tree clean, the changelog has a dated section for the version, the appcast build number is strictly higher than the last release, `package.json`, `version.env` and `RunicVersion.swift` agree.
2. **Gates**: `swiftformat --lint`, `swiftlint --strict` and the full test suite. Any failure aborts before anything is built for publishing.
3. **Build, sign, notarize**: a universal release build, Developer ID signing, Apple notarization. The script refuses to package a binary older than its sources, and fails if the dSYM and binary UUIDs differ.
4. **Tag and publish**: a signed annotated tag `vX.Y.Z`, then a draft GitHub release that gets `Runic-X.Y.Z.zip`, the dSYM and the delta updates before it is published. Published releases are immutable: their tag and files can't change afterwards.
5. **Appcast**: Sparkle's appcast is regenerated and signed. Because `main` requires pull requests, the script opens a PR from `sriinnu/appcast-X.Y.Z`; merging it makes the update live.
6. **Homebrew**: the cask in `sriinnu/homebrew-tap` is bumped with the zip's sha256 and merged.
7. **npm**: publishing the release stages `@sriinnu/runic` from GitHub Actions through npm trusted publishing, with provenance. It goes live once the maintainer approves it with a security key.

## After a release

- Verify the live appcast, that each asset URL answers 200, that the cask sha equals `shasum -a 256` of the zip, and `git tag -v`.
- Compare `dwarfdump --uuid` of the zip's binary and a fresh build, and grep the zip's binary for a string only the new code has. A release once shipped the previous build's binary; this is the check that catches it.
- Install the notarized zip to `/Applications` and confirm `spctl` reports *Notarized Developer ID* and a single running instance.
- Local `main` now has the appcast commit and diverges from the squash: `git reset --hard origin/main`.

## CI

One `macos-26` job. GitHub often cancels it after about 15 minutes with "job was not acquired by Runner" when arm64 capacity is short. That is not a build failure; re-run it. SwiftFormat and SwiftLint are pinned in the workflow to the versions the release gate uses locally, because the latest SwiftFormat flags files the pinned one accepts.

## Updating this wiki

The wiki repo only exists after a page has been saved once in the web UI. Push with the SSH remote, `git@github.com:sriinnu/Runic.wiki.git`; the HTTPS remote fails authentication. Images live in `images/` and are served from `raw.githubusercontent.com/wiki/sriinnu/Runic/images/`.
