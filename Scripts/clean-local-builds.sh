#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: Scripts/clean-local-builds.sh [--dry-run]

Removes generated local Runic build artifacts:
  .build/     SwiftPM build cache
  builds/     packaged release builds
  build/      legacy icon/build scratch output
  Runic.app   legacy root-level app bundle

The installed /Applications/Runic.app is never removed by this script.

Options:
  -n, --dry-run   Print what would be removed without deleting anything
  -h, --help      Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! -f "$ROOT/Package.swift" || ! -d "$ROOT/Sources" ]]; then
  echo "Refusing to clean: $ROOT does not look like the Runic repo root." >&2
  exit 1
fi

targets=(
  ".build"
  "builds"
  "build"
  "Runic.app"
)

removed=0
skipped=0

for rel in "${targets[@]}"; do
  path="$ROOT/$rel"

  if [[ ! -e "$path" && ! -L "$path" ]]; then
    echo "Skip missing: $rel"
    skipped=$((skipped + 1))
    continue
  fi

  case "$path" in
    "$ROOT"/*) ;;
    *)
      echo "Skip unsafe path outside repo: $path" >&2
      skipped=$((skipped + 1))
      continue
      ;;
  esac

  if tracked=$(git -C "$ROOT" ls-files -- "$rel") && [[ -n "$tracked" ]]; then
    echo "Skip tracked path: $rel" >&2
    skipped=$((skipped + 1))
    continue
  fi

  size=$(du -sh "$path" 2>/dev/null | awk '{print $1}' || true)
  if [[ -z "$size" ]]; then
    size="unknown size"
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    echo "Would remove: $rel ($size)"
  else
    echo "Removing: $rel ($size)"
    rm -rf "$path"
  fi
  removed=$((removed + 1))
done

if [[ "$DRY_RUN" == "1" ]]; then
  echo "Dry run complete: $removed removable, $skipped skipped."
else
  echo "Clean complete: $removed removed, $skipped skipped."
fi
