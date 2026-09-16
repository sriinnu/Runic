#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Runic"
ROOT=$(cd "$(dirname "$0")/.." && pwd)
for LOCAL_ENV in "${HOME}/.config/runic/local.env" "${ROOT}/.runic.local.env"; do
  if [[ -f "$LOCAL_ENV" ]]; then
    # shellcheck disable=SC1090
    source "$LOCAL_ENV"
    break
  fi
done
APP_IDENTITY="${APP_IDENTITY:-Developer ID Application: YOUR_NAME (TEAMID)}"
APP_BUNDLE="${ROOT}/builds/latest/${APP_NAME}.app"
source "$ROOT/version.env"
ZIP_NAME="${APP_NAME}-${MARKETING_VERSION}.zip"
DSYM_ZIP="${APP_NAME}-${MARKETING_VERSION}.dSYM.zip"

if [[ -z "${APP_STORE_CONNECT_API_KEY_P8:-}" || -z "${APP_STORE_CONNECT_KEY_ID:-}" || -z "${APP_STORE_CONNECT_ISSUER_ID:-}" ]]; then
  echo "Missing APP_STORE_CONNECT_* env vars (API key, key id, issuer id)." >&2
  exit 1
fi
if [[ -z "${SPARKLE_PRIVATE_KEY_FILE:-}" ]]; then
  echo "SPARKLE_PRIVATE_KEY_FILE is required for release signing/verification." >&2
  exit 1
fi
if [[ ! -f "$SPARKLE_PRIVATE_KEY_FILE" ]]; then
  echo "Sparkle key file not found: $SPARKLE_PRIVATE_KEY_FILE" >&2
  exit 1
fi
key_lines=$(grep -v '^[[:space:]]*#' "$SPARKLE_PRIVATE_KEY_FILE" | sed '/^[[:space:]]*$/d')
if [[ $(printf "%s\n" "$key_lines" | wc -l) -ne 1 ]]; then
  echo "Sparkle key file must contain exactly one base64 line (no comments/blank lines)." >&2
  exit 1
fi

API_KEY_FILE=$(mktemp "${TMPDIR:-/tmp}/runic-api-key.XXXXXX")
NOTARIZE_ZIP=$(mktemp "${TMPDIR:-/tmp}/${APP_NAME}Notarize.XXXXXX")
chmod 600 "$API_KEY_FILE"
echo "$APP_STORE_CONNECT_API_KEY_P8" | sed 's/\\n/\n/g' > "$API_KEY_FILE"
trap 'rm -f "$API_KEY_FILE" "$NOTARIZE_ZIP"' EXIT

# Allow building a universal binary if ARCHES is provided; default to universal (arm64 + x86_64).
ARCHES_VALUE=${ARCHES:-"arm64 x86_64"}
ARCH_LIST=( ${ARCHES_VALUE} )
ARCH_FLAGS=()
for ARCH in "${ARCH_LIST[@]}"; do
  ARCH_FLAGS+=(--arch "$ARCH")
done
# package_app.sh builds every arch in one invocation and copies from SwiftPM's
# reported output directory (see the note there on the stale per-arch dirs).
ARCHES="${ARCHES_VALUE}" ./Scripts/package_app.sh release
BIN_DIR="$(swift build -c release "${ARCH_FLAGS[@]}" --show-bin-path)"

ENTITLEMENTS_DIR="$ROOT/.build/entitlements"
APP_ENTITLEMENTS="${ENTITLEMENTS_DIR}/Runic.entitlements"
WIDGET_ENTITLEMENTS="${ENTITLEMENTS_DIR}/RunicWidget.entitlements"

echo "Signing with $APP_IDENTITY"
if [[ -f "$APP_BUNDLE/Contents/Helpers/RunicCLI" ]]; then
  codesign --force --timestamp --options runtime --sign "$APP_IDENTITY" \
    "$APP_BUNDLE/Contents/Helpers/RunicCLI"
fi
if [[ -f "$APP_BUNDLE/Contents/Helpers/RunicClaudeWatchdog" ]]; then
  codesign --force --timestamp --options runtime --sign "$APP_IDENTITY" \
    "$APP_BUNDLE/Contents/Helpers/RunicClaudeWatchdog"
fi
if [[ -d "$APP_BUNDLE/Contents/PlugIns/RunicWidget.appex" ]]; then
  codesign --force --timestamp --options runtime --sign "$APP_IDENTITY" \
    --entitlements "$WIDGET_ENTITLEMENTS" \
    "$APP_BUNDLE/Contents/PlugIns/RunicWidget.appex/Contents/MacOS/RunicWidget"
  codesign --force --timestamp --options runtime --sign "$APP_IDENTITY" \
    --entitlements "$WIDGET_ENTITLEMENTS" \
    "$APP_BUNDLE/Contents/PlugIns/RunicWidget.appex"
fi
codesign --force --timestamp --options runtime --sign "$APP_IDENTITY" \
  --entitlements "$APP_ENTITLEMENTS" \
  "$APP_BUNDLE"

DITTO_BIN=${DITTO_BIN:-/usr/bin/ditto}
"$DITTO_BIN" --norsrc -c -k --keepParent "$APP_BUNDLE" "$NOTARIZE_ZIP"

echo "Submitting for notarization"
xcrun notarytool submit "$NOTARIZE_ZIP" \
  --key "$API_KEY_FILE" \
  --key-id "$APP_STORE_CONNECT_KEY_ID" \
  --issuer "$APP_STORE_CONNECT_ISSUER_ID" \
  --wait

echo "Stapling ticket"
xcrun stapler staple "$APP_BUNDLE"

# Strip any extended attributes that would create AppleDouble files when zipping
xattr -cr "$APP_BUNDLE"
find "$APP_BUNDLE" -name '._*' -delete

"$DITTO_BIN" --norsrc -c -k --keepParent "$APP_BUNDLE" "$ZIP_NAME"

spctl -a -t exec -vv "$APP_BUNDLE"
stapler validate "$APP_BUNDLE"

echo "Packaging dSYM"
DSYM_PATH="${BIN_DIR}/${APP_NAME}.dSYM"
if [[ ! -d "$DSYM_PATH" ]]; then
  echo "Missing dSYM at $DSYM_PATH" >&2
  exit 1
fi
# The dSYM and the signed binary must come from the same link: identical UUIDs
# for every arch. A mismatch means the bundle holds a binary from another build.
APP_UUIDS=$(dwarfdump --uuid "$APP_BUNDLE/Contents/MacOS/${APP_NAME}" | awk '{print $2, $3}' | sort)
DSYM_UUIDS=$(dwarfdump --uuid "$DSYM_PATH" | awk '{print $2, $3}' | sort)
if [[ "$APP_UUIDS" != "$DSYM_UUIDS" ]]; then
  echo "ERROR: app binary and dSYM UUIDs differ; the bundle is not from this build." >&2
  echo "app:  $APP_UUIDS" >&2
  echo "dSYM: $DSYM_UUIDS" >&2
  exit 1
fi
"$DITTO_BIN" --norsrc -c -k --keepParent "$DSYM_PATH" "$DSYM_ZIP"

echo "Done: $ZIP_NAME"
