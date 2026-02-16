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
        configureEngine()
        bootstrapAccessibilityPermission()
        bindStatusActions()

        renderMenu()
        engine.start()
    }

    private func configureEngine() {
        engine.debugLoggingEnabled = logger.isEnabled
        engine.isEnabled = engine.isAccessibilityTrusted
        engine.onAccessibilityTrustChanged = { [weak self] trusted in
            guard let self else { return }
            let message: String
            if trusted {
                self.engine.isEnabled = true
                message = "Accessibility granted; AutoQuit enabled"
            } else {
                self.engine.isEnabled = false
                message = "Accessibility revoked; AutoQuit disabled"
            }
            self.logger.log(component: "Startup", message: message)
            self.renderMenu()
        }
    }

    private func bindStatusActions() {
        statusController.onToggleEnabled = { [weak self] in self?.handleToggleEnabled() }
        statusController.onToggleLogging = { [weak self] in self?.handleToggleLogging() }
        statusController.onSetGracePeriod = { [weak self] seconds in self?.handleSetGracePeriod(seconds) }
        statusController.onToggleLaunchAtLogin = { [weak self] in self?.handleToggleLaunchAtLogin() }
        statusController.onOpenLogFile = { [weak self] in self?.logger.openLogFile() }
        statusController.onClearLogFile = { [weak self] in self?.logger.clearLogFile() }
        statusController.onGrantAccessibility = { AccessibilityInspector.promptForAccessibilityTrust() }
        statusController.onShowPermissions = { _ = AccessibilityInspector.openAccessibilitySettings() }
        statusController.onQuitAutoQuit = { NSApp.terminate(nil) }
    }

    private func handleToggleEnabled() {
        if engine.isEnabled {
            engine.isEnabled = false
            renderMenu()
            return
        }
        guard engine.isAccessibilityTrusted else {
            showAccessibilityRequiredAlert()
            renderMenu()
            return
        }
        engine.isEnabled = true
        renderMenu()
    }

    private func handleToggleLogging() {
        logger.setEnabled(!logger.isEnabled)
        engine.debugLoggingEnabled = logger.isEnabled
        renderMenu()
    }

    private func handleSetGracePeriod(_ seconds: TimeInterval) {
        engine.setGracePeriod(seconds: seconds)
        defaults.set(seconds, forKey: DefaultsKey.gracePeriodSeconds)
        renderMenu()
    }

    private func handleToggleLaunchAtLogin() {
        do {
            try loginItemManager.toggle()
        } catch {
            showLaunchAtLoginErrorAlert(error: error)
        }
        if loginItemManager.state == .requiresApproval {
            showLaunchAtLoginApprovalAlert()
        }
        renderMenu()
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
        statusController.render(
            isEnabled: engine.isEnabled,
            gracePeriod: engine.gracePeriodSeconds,
            isLoggingEnabled: logger.isEnabled,
            isAccessibilityTrusted: engine.isAccessibilityTrusted,
            launchAtLoginState: launchAtLoginMenuState
        )
    }

    private var launchAtLoginMenuState: StatusMenuController.LaunchAtLoginState {
        switch loginItemManager.state {
        case .on:
            return .on
        case .off:
            return .off
        case .requiresApproval:
            return .requiresApproval
        case .unavailable:
            return .unavailable
        }
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
