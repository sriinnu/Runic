#!/usr/bin/env bash
# One-command local ship: bump build, package a signed release bundle, replace
# the single copy in /Applications, relaunch, verify singleton, and render the
# review set from the installed (signed) app so no ad-hoc binary touches the
# keychain. Usage: Scripts/ship.sh [--no-bump] [--no-render]
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
BUMP=1; RENDER=1
for arg in "$@"; do
  case "$arg" in
    --no-bump) BUMP=0 ;;
    --no-render) RENDER=0 ;;
    *) echo "unknown flag: $arg" >&2; exit 2 ;;
  esac
done

# shellcheck disable=SC1091
source version.env
if [[ $BUMP -eq 1 ]]; then
  BUILD_NUMBER=$((BUILD_NUMBER + 1))
  sed -i '' "s/^BUILD_NUMBER=.*/BUILD_NUMBER=${BUILD_NUMBER}/" version.env
fi
echo "==> shipping ${MARKETING_VERSION} (${BUILD_NUMBER})"

Scripts/package_app.sh release
SRC="builds/versions/athena-runic-${MARKETING_VERSION}-${BUILD_NUMBER}/Runic.app"
[[ -d "$SRC" ]] || { echo "package_app.sh produced no bundle at $SRC" >&2; exit 1; }

pkill -x Runic 2>/dev/null || true; sleep 1
rm -rf /Applications/Runic.app
ditto "$SRC" /Applications/Runic.app
rm -rf "$(dirname "$SRC")"
xattr -dr com.apple.quarantine /Applications/Runic.app 2>/dev/null || true
codesign --verify --deep --strict /Applications/Runic.app
open -a /Applications/Runic.app; sleep 3

# Singleton: exactly one bundle, exactly one process.
extra=$(find /Applications "$HOME/Applications" "$HOME/Desktop" "$HOME/Downloads" builds -maxdepth 3 -name "Runic.app" 2>/dev/null | grep -v "^/Applications/Runic.app$" || true)
[[ -z "$extra" ]] || { echo "stray bundles:"; echo "$extra"; exit 1; }
procs=$(pgrep -x Runic | wc -l | tr -d ' ')
[[ "$procs" == "1" ]] || { echo "expected 1 Runic process, found $procs" >&2; exit 1; }
echo "==> /Applications/Runic.app = $(defaults read /Applications/Runic.app/Contents/Info.plist CFBundleShortVersionString) ($(defaults read /Applications/Runic.app/Contents/Info.plist CFBundleVersion)), 1 process"

if [[ $RENDER -eq 1 ]]; then
  OUT="builds/review/${MARKETING_VERSION}-${BUILD_NUMBER}"; mkdir -p "$OUT"
  APP=/Applications/Runic.app/Contents/MacOS/Runic
  RUNIC_SCREENSHOT_RENDER="menubar:$OUT/overview.png" RUNIC_SCREENSHOT_HEIGHT=1100 RUNIC_SCREENSHOT_MENU_PROVIDER=overview "$APP" >/dev/null 2>&1 || true
  RUNIC_SCREENSHOT_RENDER="prefs-providers:$OUT/providers-list.png" RUNIC_SCREENSHOT_HEIGHT=4200 RUNIC_SCREENSHOT_PROVIDERS_LAYOUT=list "$APP" >/dev/null 2>&1 || true
  RUNIC_SCREENSHOT_RENDER="prefs-providers:$OUT/providers-sidebar.png" RUNIC_SCREENSHOT_HEIGHT=1500 RUNIC_SCREENSHOT_PROVIDERS_LAYOUT=sidebar RUNIC_SCREENSHOT_SIDEBAR_PROVIDER=kimi "$APP" >/dev/null 2>&1 || true
  RUNIC_SCREENSHOT_RENDER="prefs-general:$OUT/general.png" RUNIC_SCREENSHOT_HEIGHT=2200 "$APP" >/dev/null 2>&1 || true
  echo "==> review renders in $OUT"; ls "$OUT"
fi
