#!/usr/bin/env bash
# Point git at the repo's hooks so the release gates run at commit time.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
git config core.hooksPath .githooks
echo "hooks installed: $(git config core.hooksPath)"
