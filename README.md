# AutoQuit (Scaffold)

Menu bar MVP for "quit on last primary window close" using a launch-age grace period instead of a hardcoded delayed quit.

## Current Behavior

- Runs as a menu bar app.
- Tracks regular macOS apps.
- Uses Accessibility observers (window create/destroy/focus/minimize hooks), not polling.
- Uses Accessibility window inspection to count primary windows when hooks fire.
- Records app launch time and applies an age check (`gracePeriodSeconds = 8`).
- Quits an app only when:
  - app is older than grace period, and
  - app has no primary windows, and
  - app previously had at least one primary window.

## Why This Exists

This scaffold is intentionally simple and hackable. It is designed to test the launch-date grace-period strategy quickly before investing in richer per-app heuristics.

## Run

```bash
swift run
```

Then grant Accessibility access when prompted from the menu item:

- `Request Accessibility Permission`

## Run As Full App (Xcode)

Generate/open the app project:

```bash
xcodegen generate
open AutoQuit.xcodeproj
```

In Xcode:

- Select scheme `AutoQuit`
- Press Run
- Set breakpoints in:
  - `Sources/autoquit/AutoQuitEngine.swift`
  - `Sources/autoquit/AccessibilityEventMonitor.swift`

CLI build (no signing required for local build validation):

```bash
xcodebuild -project AutoQuit.xcodeproj -scheme AutoQuit -configuration Debug -derivedDataPath .derived build CODE_SIGNING_ALLOWED=NO
open .derived/Build/Products/Debug/AutoQuit.app
```

## Project Layout

- `Sources/autoquit/main.swift` app bootstrap
- `Sources/autoquit/AutoQuitAppDelegate.swift` lifecycle entry point
- `Sources/autoquit/AppCoordinator.swift` wiring for engine + status menu
- `Sources/autoquit/StatusMenuController.swift` menu bar UI
- `Sources/autoquit/AutoQuitEngine.swift` grace-period decisions
- `Sources/autoquit/AccessibilityInspector.swift` AX window classification
- `Assets/` placeholder media/icons

## Notes

- This is an MVP scaffold, not production-safe.
- Some apps use unusual AX behavior; false positives/negatives are still possible.
- Exclusions and settings UI are intentionally minimal for now.
