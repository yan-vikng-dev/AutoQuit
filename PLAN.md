# Last-Window Auto-Quit (macOS) - Plan

## Context
- Current behavior relies on a fixed delay before quitting an app after its last window closes.
- The fixed delay is used to avoid false quits during startup/splash-screen transitions.
- Goal: build a custom macOS utility with better signals for deciding when to quit.
- Target user/device: personal use on MacBook first, with potential public release later.

## Problem Statement
- Naive "last window closed => quit app" logic can incorrectly quit apps during startup.
- Splash or transient windows may emit close events before the main window appears.
- Different apps expose different window types and Accessibility attributes.

## Product Goal
- Automatically quit apps when their last **primary** window is closed.
- Avoid false positives for newly launched apps and non-primary windows.

## Functional Requirements
1. Track application lifecycle:
- Detect app launch/termination/activation events.
- Maintain per-app launch timestamp (`launchDate`).

2. Track window state changes:
- Observe window close/disappear events.
- Re-scan current windows for the app before deciding to quit.

3. Window classification:
- Distinguish primary windows from transient/non-primary windows.
- Prefer combined heuristics:
  - AX role/subrole (e.g., ignore sheets/dialog-like/transient elements where appropriate)
  - Window visibility/size sanity checks
  - Presence of expected controls (e.g., `AXMinimizeButton`) as optional signal

4. Grace period logic:
- If app age is below configurable startup grace window, do not auto-quit yet.
- Re-evaluate after grace period or on next relevant window event.

5. Quit decision:
- If zero primary windows remain and app is past grace period, request normal terminate.
- Avoid force-quit by default.

6. Exclusions:
- Global app exclusions list (e.g., Finder, menu-bar-only apps, user-defined).
- Optional per-app policy overrides.

## Non-Functional Requirements
- Reliability: no frequent false quits during normal startup/use.
- Low overhead: lightweight background/menu bar app.
- Privacy/safety: only required Accessibility access; no extra data collection.
- Observability: optional debug logging for classification/quit decisions.

## Platform & Permissions
- Platform: macOS (Swift, menu bar app, `LSUIElement`).
- Required permission: Accessibility trust (`AXIsProcessTrustedWithOptions`).
- Distribution:
  - Local/internal use possible without paid dev account.
  - Public trusted release requires Developer ID signing + notarization (paid Apple Developer Program).

## High-Level Architecture
1. Event Layer
- `NSWorkspace` notifications for app lifecycle.
- Accessibility observers for window-level changes.

2. State Layer
- Per-app model: pid, bundle id, launchDate, known windows, exclusion flags.

3. Decision Engine
- Window classifier (primary vs transient).
- Grace-window evaluator.
- Quit policy executor.

4. UI/Config Layer
- Menu bar controls.
- Settings for grace duration, exclusions, logging.

## Milestones
1. MVP
- Lifecycle tracking
- AX permission flow
- Last-primary-window detection
- Startup grace handling
- Basic exclusions

2. Beta
- Settings UI
- Per-app overrides
- Structured logs and diagnostics

3. Release
- Code signing
- Notarization
- Installer/distribution packaging

## Open Decisions
1. Default grace duration (e.g., 3-8 seconds).
2. Exact primary-window heuristic weighting.
3. Initial default exclusion list.
4. Whether to support both "global policy" and per-app policy from day one.

## Acceptance Criteria (MVP)
1. App does not quit during common splash/startup flows when main window appears shortly after.
2. App quits when last primary window closes after grace window.
3. Excluded apps are never auto-quit.
4. User can see permission status and basic decision logs.
