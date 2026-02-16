import AppKit
import ApplicationServices
import Foundation

final class AccessibilityInspector {
    var hasAccessibilityTrust: Bool {
        AXIsProcessTrusted()
    }

    static func promptForAccessibilityTrust() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    @discardableResult
    static func openAccessibilitySettings() -> Bool {
        let deepLinkCandidates = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.Settings.PrivacySecurity.extension?Privacy_Accessibility"
        ]
        for candidate in deepLinkCandidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) {
                return true
            }
        }
        return false
    }

    static func runtimeIdentitySummary() -> String {
        let bundleID = Bundle.main.bundleIdentifier ?? "<no.bundle.id>"
        let bundlePath = Bundle.main.bundleURL.path
        let executablePath = Bundle.main.executableURL?.path ?? CommandLine.arguments.first ?? "<unknown>"
        let pid = ProcessInfo.processInfo.processIdentifier
        return "pid=\(pid) bundleID=\(bundleID) bundlePath=\(bundlePath) executablePath=\(executablePath)"
    }

    func windows(for pid: pid_t) -> [AXUIElement] {
        let appElement = AXUIElementCreateApplication(pid)
        return copyAttribute(kAXWindowsAttribute as CFString, from: appElement) ?? []
    }

    func windowCount(for pid: pid_t) -> Int {
        windows(for: pid).count
    }

    private func copyAttribute<T>(_ attribute: CFString, from element: AXUIElement) -> T? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard error == .success, let cast = value as? T else {
            return nil
        }
        return cast
    }
}
