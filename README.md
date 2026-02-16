# AutoQuit

AutoQuit is a macOS menu bar app that closes apps after their last window is gone.

## Behavior

- Tracks regular user apps.
- Uses Accessibility events and AX window inspection.
- Quits an app only when:
  - the app is older than the configured grace period,
  - AX window count is `0`,
  - and the app has shown at least one window since launch.

Default grace period is `5s`.

## Controls

- Enable / disable AutoQuit
- Enable Launch at Login
- Set grace period: `0, 1, 3, 5, 10, 30` seconds
- Enable / disable file logging
- Open / clear log file

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

## Permissions

AutoQuit requires Accessibility permission:

- `System Settings -> Privacy & Security -> Accessibility`
- enable `AutoQuit`
