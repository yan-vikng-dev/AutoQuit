set shell := ["zsh", "-cu"]

rebuild-install:
  set -euo pipefail
  cd /Users/yan/Desktop/github/yan-vikng-dev/macos-quit/autoquit
  xcodegen generate
  xcodebuild -project AutoQuit.xcodeproj -scheme AutoQuit -configuration Release -derivedDataPath .derived-release build CODE_SIGNING_ALLOWED=NO
  pkill -f '/Applications/AutoQuit.app/Contents/MacOS/AutoQuit' || true
  if [ -d '/Applications/AutoQuit.app' ]; then mv '/Applications/AutoQuit.app' "/Applications/AutoQuit.app.bak.$(date +%Y%m%d-%H%M%S)"; fi
  rm -rf '/Applications/AutoQuit.app'
  ditto '.derived-release/Build/Products/Release/AutoQuit.app' '/Applications/AutoQuit.app'
  codesign --force --deep --sign - '/Applications/AutoQuit.app'
