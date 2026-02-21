#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
source "$ROOT/Scripts/release-lib.sh"

TAG=${1:-$(git describe --tags --abbrev=0)}
ARTIFACT_PREFIX="Runic-"

check_assets "$TAG" "$ARTIFACT_PREFIX"
