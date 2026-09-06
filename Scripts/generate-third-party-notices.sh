#!/usr/bin/env bash
# Regenerate THIRD-PARTY-NOTICES.md from the resolved dependency checkouts and
# the bundled font licenses. MIT/Apache/zlib-style licenses require their notice
# to travel with binary distributions; package_app.sh copies this file into the
# app bundle. Run after changing dependencies.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
OUT=THIRD-PARTY-NOTICES.md
[[ -d .build/checkouts ]] || { echo "run swift build first (.build/checkouts missing)" >&2; exit 1; }

version_of() { python3 -c "
import json,sys
for p in json.load(open('Package.resolved'))['pins']:
    if p['identity'].lower()==sys.argv[1].lower(): print(p['state'].get('version') or p['state'].get('revision','')[:8])
" "$1"; }

{
  echo "# Third-party notices"
  echo
  echo "Runic is MPL-2.0 (see LICENSE). It ships the following third-party software and fonts under their own licenses, reproduced here as those licenses require."
  echo
  for dep in Sparkle KeyboardShortcuts swift-log swift-syntax CryptoSwift; do
    dir=".build/checkouts/$dep"
    file=$(find "$dir" -maxdepth 1 -iname "LICENSE*" | head -1)
    [[ -n "$file" ]] || { echo "no license file for $dep" >&2; exit 1; }
    echo "## $dep $(version_of "$dep")"
    echo
    echo '```'
    cat "$file"
    echo '```'
    echo
  done
  for own in Silo Helix; do
    dir=$(ls -d "Packages/$own" "../Packages/$own" 2>/dev/null | head -1 || true)
    file=$( [[ -n "$dir" ]] && find "$dir" -maxdepth 1 -iname "LICENSE*" | head -1 || true)
    v=$(version_of "$own"); echo "## $own ${v:-local}"
    echo
    echo '```'
    if [[ -n "$file" ]]; then cat "$file"; else echo "MIT License — https://github.com/sriinnu/$own"; fi
    echo '```'
    echo
  done
  echo "## Fonts (SIL Open Font License 1.1)"
  echo
  echo "Geist, Geist Mono, Mona Sans, Commit Mono, and VT323 are bundled under the SIL OFL 1.1. The full license text for each ships alongside the fonts in \`Contents/Resources/Fonts/\` (OFL-*.txt). See \`Sources/Runic/Resources/Fonts/FONT_PROVENANCE.md\`."
} > "$OUT"
echo "wrote $OUT ($(wc -l < "$OUT") lines)"
