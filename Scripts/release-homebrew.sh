#!/usr/bin/env zsh
set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "Usage: Scripts/release-homebrew.sh <version>"
  echo "Example: Scripts/release-homebrew.sh 1.0.2"
  exit 64
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Step 1: build, sign, notarize, tag, push, and publish the GitHub release.
# Skip via SKIP_BUILD=1 if the GitHub release already exists for this version.
if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
  "$ROOT_DIR/Scripts/release-github.sh" "$VERSION"
fi

# Step 2: open a Homebrew cask bump PR against the tap.
"$ROOT_DIR/Scripts/update-homebrew-cask.sh" "$VERSION"
