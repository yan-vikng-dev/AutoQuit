import AppKit

private struct AppRuntimeState {
    var launchDate: Date
    var hasSeenWindow: Bool
}

final class AutoQuitEngine: @unchecked Sendable {
    var isEnabled = true
    private(set) var gracePeriodSeconds: TimeInterval = 5
    var debugLoggingEnabled = true {
        didSet {
            eventMonitor.debugLoggingEnabled = debugLoggingEnabled
        }
    }

    private let accessibilityInspector = AccessibilityInspector()
    private lazy var eventMonitor = AccessibilityEventMonitor(inspector: accessibilityInspector)
    private var runtimeStateByPID: [pid_t: AppRuntimeState] = [:]
    private var pendingGraceRechecks: [pid_t: DispatchWorkItem] = [:]
    private var trustPollingTimer: Timer?
    private var accessibilityActive = false
    var onAccessibilityTrustChanged: ((Bool) -> Void)?

    private let excludedBundleIDs: Set<String> = [
        "com.apple.finder",
        "com.apple.dock",
        "com.apple.systemuiserver",
        "com.apple.controlcenter",
        "com.apple.notificationcenterui",
        "com.apple.loginwindow",
        "com.apple.WindowServer"
    ]

    func start() {
        eventMonitor.debugLoggingEnabled = debugLoggingEnabled
        log("Starting engine (grace=\(Int(gracePeriodSeconds))s)")
        eventMonitor.start { [weak self] pid in
            self?.evaluateApplicationIfTracked(pid: pid)
        }
        seedExistingApplications()
        installWorkspaceObservers()
        refreshAccessibilityState()
    }

    func setGracePeriod(seconds: TimeInterval) {
        let normalizedSeconds = max(0, seconds)
        guard gracePeriodSeconds != normalizedSeconds else { return }

        gracePeriodSeconds = normalizedSeconds
        log("Updated grace period to \(Int(gracePeriodSeconds))s")

        // Existing timers are computed with the previous grace period.
        for workItem in pendingGraceRechecks.values {
            workItem.cancel()
        }
        pendingGraceRechecks.removeAll()

        for pid in runtimeStateByPID.keys {
            evaluateApplicationIfTracked(pid: pid)
        }
    }

    var isAccessibilityTrusted: Bool {
        accessibilityInspector.hasAccessibilityTrust
    }

    private func seedExistingApplications() {
        for app in NSWorkspace.shared.runningApplications where shouldTrack(app) {
            runtimeStateByPID[app.processIdentifier] = AppRuntimeState(
                launchDate: app.launchDate ?? Date(),
                hasSeenWindow: false
            )
            log("Seed app \(appLabel(app))")
            if accessibilityActive {
                eventMonitor.registerApplication(pid: app.processIdentifier)
                evaluate(app)
            }
        }
    }

