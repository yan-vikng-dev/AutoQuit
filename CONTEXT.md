# AutoQuit Context

## Project Goal

Build a macOS menu bar utility that quits apps when their last primary window closes, using a launch-age grace period (instead of a hardcoded delayed quit model).

## Current State

- Project is a real macOS app target (`AutoQuit.xcodeproj`), not just `swift run`.
- Bundle ID: `dev.yan.autoquit`
- Menu bar app (`LSUIElement = true`).
- Runs locally without paid Apple Developer account.
- Local install path used for testing: `/Applications/AutoQuit.app`.

## Key Technical Decisions

1. Grace-period model
- Per-app `launchDate` is tracked.
- App is only terminated when:
  - no primary windows remain,
  - app age is beyond grace (`8s`),
  - and at least one primary window was seen before (`hasSeenPrimaryWindow`).

2. Event-driven window tracking (no polling loop)
- Removed recurring window polling.
- Added AX observer-based hooks for:
  - window created,
  - focused/main window changed,
  - window destroyed,
  - miniaturized/deminiaturized.
- Added one-shot grace recheck timers only when needed.

3. Accessibility trust gating
- On startup:
  - log runtime identity,
  - check AX trust,
  - prompt if untrusted.
- AX observer registration is deferred until trust is granted.
- Lightweight trust polling (`0.5s`) runs only while untrusted.
- When trust flips to true, observers are registered for all tracked running apps.

## Important Files

- App entry and setup:
  - `Sources/autoquit/main.swift`
  - `Sources/autoquit/AutoQuitAppDelegate.swift`
  - `Sources/autoquit/AppCoordinator.swift`
- Engine and AX:
  - `Sources/autoquit/AutoQuitEngine.swift`
  - `Sources/autoquit/AccessibilityInspector.swift`
  - `Sources/autoquit/AccessibilityEventMonitor.swift`
- Menu bar UI:
  - `Sources/autoquit/StatusMenuController.swift`
- App metadata/build:
  - `project.yml`
  - `AutoQuit-Info.plist`
  - `AutoQuit.xcodeproj` (generated)

## Exclusions (Hardcoded)

Currently excluded from auto-quit:

- `com.apple.finder`
- `com.apple.dock`
- `com.apple.systemuiserver`
- `com.apple.controlcenter`
- `com.apple.notificationcenterui`
- `com.apple.loginwindow`
- `com.apple.WindowServer`

(`System Settings` is intentionally not excluded by request.)

## Logging Added

Console logs exist for:

- startup identity and trust status,
- AX observer registration and AX events,
- decision path per app (keep alive, grace defer, terminate, skip reason).

Prefixes:

- `[AutoQuit][Startup]`
- `[AutoQuit][AX]`
- `[AutoQuit][Engine]`

## Permissions / Debug Lessons

1. Process identity matters
- Accessibility trust is tied to the running app identity/path context.
- Running wrong target (`swift package` executable) showed:
  - `bundleID=<no.bundle.id>`,
  - AX errors (`-25211` / `kAXErrorAPIDisabled`).

2. Correct target for debugging
- Must run `AutoQuit` app target (not package executable).

3. Stable local usage
- Use `/Applications/AutoQuit.app` for consistent trust and behavior.

## Icons and Assets

### App icon

- App icon is configured via `CFBundleIconFile = AppIcon`.
- Source pipeline currently uses:
  - `Assets/temp/AppIcon.png` as import source,
  - generated `Assets/AppIcon-1024.png`,
  - generated `Assets/AppIcon.iconset/*`,
  - generated `Assets/AppIcon.icns`.

### Menu bar icon

- Menu icon now switches by enabled state:
  - `Assets/MenuIconEnabled.png`
  - `Assets/MenuIconDisabled.png`
- `StatusMenuController` applies icon in `render(isEnabled:)`.
- Uses `NSStatusItem.squareLength` for tighter hover footprint.
- Keeps aspect ratio at target height (~16pt).

### Resource packaging fix

- Project now copies `Assets` in resources build phase.
- Excludes:
  - `Assets/temp/**`
  - `Assets/AppIcon.iconset/**`
- This avoids duplicate icon output and ensures required resources are present in app bundle.

## Build / Install Workflow (Local Product)

From repo root (`autoquit`):

1. Regenerate project after `project.yml` changes:
```bash
xcodegen generate
```

2. Build Release:
```bash
xcodebuild -project AutoQuit.xcodeproj -scheme AutoQuit -configuration Release -derivedDataPath .derived-release build CODE_SIGNING_ALLOWED=NO
```

3. Install locally:
```bash
ditto .derived-release/Build/Products/Release/AutoQuit.app /Applications/AutoQuit.app
codesign --force --deep --sign - /Applications/AutoQuit.app
open /Applications/AutoQuit.app
```

## Known Notes

- Some apps may ignore `terminate()` or relaunch due to their own behavior.
- Current app policy is broad (tracks most regular apps); user-configurable include/exclude UI not implemented yet.
- Debug logs are intentionally verbose while tuning behavior.

## Suggested Next Steps

1. Add persistent settings:
- grace period,
- logging toggle,
- include/exclude app list.

2. Add safety UX:
- confirmation mode or dry-run mode.

3. Improve classification heuristics:
- per-app overrides,
- better transient/special-window handling.
