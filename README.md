# AutoQuit

AutoQuit is a macOS menu bar app that closes apps after their last window is gone.
This mirrors Windows behaviour where apps cannot remain open without a window.

## Behavior

- AutoQuit uses a grace period mechanism to prevent apps with splash screens from being closed prematurely.
- Grace period is measured from app launch time.
- AutoQuit does not quit the following apps:
  - Finder
  - Dock
  - SystemUIServer
  - Control Center
  - Notification Center
  - loginwindow
  - WindowServer

## Installation

With Homebrew:

```bash
brew tap yan-vikng-dev/tap
brew install --cask autoquit
```

Or manually:

1. Download the latest build: https://github.com/yan-vikng-dev/AutoQuit/releases/latest
2. Open the `.dmg`.
3. Drag `AutoQuit.app` to `Applications`.
4. Eject the disk image and open `AutoQuit.app` from `/Applications`.

## Build and Run

```bash
xcodegen generate
open AutoQuit.xcodeproj
```

Or use the local install workflow:

```bash
just rebuild-install
open /Applications/AutoQuit.app
```

## Releasing

Maintainer release steps are documented in `RELEASING.md`.
