import AppKit

@MainActor
final class AppCoordinator {
    enum LaunchSource: String {
        case loginItem
        case nonLogin
        case unknown
    }

    private enum DefaultsKey {
        static let gracePeriodSeconds = "gracePeriodSeconds"
        static let statusItemHidden = "statusItemHidden"
    }

    private let engine = AutoQuitEngine()
    private let statusController = StatusMenuController()
    private let logger = AppLogger.shared
    private let loginItemManager = LoginItemManager()
    private let defaults = UserDefaults.standard

    func start(launchSource: LaunchSource) {
        applyPersistedSettings()
        applyStatusItemVisibilityOnLaunch(launchSource: launchSource)
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
        statusController.onSupportDev = { [weak self] in self?.openSupportLink() }
        statusController.onHideAutoQuit = { [weak self] in self?.handleHideAutoQuit() }
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

    private func applyStatusItemVisibilityOnLaunch(launchSource: LaunchSource) {
        let persistedHidden = defaults.bool(forKey: DefaultsKey.statusItemHidden)
        logger.log(
            component: "Startup",
            message: "Launch visibility decision launchSource=\(launchSource.rawValue) persistedHidden=\(persistedHidden)"
        )

        if launchSource == .nonLogin {
            defaults.set(false, forKey: DefaultsKey.statusItemHidden)
            statusController.setStatusItemHidden(false)
            logger.log(component: "Startup", message: "Cleared persisted hidden flag for non-login launch")
            return
        }

        statusController.setStatusItemHidden(persistedHidden)
        if launchSource == .loginItem {
            logger.log(component: "Startup", message: "Applied status item hidden=\(persistedHidden) for login launch")
            return
        }
        logger.log(component: "Startup", message: "Launch source unknown; preserved persisted hidden=\(persistedHidden)")
    }

    private func handleHideAutoQuit() {
        defaults.set(true, forKey: DefaultsKey.statusItemHidden)
        statusController.setStatusItemHidden(true)
        logger.log(component: "Startup", message: "Hide action selected; persisted hidden flag set to true")
    }

    func restoreStatusItemIfHidden() {
        guard defaults.bool(forKey: DefaultsKey.statusItemHidden) else {
            logger.log(component: "Startup", message: "Reopen requested; no hidden status item to restore")
            return
        }
        defaults.set(false, forKey: DefaultsKey.statusItemHidden)
        statusController.setStatusItemHidden(false)
        logger.log(component: "Startup", message: "Reopen requested; restored hidden status item and cleared flag")
        renderMenu()
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
            launchAtLoginState: loginItemManager.state
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

    private func openSupportLink() {
        guard let url = URL(string: "https://ko-fi.com/vikng") else { return }
        _ = NSWorkspace.shared.open(url)
    }
}
