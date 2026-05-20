#!/usr/bin/env zsh
set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "Usage: Scripts/release-github.sh <version>"
  echo "Example: Scripts/release-github.sh 1.0.2"
  exit 64
fi

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Version must be MAJOR.MINOR.PATCH (e.g. 1.0.2), got: $VERSION"
  exit 64
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DIR="$ROOT_DIR/.derived-release"
APP_PATH="$DERIVED_DIR/Build/Products/Release/AutoQuit.app"
DIST_DIR="$ROOT_DIR/dist"
DMG_ROOT="$DERIVED_DIR/dmg-root"
NOTARY_DMG="$DIST_DIR/AutoQuit-v${VERSION}-notary-upload.dmg"
FINAL_DMG="$DIST_DIR/AutoQuit-v${VERSION}.dmg"
FINAL_DMG_CHECKSUM="$FINAL_DMG.sha256"
PROJECT_YML="$ROOT_DIR/project.yml"
TAG="v$VERSION"
GITHUB_REPO="${GITHUB_REPOSITORY:-yan-vikng-dev/AutoQuit}"
NOTARY_PROFILE="${NOTARYTOOL_PROFILE:-autoquit-notary}"
SKIP_PUSH="${SKIP_PUSH:-0}"
SKIP_GITHUB_RELEASE="${SKIP_GITHUB_RELEASE:-0}"

cd "$ROOT_DIR"

# ---------- Pre-flight ----------

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1"
    [[ -n "${2:-}" ]] && echo "  $2"
    exit 69
  fi
}

require_cmd xcodegen "Install with: brew install xcodegen"
require_cmd gh "Install with: brew install gh"
require_cmd git-cliff "Install with: brew install git-cliff"

if ! git -C "$ROOT_DIR" diff --quiet || ! git -C "$ROOT_DIR" diff --cached --quiet; then
  echo "Working tree has uncommitted changes. Commit, stash, or discard before releasing."
  exit 65
fi

CURRENT_BRANCH="$(git -C "$ROOT_DIR" symbolic-ref --short HEAD 2>/dev/null || echo "")"
if [[ "$CURRENT_BRANCH" != "main" ]]; then
  echo "Releases must be cut from main (currently on: ${CURRENT_BRANCH:-detached HEAD})."
  exit 65
fi

git -C "$ROOT_DIR" fetch --tags origin main >/dev/null

LOCAL_SHA="$(git -C "$ROOT_DIR" rev-parse HEAD)"
REMOTE_SHA="$(git -C "$ROOT_DIR" rev-parse origin/main)"
if [[ "$LOCAL_SHA" != "$REMOTE_SHA" ]]; then
  echo "main is not in sync with origin/main."
  echo "  local : $LOCAL_SHA"
  echo "  remote: $REMOTE_SHA"
  echo "Pull or push, then re-run."
  exit 65
fi

if git -C "$ROOT_DIR" rev-parse --verify --quiet "refs/tags/$TAG" >/dev/null; then
  echo "Tag $TAG already exists locally. Pick a new version or delete the tag first."
  exit 65
fi

if git -C "$ROOT_DIR" ls-remote --tags --exit-code origin "refs/tags/$TAG" >/dev/null 2>&1; then
  echo "Tag $TAG already exists on origin. Pick a new version."
  exit 65
fi

if gh release view "$TAG" --repo "$GITHUB_REPO" >/dev/null 2>&1; then
  echo "GitHub release $TAG already exists. Pick a new version."
  exit 65
fi

LAST_TAG="$(git -C "$ROOT_DIR" describe --tags --abbrev=0 2>/dev/null || echo "")"
if [[ -n "$LAST_TAG" ]]; then
  COMMITS_SINCE_TAG="$(git -C "$ROOT_DIR" rev-list --count "$LAST_TAG"..HEAD)"
  if [[ "$COMMITS_SINCE_TAG" -eq 0 ]]; then
    echo "No commits since $LAST_TAG. Nothing to release."
    exit 65
  fi
fi

CURRENT_MARKETING="$(awk -F': ' '/^[[:space:]]+MARKETING_VERSION:/ {gsub(/[[:space:]]/,"",$2); print $2; exit}' "$PROJECT_YML")"
CURRENT_BUILD="$(awk -F': ' '/^[[:space:]]+CURRENT_PROJECT_VERSION:/ {gsub(/[[:space:]]/,"",$2); print $2; exit}' "$PROJECT_YML")"

if [[ -z "$CURRENT_MARKETING" || -z "$CURRENT_BUILD" ]]; then
  echo "Could not read MARKETING_VERSION or CURRENT_PROJECT_VERSION from $PROJECT_YML"
  exit 70
fi

if [[ "$CURRENT_MARKETING" == "$VERSION" ]]; then
  echo "MARKETING_VERSION is already $VERSION. Pick a new version."
  exit 65
fi

NEW_BUILD=$((CURRENT_BUILD + 1))

