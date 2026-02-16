import AppKit

@MainActor
final class AppCoordinator {
    private let engine = AutoQuitEngine()
    private let statusController = StatusMenuController()
    private let logger = AppLogger.shared

    func start() {
        engine.debugLoggingEnabled = logger.isEnabled
        engine.isEnabled = engine.isAccessibilityTrusted
        engine.onAccessibilityTrustChanged = { [weak self] trusted in
            guard let self else { return }
            if trusted {
                self.engine.isEnabled = true
                self.logger.log(component: "Startup", message: "Accessibility granted; AutoQuit enabled")
            } else {
                self.engine.isEnabled = false
                self.logger.log(component: "Startup", message: "Accessibility revoked; AutoQuit disabled")
            }
            self.renderMenu()
        }
        bootstrapAccessibilityPermission()

        statusController.onToggleEnabled = { [weak self] in
            guard let self else { return }
            if self.engine.isEnabled {
                self.engine.isEnabled = false
                self.renderMenu()
                return
            }
            guard self.engine.isAccessibilityTrusted else {
                self.showAccessibilityRequiredAlert()
                self.renderMenu()
                return
            }
            self.engine.isEnabled = true
            self.renderMenu()
        }
        statusController.onToggleLogging = { [weak self] in
            guard let self else { return }
            self.logger.setEnabled(!self.logger.isEnabled)
            self.engine.debugLoggingEnabled = self.logger.isEnabled
            self.renderMenu()
        }
        statusController.onOpenLogFile = { [weak self] in
            guard let self else { return }
            self.logger.openLogFile()
        }
        statusController.onGrantAccessibility = {
            AccessibilityInspector.promptForAccessibilityTrust()
        }
        statusController.onShowPermissions = {
            _ = AccessibilityInspector.openAccessibilitySettings()
        }
        statusController.onQuitAutoQuit = {
            NSApp.terminate(nil)
        }

        renderMenu()
        engine.start()
    }

    private func bootstrapAccessibilityPermission() {
        logger.log(component: "Startup", message: AccessibilityInspector.runtimeIdentitySummary())
        let inspector = AccessibilityInspector()
        let trusted = inspector.hasAccessibilityTrust
        logger.log(component: "Startup", message: "AX trusted=\(trusted)")
        if !trusted {
            logger.log(component: "Startup", message: "Prompting for Accessibility permission")
            AccessibilityInspector.promptForAccessibilityTrust()
        }
    }

    private func renderMenu() {
        statusController.render(
            isEnabled: engine.isEnabled,
            gracePeriod: engine.gracePeriodSeconds,
            isLoggingEnabled: logger.isEnabled,
            isAccessibilityTrusted: engine.isAccessibilityTrusted
        )
    }

    private func showAccessibilityRequiredAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "Enable Accessibility permission before turning on AutoQuit."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Permissions")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            AccessibilityInspector.promptForAccessibilityTrust()
            _ = AccessibilityInspector.openAccessibilitySettings()
        }
    }
}
