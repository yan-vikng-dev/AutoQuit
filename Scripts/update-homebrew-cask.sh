#!/usr/bin/env zsh
set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "Usage: Scripts/update-homebrew-cask.sh <version>"
  echo "Example: Scripts/update-homebrew-cask.sh 1.0.0"
  exit 64
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TAP_NAME="${HOMEBREW_TAP_NAME:-yan-vikng-dev/tap}"
CASK_TOKEN="${HOMEBREW_CASK_TOKEN:-autoquit}"
DMG_PATH="$ROOT_DIR/dist/AutoQuit-v${VERSION}.dmg"
CHECKSUM_PATH="$DMG_PATH.sha256"

if [[ ! -f "$DMG_PATH" ]]; then
  echo "Missing release dmg: $DMG_PATH"
  echo "Run: just release $VERSION"
  exit 66
fi

if [[ ! -f "$CHECKSUM_PATH" ]]; then
  echo "Missing checksum file: $CHECKSUM_PATH"
  echo "Run: shasum -a 256 '$DMG_PATH' > '$CHECKSUM_PATH'"
  exit 66
fi

SHA256="$(awk '{ print $1 }' "$CHECKSUM_PATH")"
if [[ ! "$SHA256" =~ '^[0-9a-fA-F]{64}$' ]]; then
  echo "Invalid SHA-256 in $CHECKSUM_PATH: $SHA256"
  exit 65
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required to update the cask."
  exit 69
fi

brew tap "$TAP_NAME" >/dev/null
TAP_DIR="$(brew --repository "$TAP_NAME")"
CASK_PATH="$TAP_DIR/Casks/$CASK_TOKEN.rb"

if [[ ! -f "$CASK_PATH" ]]; then
  echo "Missing cask in tap: $CASK_PATH"
  echo "Create the cask once before using the update workflow."
  exit 66
fi

if ! git -C "$TAP_DIR" diff --quiet || ! git -C "$TAP_DIR" diff --cached --quiet; then
  echo "Tap checkout has uncommitted changes: $TAP_DIR"
  echo "Commit, stash, or discard them before running the cask bump."
  exit 65
fi

git -C "$TAP_DIR" checkout main >/dev/null
git -C "$TAP_DIR" pull --ff-only >/dev/null

BUMP_ARGS=(
  bump-cask-pr
  --version "$VERSION"
  --sha256 "$SHA256"
  --no-browse
)

if [[ "${HOMEBREW_CASK_DRY_RUN:-0}" == "1" ]]; then
  BUMP_ARGS+=(--dry-run)
fi

if [[ "${HOMEBREW_CASK_WRITE_ONLY:-0}" == "1" ]]; then
  BUMP_ARGS+=(--write-only --no-audit --no-style)
fi

BUMP_ARGS+=("$TAP_NAME/$CASK_TOKEN")

HOMEBREW_DEVELOPER=1 brew "${BUMP_ARGS[@]}"

echo "Updated: $CASK_PATH"
echo "Version: $VERSION"
echo "SHA-256: $SHA256"