    private func installWorkspaceObservers() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                self?.shouldTrack(app) == true
            else {
                return
            }
            self?.runtimeStateByPID[app.processIdentifier] = AppRuntimeState(
                launchDate: app.launchDate ?? Date(),
                hasSeenWindow: false
            )
            self?.log("App launched \(self?.appLabel(app) ?? "unknown")")
            self?.refreshAccessibilityState()
            if self?.accessibilityActive == true {
                self?.eventMonitor.registerApplication(pid: app.processIdentifier)
                self?.evaluate(app)
            } else {
                self?.log("Deferring AX observer registration until trust is granted for \(self?.appLabel(app) ?? "unknown")")
            }
        }

        center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            self?.log("App terminated \(self?.appLabel(app) ?? "unknown")")
            self?.pendingGraceRechecks[app.processIdentifier]?.cancel()
            self?.pendingGraceRechecks.removeValue(forKey: app.processIdentifier)
            self?.eventMonitor.unregisterApplication(pid: app.processIdentifier)
            self?.runtimeStateByPID.removeValue(forKey: app.processIdentifier)
        }
    }

    private func refreshAccessibilityState() {
        let trusted = accessibilityInspector.hasAccessibilityTrust
        if trusted {
            stopTrustPolling()
            if !accessibilityActive {
                accessibilityActive = true
                log("Accessibility trust became active; registering observers")
                onAccessibilityTrustChanged?(true)
                activateAccessibilityObserversForTrackedApps()
            }
            return
        }

        if accessibilityActive {
            accessibilityActive = false
            log("Accessibility trust lost; unregistering observers")
            onAccessibilityTrustChanged?(false)
            deactivateAccessibilityObservers()
        } else {
            log("Accessibility not trusted yet; waiting to register observers")
        }
        startTrustPolling()
    }

    private func activateAccessibilityObserversForTrackedApps() {
        let trackedApps = NSWorkspace.shared.runningApplications.filter { shouldTrack($0) }
        for app in trackedApps {
            if runtimeStateByPID[app.processIdentifier] == nil {
                runtimeStateByPID[app.processIdentifier] = AppRuntimeState(
                    launchDate: app.launchDate ?? Date(),
                    hasSeenWindow: false
                )
            }
            eventMonitor.registerApplication(pid: app.processIdentifier)
            evaluate(app)
        }
    }

    private func deactivateAccessibilityObservers() {
        for pid in runtimeStateByPID.keys {
            eventMonitor.unregisterApplication(pid: pid)
        }
    }

    private func startTrustPolling() {
        guard trustPollingTimer == nil else { return }
        trustPollingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.refreshAccessibilityState()
        }
        log("Started trust polling")
    }

    private func stopTrustPolling() {
        if trustPollingTimer != nil {
            log("Stopped trust polling")
        }
        trustPollingTimer?.invalidate()
        trustPollingTimer = nil
    }

    private func evaluateApplicationIfTracked(pid: pid_t) {
        guard let app = NSRunningApplication(processIdentifier: pid), shouldTrack(app) else {
            log("Skipping untracked pid=\(pid)")
            return
        }
        log("Evaluating from AX event for \(appLabel(app))")
        evaluate(app)
    }

    private func evaluate(_ app: NSRunningApplication) {
        guard isEnabled else {
            log("AutoQuit disabled, skip \(appLabel(app))")
            return
        }
        guard accessibilityInspector.hasAccessibilityTrust else {
            log("Accessibility not trusted, skip \(appLabel(app))")
            return
        }

        let pid = app.processIdentifier
        var state = runtimeStateByPID[pid] ?? AppRuntimeState(
            launchDate: app.launchDate ?? Date(),
            hasSeenWindow: false
        )

        let windowCount = accessibilityInspector.windowCount(for: pid)
        log("App \(appLabel(app)) windowCount=\(windowCount) hasSeenWindow=\(state.hasSeenWindow)")
        if windowCount > 0 {
            state.hasSeenWindow = true
            runtimeStateByPID[pid] = state
            cancelGraceRecheck(pid: pid)
            log("Keep alive \(appLabel(app)): window present")
            return
        }

        let appAgeSeconds = Date().timeIntervalSince(state.launchDate)
        if appAgeSeconds < gracePeriodSeconds {
            runtimeStateByPID[pid] = state
            log("In grace window for \(appLabel(app)) age=\(Int(appAgeSeconds))s")
            scheduleGraceRecheck(for: app, state: state)
            return
        }

        // Avoid quitting regular apps that have never surfaced any window.
        if !state.hasSeenWindow {
            runtimeStateByPID[pid] = state
            cancelGraceRecheck(pid: pid)
            log("Skip terminate \(appLabel(app)): never saw any window")
            return
        }

        runtimeStateByPID[pid] = state
        cancelGraceRecheck(pid: pid)
        log("Terminating \(appLabel(app))")
        _ = app.terminate()
    }

    private func scheduleGraceRecheck(for app: NSRunningApplication, state: AppRuntimeState) {
        guard state.hasSeenWindow else {
            log("No grace recheck for \(appLabel(app)): no window observed yet")
            return
        }

        let pid = app.processIdentifier
        if pendingGraceRechecks[pid] != nil {
            log("Grace recheck already queued for \(appLabel(app))")
            return
        }

        let secondsUntilGraceEnds = gracePeriodSeconds - Date().timeIntervalSince(state.launchDate)
        guard secondsUntilGraceEnds > 0 else {
            log("Grace already elapsed for \(appLabel(app)), evaluating now")
            evaluate(app)
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            self?.pendingGraceRechecks.removeValue(forKey: pid)
            self?.log("Grace timer fired for pid=\(pid)")
            self?.evaluateApplicationIfTracked(pid: pid)
        }
        pendingGraceRechecks[pid] = workItem
        log("Scheduled grace recheck for \(appLabel(app)) in \(String(format: "%.2f", secondsUntilGraceEnds))s")
        DispatchQueue.main.asyncAfter(deadline: .now() + secondsUntilGraceEnds, execute: workItem)
    }

    private func cancelGraceRecheck(pid: pid_t) {
        if pendingGraceRechecks[pid] != nil {
            log("Canceled grace recheck for pid=\(pid)")
        }
        pendingGraceRechecks[pid]?.cancel()
        pendingGraceRechecks.removeValue(forKey: pid)
    }

    private func shouldTrack(_ app: NSRunningApplication) -> Bool {
        if app.processIdentifier == ProcessInfo.processInfo.processIdentifier {
            return false
        }
        if app.activationPolicy != .regular {
            return false
        }
        guard let bundleID = app.bundleIdentifier else {
            return false
        }
        if excludedBundleIDs.contains(bundleID) {
            return false
        }
        return true
    }

    private func appLabel(_ app: NSRunningApplication) -> String {
        let name = app.localizedName ?? "<unknown>"
        let bundle = app.bundleIdentifier ?? "<no.bundle>"
        return "\(name) [pid=\(app.processIdentifier), \(bundle)]"
    }

    private func log(_ message: String) {
        guard debugLoggingEnabled else { return }
        AppLogger.shared.log(component: "Engine", message: message)
    }
}
