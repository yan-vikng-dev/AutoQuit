set shell := ["zsh", "-cu"]

[default]
rebuild-install:
  set -euo pipefail
  xcodegen generate
  xcodebuild -project AutoQuit.xcodeproj -scheme AutoQuit -configuration Release -derivedDataPath .derived-release build
  pkill -f '/Applications/AutoQuit.app/Contents/MacOS/AutoQuit' || true
  rm -rf '/Applications/AutoQuit.app'
  ditto '.derived-release/Build/Products/Release/AutoQuit.app' '/Applications/AutoQuit.app'

dist-unsigned VERSION:
  set -euo pipefail
  xcodegen generate
  xcodebuild -project AutoQuit.xcodeproj -scheme AutoQuit -configuration Release -derivedDataPath .derived-release build CODE_SIGNING_ALLOWED=NO
  mkdir -p dist
  ditto -c -k --sequesterRsrc --keepParent '.derived-release/Build/Products/Release/AutoQuit.app' 'dist/AutoQuit-v{{VERSION}}-macos.zip'
  shasum -a 256 'dist/AutoQuit-v{{VERSION}}-macos.zip' > 'dist/AutoQuit-v{{VERSION}}-macos.zip.sha256'
  echo 'Created:'
  ls -lh 'dist/AutoQuit-v{{VERSION}}-macos.zip' 'dist/AutoQuit-v{{VERSION}}-macos.zip.sha256'

release VERSION:
  Scripts/release-github.sh '{{VERSION}}'
