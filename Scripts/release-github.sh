#!/usr/bin/env zsh
set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "Usage: Scripts/release-github.sh <version>"
  echo "Example: Scripts/release-github.sh 1.0.0"
  exit 64
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DIR="$ROOT_DIR/.derived-release"
APP_PATH="$DERIVED_DIR/Build/Products/Release/AutoQuit.app"
DIST_DIR="$ROOT_DIR/dist"
NOTARY_ZIP="$DIST_DIR/AutoQuit-v${VERSION}-notary-upload.zip"
FINAL_ZIP="$DIST_DIR/AutoQuit-v${VERSION}-macos.zip"
FINAL_ZIP_CHECKSUM="$FINAL_ZIP.sha256"
DMG_ROOT="$DERIVED_DIR/dmg-root"
FINAL_DMG="$DIST_DIR/AutoQuit-v${VERSION}.dmg"
FINAL_DMG_CHECKSUM="$FINAL_DMG.sha256"
NOTARY_PROFILE="${NOTARYTOOL_PROFILE:-autoquit-notary}"

cd "$ROOT_DIR"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen is required. Install it with: brew install xcodegen"
  exit 69
fi

SIGN_IDENTITY="${DEVELOPER_ID_APPLICATION:-}"
if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="$(security find-identity -v -p codesigning | awk -F '"' '/Developer ID Application/ { print $2; exit }')"
fi

if [[ -z "$SIGN_IDENTITY" ]]; then
  echo "No Developer ID Application signing identity found."
  echo "Create/download one from Apple Developer, then install it in your login keychain."
  exit 65
fi

echo "Using signing identity: $SIGN_IDENTITY"
echo "Using notarytool keychain profile: $NOTARY_PROFILE"

rm -rf "$DERIVED_DIR"
mkdir -p "$DIST_DIR"
rm -f "$NOTARY_ZIP" "$FINAL_ZIP" "$FINAL_ZIP_CHECKSUM" "$FINAL_DMG" "$FINAL_DMG_CHECKSUM"

xcodegen generate
xcodebuild \
  -project AutoQuit.xcodeproj \
  -scheme AutoQuit \
  -configuration Release \
  -derivedDataPath "$DERIVED_DIR" \
  build CODE_SIGNING_ALLOWED=NO

codesign \
  --force \
  --deep \
  --options runtime \
  --timestamp \
  --sign "$SIGN_IDENTITY" \
  "$APP_PATH"

codesign --verify --deep --strict --verbose=2 "$APP_PATH"

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$NOTARY_ZIP"
xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"
spctl -a -vvv -t exec "$APP_PATH"

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$FINAL_ZIP"
shasum -a 256 "$FINAL_ZIP" > "$FINAL_ZIP_CHECKSUM"
rm -f "$NOTARY_ZIP"

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

echo "Created:"
ls -lh "$FINAL_DMG" "$FINAL_DMG_CHECKSUM" "$FINAL_ZIP" "$FINAL_ZIP_CHECKSUM"
