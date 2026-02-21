#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

source "$ROOT/version.env"
source "$ROOT/Scripts/release-lib.sh"

APPCAST="$ROOT/appcast.xml"
APP_NAME="Runic"
ARTIFACT_PREFIX="Runic-"
BUNDLE_ID="com.steipete.runic"
TAG="v${MARKETING_VERSION}"

require_clean_worktree
ensure_changelog_finalized "$MARKETING_VERSION"
ensure_appcast_monotonic "$APPCAST" "$MARKETING_VERSION" "$BUILD_NUMBER"

CURRENT_BRANCH=$(git branch --show-current)
if [[ "$CURRENT_BRANCH" != "main" ]]; then
  err "Release must be run from branch 'main' (current: $CURRENT_BRANCH)"
fi

swiftformat Sources Tests >/dev/null
swiftlint --strict
swift test

# Note: run this script in the foreground; do not background it so it waits to completion.
"$ROOT/Scripts/sign-and-notarize.sh"

KEY_FILE=$(clean_key "$SPARKLE_PRIVATE_KEY_FILE")
trap 'rm -f "$KEY_FILE"' EXIT

probe_sparkle_key "$KEY_FILE"

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

git tag "$TAG"
git push origin "$TAG"

gh release create "$TAG" ${APP_NAME}-${MARKETING_VERSION}.zip ${APP_NAME}-${MARKETING_VERSION}.dSYM.zip \
  --title "${APP_NAME} ${MARKETING_VERSION}" \
  --notes-file "$NOTES_FILE"

SPARKLE_PRIVATE_KEY_FILE="$KEY_FILE" \
  "$ROOT/Scripts/make_appcast.sh" \
  "${APP_NAME}-${MARKETING_VERSION}.zip" \
  "https://raw.githubusercontent.com/steipete/Runic/main/appcast.xml"

verify_appcast_entry "$APPCAST" "$MARKETING_VERSION" "$KEY_FILE"

git add "$APPCAST"
git commit -m "docs: update appcast for ${MARKETING_VERSION}"
git push origin main

if [[ "${RUN_SPARKLE_UPDATE_TEST:-0}" == "1" ]]; then
  PREV_TAG=$(git tag --sort=-v:refname | sed -n '2p')
  [[ -z "$PREV_TAG" ]] && err "RUN_SPARKLE_UPDATE_TEST=1 set but no previous tag found"
  "$ROOT/Scripts/test_live_update.sh" "$PREV_TAG" "v${MARKETING_VERSION}"
fi

check_assets "$TAG" "$ARTIFACT_PREFIX"

echo "Release ${MARKETING_VERSION} complete."
