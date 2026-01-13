---
summary: "Homebrew Cask release steps for Runic (Sparkle-disabled builds)."
read_when:
  - Publishing a Runic release via Homebrew
  - Updating the Homebrew tap cask definition
---

# Runic Homebrew Release Playbook

Homebrew is for the UI app via Cask. When installed via Homebrew, Runic disables Sparkle and shows a "update via brew" hint in About.

## Prereqs
- Homebrew installed.
- Access to the tap repo: `../homebrew-tap`.

## 1) Release Runic normally
Follow `docs/RELEASING.md` to publish `Runic-<version>.zip` to GitHub Releases.

## 2) Update the Homebrew tap cask
In `../homebrew-tap`, add/update the cask at `Casks/runic.rb`:
- `url` points at the GitHub release asset: `.../releases/download/v<version>/Runic-<version>.zip`
- Update `sha256` to match that zip.
- Keep `depends_on arch: :arm64` and `depends_on macos: ">= :sonoma"` (Runic is macOS 14+).

## 3) Verify install
```sh
brew uninstall --cask runic || true
brew untap steipete/tap || true
brew tap steipete/tap
brew install --cask steipete/tap/runic
open -a Runic
```

## 4) Push tap changes
Commit + push in the tap repo.
