#!/usr/bin/env bash
set -euo pipefail

RELEASE_LIB_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

err() {
  echo "ERROR: $*" >&2
  exit 1
}

require_command() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || err "Required command not found in PATH: $cmd"
}

require_clean_worktree() {
  local status
  status=$(git status --porcelain)
  if [[ -n "$status" ]]; then
    echo "$status" >&2
    err "Git working tree must be clean before releasing."
  fi
}

ensure_changelog_finalized() {
  local version="$1"
  local changelog="${2:-CHANGELOG.md}"

  [[ -f "$changelog" ]] || err "CHANGELOG not found: $changelog"

  local first_heading
  first_heading=$(awk '/^## /{print; exit}' "$changelog")
  [[ -n "$first_heading" ]] || err "Could not find a release heading in $changelog"

  if [[ "$first_heading" =~ [Uu]nreleased ]]; then
    err "Top changelog section is still Unreleased. Finalize CHANGELOG.md for $version first."
  fi
  if [[ "$first_heading" != *"$version"* ]]; then
    err "Top changelog section must match MARKETING_VERSION ($version). Found: $first_heading"
  fi
}

ensure_appcast_monotonic() {
  local appcast="$1"
  local version="$2"
  local build_number="$3"

  [[ -f "$appcast" ]] || err "Appcast not found: $appcast"
  [[ "$build_number" =~ ^[0-9]+$ ]] || err "BUILD_NUMBER must be numeric: $build_number"

  python3 - "$appcast" "$version" "$build_number" <<'PY'
import sys
import xml.etree.ElementTree as ET

appcast = sys.argv[1]
target_version = sys.argv[2]
target_build = int(sys.argv[3])
ns = {"sparkle": "http://www.andymatuschak.org/xml-namespaces/sparkle"}

tree = ET.parse(appcast)
root = tree.getroot()

max_build = -1
for item in root.findall("./channel/item"):
    short_version = item.findtext("sparkle:shortVersionString", default="", namespaces=ns).strip()
    if short_version == target_version:
        raise SystemExit(f"Appcast already contains version {target_version}")

    build_text = item.findtext("sparkle:version", default="", namespaces=ns).strip()
    if not build_text:
        continue
    try:
        build = int(build_text)
    except ValueError:
        continue
    max_build = max(max_build, build)

if max_build >= 0 and target_build <= max_build:
    raise SystemExit(
        f"BUILD_NUMBER must be greater than latest appcast build ({max_build}); got {target_build}"
    )
PY
}

clean_key() {
  local key_file="$1"
  [[ -f "$key_file" ]] || err "Sparkle key file not found: $key_file"

  local key_lines
  key_lines=$(grep -v '^[[:space:]]*#' "$key_file" | sed '/^[[:space:]]*$/d')
  local line_count
  line_count=$(printf "%s\n" "$key_lines" | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')
  [[ "$line_count" == "1" ]] || err "Sparkle key file must contain exactly one base64 line."

  local tmp
  tmp=$(mktemp /tmp/runic-sparkle-key.XXXXXX)
  printf "%s" "$key_lines" > "$tmp"
  echo "$tmp"
}

probe_sparkle_key() {
  local key_file="$1"
  require_command sign_update

  local probe_file
  probe_file=$(mktemp /tmp/runic-sparkle-probe.XXXXXX)

  printf "runic-sparkle-probe" > "$probe_file"
  local signature
  signature=$(sign_update "$probe_file" --ed-key-file "$key_file" 2>/dev/null || true)
  rm -f "$probe_file"
  [[ -n "$signature" ]] || err "Failed to sign with SPARKLE_PRIVATE_KEY_FILE. Check key format."
}

clear_sparkle_caches() {
  local bundle_id="$1"
  local paths=(
    "$HOME/Library/Caches/${bundle_id}.Sparkle"
    "$HOME/Library/Application Support/${bundle_id}/Sparkle"
    "$HOME/Library/Application Support/Sparkle"
  )

  for path in "${paths[@]}"; do
    [[ -e "$path" ]] || continue
    rm -rf "$path"
  done
}

extract_notes_from_changelog() {
  local version="$1"
  local output="$2"
  local changelog="${3:-CHANGELOG.md}"

  [[ -f "$changelog" ]] || err "CHANGELOG not found: $changelog"

  python3 - "$changelog" "$version" "$output" <<'PY'
import re
import sys

changelog_path, version, output_path = sys.argv[1], sys.argv[2], sys.argv[3]
pattern = re.compile(rf"^##\s*\[?{re.escape(version)}\]?(?:\s|$|-)")

with open(changelog_path, "r", encoding="utf-8") as f:
    lines = f.read().splitlines()

start = None
for i, line in enumerate(lines):
    if pattern.search(line):
        start = i + 1
        break

if start is None:
    raise SystemExit(f"Could not find changelog section for {version}")

end = len(lines)
for i in range(start, len(lines)):
    if lines[i].startswith("## "):
        end = i
        break

section = lines[start:end]
while section and section[0].strip() == "":
    section.pop(0)
while section and section[-1].strip() == "":
    section.pop()

if not section:
    raise SystemExit(f"Changelog section for {version} is empty")

with open(output_path, "w", encoding="utf-8") as out:
    out.write("\n".join(section) + "\n")
PY
}

verify_appcast_entry() {
  local appcast="$1"
  local version="$2"
  local key_file="$3"
  local verify_script="${RELEASE_LIB_ROOT}/Scripts/verify_appcast.sh"

  [[ -f "$appcast" ]] || err "Appcast not found: $appcast"
  [[ -x "$verify_script" ]] || err "verify_appcast.sh not executable: $verify_script"

  SPARKLE_PRIVATE_KEY_FILE="$key_file" "$verify_script" "$version"
}

check_assets() {
  local tag="$1"
  local artifact_prefix="$2"
  local version="${tag#v}"
  local app_zip="${artifact_prefix}${version}.zip"
  local dsym_zip="${artifact_prefix}${version}.dSYM.zip"

  require_command gh
  local assets
  assets=$(gh release view "$tag" --json assets --jq '.assets[].name' 2>/dev/null || true)
  [[ -n "$assets" ]] || err "No assets found for release tag $tag"

  local missing=()
  if ! printf "%s\n" "$assets" | grep -Fxq "$app_zip"; then
    missing+=("$app_zip")
  fi
  if ! printf "%s\n" "$assets" | grep -Fxq "$dsym_zip"; then
    missing+=("$dsym_zip")
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Release assets for $tag:" >&2
    printf "%s\n" "$assets" >&2
    err "Missing expected assets: ${missing[*]}"
  fi

  echo "Release assets verified for $tag: $app_zip, $dsym_zip"
}
