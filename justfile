set shell := ["zsh", "-cu"]

[default]
rebuild-install:
  set -euo pipefail
  xcodegen generate
  xcodebuild -project AutoQuit.xcodeproj -scheme AutoQuit -configuration Release -derivedDataPath .derived-release build
  pkill -f '/Applications/AutoQuit.app/Contents/MacOS/AutoQuit' || true
  rm -rf '/Applications/AutoQuit.app'
  ditto '.derived-release/Build/Products/Release/AutoQuit.app' '/Applications/AutoQuit.app'
