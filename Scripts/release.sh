#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

source "$ROOT/version.env"
source "$ROOT/Scripts/release-lib.sh"

APPCAST="$ROOT/appcast.xml"
APP_NAME="Runic"
ARTIFACT_PREFIX="Runic-"
BUNDLE_ID="com.sriinnu.athena.runic"
TAG="v${MARKETING_VERSION}"

require_clean_worktree
ensure_changelog_finalized "$MARKETING_VERSION"
ensure_package_version "$MARKETING_VERSION"
ensure_cli_version "$MARKETING_VERSION"
ensure_appcast_monotonic "$APPCAST" "$MARKETING_VERSION" "$BUILD_NUMBER"

CURRENT_BRANCH=$(git branch --show-current)
if [[ "$CURRENT_BRANCH" != "main" ]]; then
  err "Release must be run from branch 'main' (current: $CURRENT_BRANCH)"
fi

KEY_FILE=$(clean_key "${SPARKLE_PRIVATE_KEY_FILE:-}")
trap 'rm -f "$KEY_FILE"' EXIT
probe_sparkle_key "$KEY_FILE"

swiftformat Sources Tests --lint
swiftlint --strict
swift test

# Note: run this script in the foreground; do not background it so it waits to completion.
"$ROOT/Scripts/sign-and-notarize.sh"

clear_sparkle_caches "$BUNDLE_ID"

NOTES_FILE=$(mktemp /tmp/runic-notes.XXXXXX.md)
extract_notes_from_changelog "$MARKETING_VERSION" "$NOTES_FILE"
trap 'rm -f "$KEY_FILE" "$NOTES_FILE"' EXIT

if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  err "Tag already exists locally: $TAG"
fi
if git ls-remote --tags origin "$TAG" | grep -q "refs/tags/$TAG$"; then
  err "Tag already exists on origin: $TAG"
fi

# Release tags are always signed, whatever tag.gpgSign says, and verified
# before they leave the machine.
git tag --sign "$TAG" --message "${APP_NAME} ${MARKETING_VERSION}"
git tag --verify "$TAG" >/dev/null 2>&1 || err "Tag $TAG has no valid signature"
git push origin "$TAG"

# Releases are immutable once published (repo setting): the tag and assets are
# frozen. So the release starts as a draft, gets every asset (deltas included),
# and is published last.
gh release create "$TAG" ${APP_NAME}-${MARKETING_VERSION}.zip ${APP_NAME}-${MARKETING_VERSION}.dSYM.zip \
  --draft \
  --title "${APP_NAME} ${MARKETING_VERSION}" \
  --notes-file "$NOTES_FILE"

SPARKLE_PRIVATE_KEY_FILE="$KEY_FILE" \
  "$ROOT/Scripts/make_appcast.sh" \
  "${APP_NAME}-${MARKETING_VERSION}.zip" \
  "https://raw.githubusercontent.com/sriinnu/Runic/main/appcast.xml"

verify_appcast_entry "$APPCAST" "$MARKETING_VERSION" "$KEY_FILE"

# The appcast now points at deltas that only exist locally; attach them to the
# release before anyone reads it.
upload_deltas "$TAG" "$APP_NAME"
check_appcast_deltas "$APPCAST" "$TAG" "$BUILD_NUMBER"
check_assets "$TAG" "$ARTIFACT_PREFIX"

# Publishing freezes the release and fires .github/workflows/publish-npm.yml,
# which stages the npm package.
gh release edit "$TAG" --draft=false

git add "$APPCAST"
git commit -m "docs: update appcast for ${MARKETING_VERSION}"
push_appcast_commit "$MARKETING_VERSION"

if [[ "${RUN_SPARKLE_UPDATE_TEST:-0}" == "1" ]]; then
  PREV_TAG=$(git tag --sort=-v:refname | sed -n '2p')
  [[ -z "$PREV_TAG" ]] && err "RUN_SPARKLE_UPDATE_TEST=1 set but no previous tag found"
  "$ROOT/Scripts/test_live_update.sh" "$PREV_TAG" "v${MARKETING_VERSION}"
fi

# Bump the Homebrew cask in the tap from the just-published artifact. Best-effort:
# the tag and release assets already exist, so a tap hiccup must not hide them.
# On failure, inspect the tap PR and rerun Scripts/update-homebrew-cask.sh if safe.
"$ROOT/Scripts/update-homebrew-cask.sh" || \
  echo "WARN: Homebrew cask bump failed; the release IS published. Re-run Scripts/update-homebrew-cask.sh." >&2

# npm is not published from here: publishing the GitHub release above runs
# .github/workflows/publish-npm.yml, which stages the package with provenance
# (npm trusted publishing, no token). It goes live after approval with 2FA:
# npmjs.com → @sriinnu/runic, or `npm stage list @sriinnu/runic` + `npm stage approve <id>`.

echo "Release published. Merge the appcast PR, approve the staged npm version, and verify the live update feed to complete ${MARKETING_VERSION}."