# Signing identity
SIGN_IDENTITY="${DEVELOPER_ID_APPLICATION:-}"
if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="$(security find-identity -v -p codesigning | awk -F '"' '/Developer ID Application/ { print $2; exit }')"
fi
if [[ -z "$SIGN_IDENTITY" ]]; then
  echo "No Developer ID Application signing identity found."
  echo "Create/download one from Apple Developer, then install it in your login keychain."
  exit 65
fi

echo "Releasing AutoQuit v$VERSION"
echo "  build number   : $CURRENT_BUILD -> $NEW_BUILD"
echo "  marketing ver  : $CURRENT_MARKETING -> $VERSION"
echo "  signing as     : $SIGN_IDENTITY"
echo "  notary profile : $NOTARY_PROFILE"
echo "  github repo    : $GITHUB_REPO"
echo

# ---------- Build ----------

rm -rf "$DERIVED_DIR"
mkdir -p "$DIST_DIR"
rm -f "$NOTARY_DMG" "$FINAL_DMG" "$FINAL_DMG_CHECKSUM"

xcodegen generate

xcodebuild \
  -project AutoQuit.xcodeproj \
  -scheme AutoQuit \
  -configuration Release \
  -derivedDataPath "$DERIVED_DIR" \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$NEW_BUILD" \
  build CODE_SIGNING_ALLOWED=NO

# ---------- Sign + notarize app ----------

codesign \
  --force \
  --deep \
  --options runtime \
  --timestamp \
  --sign "$SIGN_IDENTITY" \
  "$APP_PATH"

codesign --verify --deep --strict --verbose=2 "$APP_PATH"

# ---------- Build DMG, notarize, staple ----------

mkdir -p "$DMG_ROOT"
ditto "$APP_PATH" "$DMG_ROOT/AutoQuit.app"
ln -s /Applications "$DMG_ROOT/Applications"
hdiutil create -volname "AutoQuit" -srcfolder "$DMG_ROOT" -ov -format UDZO "$FINAL_DMG"
codesign --force --timestamp --sign "$SIGN_IDENTITY" "$FINAL_DMG"
codesign --verify --verbose=2 "$FINAL_DMG"
xcrun notarytool submit "$FINAL_DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$FINAL_DMG"
xcrun stapler validate "$FINAL_DMG"
spctl -a -vvv -t open --context context:primary-signature "$FINAL_DMG"
shasum -a 256 "$FINAL_DMG" > "$FINAL_DMG_CHECKSUM"

echo
echo "Built and notarized:"
ls -lh "$FINAL_DMG" "$FINAL_DMG_CHECKSUM"
echo

# ---------- Generate release notes ----------
# Done before the release commit/tag so the new "Release vX.Y.Z" commit
# isn't part of the range. cliff.toml also skips that commit message
# defensively.

RELEASE_NOTES_FILE="$DIST_DIR/release-notes-v${VERSION}.md"
git-cliff --tag "$TAG" --unreleased -o "$RELEASE_NOTES_FILE"

if [[ ! -s "$RELEASE_NOTES_FILE" ]]; then
  echo "git-cliff produced empty release notes. Falling back to a placeholder."
  echo "_No notable changes._" > "$RELEASE_NOTES_FILE"
fi

echo "Release notes preview:"
echo "---"
cat "$RELEASE_NOTES_FILE"
echo "---"
echo

# ---------- Bump versions, commit, tag ----------

# Edit project.yml in place. The patterns are anchored to the indented YAML keys
# so we don't accidentally touch other occurrences.
sed -i '' "s/^\([[:space:]]*\)MARKETING_VERSION: .*/\1MARKETING_VERSION: $VERSION/" "$PROJECT_YML"
sed -i '' "s/^\([[:space:]]*\)CURRENT_PROJECT_VERSION: .*/\1CURRENT_PROJECT_VERSION: $NEW_BUILD/" "$PROJECT_YML"

git -C "$ROOT_DIR" add "$PROJECT_YML"
git -C "$ROOT_DIR" commit -m "Release v$VERSION"
git -C "$ROOT_DIR" tag -a "$TAG" -m "AutoQuit v$VERSION"

if [[ "$SKIP_PUSH" == "1" ]]; then
  echo "SKIP_PUSH=1 set; not pushing commit/tag. Push manually with:"
  echo "  git push origin main --follow-tags"
else
  git -C "$ROOT_DIR" push origin main --follow-tags
fi

# ---------- Publish GitHub release ----------

if [[ "$SKIP_GITHUB_RELEASE" == "1" ]]; then
  echo "SKIP_GITHUB_RELEASE=1 set; not publishing GitHub release."
  echo "Publish manually with:"
  echo "  gh release create $TAG '$FINAL_DMG' '$FINAL_DMG_CHECKSUM' --repo $GITHUB_REPO --title 'AutoQuit v$VERSION' --notes-file '$RELEASE_NOTES_FILE'"
  exit 0
fi

gh release create "$TAG" \
  "$FINAL_DMG" \
  "$FINAL_DMG_CHECKSUM" \
  --repo "$GITHUB_REPO" \
  --title "AutoQuit v$VERSION" \
  --notes-file "$RELEASE_NOTES_FILE"

echo
echo "Released AutoQuit v$VERSION"
echo "  https://github.com/$GITHUB_REPO/releases/tag/$TAG"
