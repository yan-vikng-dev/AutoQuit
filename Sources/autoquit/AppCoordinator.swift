import AppKit

@MainActor
final class AppCoordinator {
    private enum DefaultsKey {
        static let gracePeriodSeconds = "gracePeriodSeconds"
    }

    private let engine = AutoQuitEngine()
    private let statusController = StatusMenuController()
    private let logger = AppLogger.shared
    private let loginItemManager = LoginItemManager()
    private let defaults = UserDefaults.standard

    func start() {
        applyPersistedSettings()
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
        statusController.onSetGracePeriod = { [weak self] seconds in
            guard let self else { return }
            self.engine.setGracePeriod(seconds: seconds)
            self.defaults.set(seconds, forKey: DefaultsKey.gracePeriodSeconds)
            self.renderMenu()
        }
        statusController.onToggleLaunchAtLogin = { [weak self] in
            guard let self else { return }
            do {
                try self.loginItemManager.toggle()
            } catch {
                self.showLaunchAtLoginErrorAlert(error: error)
            }
            if self.loginItemManager.state == .requiresApproval {
                self.showLaunchAtLoginApprovalAlert()
            }
            self.renderMenu()
        }
        statusController.onOpenLogFile = { [weak self] in
            guard let self else { return }
            self.logger.openLogFile()
        }
        statusController.onClearLogFile = { [weak self] in
            guard let self else { return }
            self.logger.clearLogFile()
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

    private func applyPersistedSettings() {
        guard defaults.object(forKey: DefaultsKey.gracePeriodSeconds) != nil else { return }
        let persistedGracePeriod = defaults.double(forKey: DefaultsKey.gracePeriodSeconds)
        engine.setGracePeriod(seconds: persistedGracePeriod)
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
        let launchAtLoginState: StatusMenuController.LaunchAtLoginState
        switch loginItemManager.state {
        case .on:
            launchAtLoginState = .on
        case .off:
            launchAtLoginState = .off
        case .requiresApproval:
            launchAtLoginState = .requiresApproval
        case .unavailable:
            launchAtLoginState = .unavailable
        }

        statusController.render(
            isEnabled: engine.isEnabled,
            gracePeriod: engine.gracePeriodSeconds,
            isLoggingEnabled: logger.isEnabled,
            isAccessibilityTrusted: engine.isAccessibilityTrusted,
            launchAtLoginState: launchAtLoginState
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

    private func showLaunchAtLoginApprovalAlert() {
        let alert = NSAlert()
        alert.messageText = "Approve Launch at Login"
        alert.informativeText = "AutoQuit is registered as a login item but still needs approval in System Settings."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Login Items")
        alert.addButton(withTitle: "Later")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            _ = loginItemManager.openLoginItemsSettings()
        }
    }

    private func showLaunchAtLoginErrorAlert(error: Error) {
        let nsError = error as NSError
        let alert = NSAlert()
        alert.messageText = "Could Not Update Launch at Login"
        alert.informativeText = nsError.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Open Login Items")
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            _ = loginItemManager.openLoginItemsSettings()
        }
    }
}
