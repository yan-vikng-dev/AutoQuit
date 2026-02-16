import ApplicationServices
import Foundation

final class AccessibilityEventMonitor {
    typealias EventHandler = (pid_t, String) -> Void

    private let inspector: AccessibilityInspector
    private var handler: EventHandler?
    private var observersByPID: [pid_t: AXObserver] = [:]
    var debugLoggingEnabled = true
    var onPermissionFailure: (() -> Void)?

    init(inspector: AccessibilityInspector) {
        self.inspector = inspector
    }

    func start(handler: @escaping EventHandler) {
        self.handler = handler
    }

    func registerApplication(pid: pid_t) {
        guard observersByPID[pid] == nil else { return }

        var observer: AXObserver?
        let createError = AXObserverCreate(pid, Self.callback, &observer)
        guard createError == .success, let observer else {
            log("Failed to create observer for pid=\(pid) error=\(createError.rawValue)")
            notifyPermissionFailureIfNeeded(error: createError)
            return
        }

        observersByPID[pid] = observer
        log("Registered observer for pid=\(pid)")
        let appElement = AXUIElementCreateApplication(pid)

        addNotification(kAXWindowCreatedNotification as String, element: appElement, observer: observer)
        addNotification(kAXFocusedWindowChangedNotification as String, element: appElement, observer: observer)
        addNotification(kAXMainWindowChangedNotification as String, element: appElement, observer: observer)

        subscribeToWindowLifecycle(pid: pid, observer: observer)
        let source = AXObserverGetRunLoopSource(observer)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    func unregisterApplication(pid: pid_t) {
        guard let observer = observersByPID.removeValue(forKey: pid) else { return }
        let source = AXObserverGetRunLoopSource(observer)
        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        log("Unregistered observer for pid=\(pid)")
    }

    private func addNotification(_ name: String, element: AXUIElement, observer: AXObserver) {
        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let result = AXObserverAddNotification(observer, element, name as CFString, refcon)
        guard result == .success || result == .notificationAlreadyRegistered else {
            log("Failed to add AX notification \(name) result=\(result.rawValue)")
            notifyPermissionFailureIfNeeded(error: result)
            return
        }
    }

    private func notifyPermissionFailureIfNeeded(error: AXError) {
        guard error == .apiDisabled else { return }
        log("Detected AX API disabled; requesting trust refresh")
        onPermissionFailure?()
    }

    private func subscribeToWindowLifecycle(pid: pid_t, observer: AXObserver) {
        for window in inspector.windows(for: pid) {
            addNotification(kAXUIElementDestroyedNotification as String, element: window, observer: observer)
            addNotification(kAXWindowMiniaturizedNotification as String, element: window, observer: observer)
            addNotification(kAXWindowDeminiaturizedNotification as String, element: window, observer: observer)
        }
    }

    private func handleCallback(observer: AXObserver, element: AXUIElement, notification: String, pid: pid_t) {
        if notification == kAXWindowCreatedNotification as String {
            subscribeToWindowLifecycle(pid: pid, observer: observer)
        }
        log("AX event \(notification) pid=\(pid)")
        handler?(pid, notification)
    }

    private static let callback: AXObserverCallback = { observer, element, notification, refcon in
        guard let refcon else { return }

        let monitor = Unmanaged<AccessibilityEventMonitor>.fromOpaque(refcon).takeUnretainedValue()
        var pid: pid_t = 0
        let result = AXUIElementGetPid(element, &pid)
        guard result == .success else { return }
        monitor.handleCallback(
            observer: observer,
            element: element,
            notification: notification as String,
            pid: pid
        )
    }

    private func log(_ message: String) {
        guard debugLoggingEnabled else { return }
        AppLogger.shared.log(component: "AX", message: message)
    }
}
