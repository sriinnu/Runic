#!/usr/bin/env bash
# Bump the Homebrew cask in the tap to the just-released version.
# Run by release.sh after the GitHub release (with the zip) is published — it
# computes sha256 from the local release artifact (identical bytes to the upload)
# and pushes the updated cask using your existing gh/git auth. No extra secret.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
# shellcheck disable=SC1091
source "$ROOT/version.env"

APP_NAME="Runic"
TAP_REPO="${RUNIC_HOMEBREW_TAP:-sriinnu/homebrew-tap}"
CASK_RELPATH="Casks/runic.rb"
ZIP="$ROOT/${APP_NAME}-${MARKETING_VERSION}.zip"

if [[ ! -f "$ZIP" ]]; then
  echo "Homebrew cask: release zip not found ($ZIP). Run after the release is built." >&2
  exit 1
fi

SHA=$(shasum -a 256 "$ZIP" | awk '{print $1}')
echo "Homebrew cask: ${APP_NAME} ${MARKETING_VERSION} (sha256 ${SHA})"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
gh repo clone "$TAP_REPO" "$WORK/tap" -- --depth 1 --quiet
CASK="$WORK/tap/$CASK_RELPATH"
if [[ ! -f "$CASK" ]]; then
  echo "Cask not found in tap: $TAP_REPO/$CASK_RELPATH" >&2
  exit 1
fi

if grep -q "version \"${MARKETING_VERSION}\"" "$CASK" && grep -q "sha256 \"${SHA}\"" "$CASK"; then
  echo "Homebrew cask already at ${MARKETING_VERSION}; nothing to do."
  exit 0
fi

# BSD sed (macOS release host). Replace only the version/sha256 stanza lines.
sed -i '' -E "s/^([[:space:]]*version )\"[^\"]*\"/\1\"${MARKETING_VERSION}\"/" "$CASK"
sed -i '' -E "s/^([[:space:]]*sha256 )\"[^\"]*\"/\1\"${SHA}\"/" "$CASK"

# Sanity: both values landed.
grep -q "version \"${MARKETING_VERSION}\"" "$CASK" || { echo "Failed to set cask version" >&2; exit 1; }
grep -q "sha256 \"${SHA}\"" "$CASK" || { echo "Failed to set cask sha256" >&2; exit 1; }

cd "$WORK/tap"
# The tap's main branch only accepts changes through pull requests (ruleset,
# 2026-09), so land the bump as a branch + PR and merge it. The clone runs
# with commit signing off: the tap has no signing requirement and the global
# config points at a hardware key that can't be touched headless.
BRANCH="runic-${MARKETING_VERSION}"
git checkout -q -b "$BRANCH"
git add "$CASK_RELPATH"
git -c commit.gpgsign=false commit -m "runic ${MARKETING_VERSION}" --quiet
git push -q -u origin "$BRANCH"
PR_URL=$(gh pr create --title "runic ${MARKETING_VERSION}" \
  --body "Bump cask to ${MARKETING_VERSION} (sha256 ${SHA}). Opened by Scripts/update-homebrew-cask.sh." 2>&1 | tail -1)
echo "Homebrew cask PR: ${PR_URL}"
if gh pr merge "$BRANCH" --squash --admin >/dev/null 2>&1 || gh pr merge "$BRANCH" --squash >/dev/null 2>&1; then
  echo "Homebrew cask updated: ${TAP_REPO} -> runic ${MARKETING_VERSION}"
else
  echo "Homebrew cask PR could not be merged automatically; merge it by hand: ${PR_URL}" >&2
fi
