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

1. Download the latest build: https://github.com/yan-vikng-dev/AutoQuit/releases/latest
2. Open the `.zip` and move `AutoQuit.app` to `/Applications`.
3. Open `AutoQuit.app`.

> Temporary note: until AutoQuit is signed with an Apple Developer account, macOS may show a “malicious software” warning. If that happens, open it from `System Settings -> Privacy & Security` (or right-click `AutoQuit.app` -> `Open`) to allow it.

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
