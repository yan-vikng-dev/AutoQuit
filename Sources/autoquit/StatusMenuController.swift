import AppKit

@MainActor
final class StatusMenuController {
    enum LaunchAtLoginState {
        case on
        case off
        case requiresApproval
        case unavailable
    }

    var onToggleEnabled: (() -> Void)?
    var onToggleLogging: (() -> Void)?
    var onSetGracePeriod: ((TimeInterval) -> Void)?
    var onToggleLaunchAtLogin: (() -> Void)?
    var onOpenLogFile: (() -> Void)?
    var onGrantAccessibility: (() -> Void)?
    var onShowPermissions: (() -> Void)?
    var onQuitAutoQuit: (() -> Void)?

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let enabledItem = NSMenuItem()
    private let loggingItem = NSMenuItem()
    private let openLogItem = NSMenuItem()
    private let graceItem = NSMenuItem()
    private let graceMenu = NSMenu()
    private let gracePresets: [Int] = [0, 1, 3, 5, 10, 30]
    private var graceOptionItems: [NSMenuItem] = []
    private let permissionItem = NSMenuItem()
    private let moreItem = NSMenuItem()
    private let moreMenu = NSMenu()
    private let launchAtLoginItem = NSMenuItem()
    private let showPermissionsItem = NSMenuItem()

    init() {
        if let button = statusItem.button {
            applyMenuIcon(isEnabled: true)
            button.toolTip = "AutoQuit"
        }

        enabledItem.target = self
        enabledItem.action = #selector(toggleEnabled)
        enabledItem.title = "AutoQuit Enabled"
        menu.addItem(enabledItem)

        permissionItem.title = "Grant Accessibility Permission"
        permissionItem.target = self
        permissionItem.action = #selector(grantAccessibility)
        menu.addItem(permissionItem)

        graceItem.title = "Grace Period"
        configureGraceMenu()
        graceItem.submenu = graceMenu
        menu.addItem(graceItem)

        moreItem.title = "More"

        launchAtLoginItem.title = "Launch at Login"
        launchAtLoginItem.target = self
        launchAtLoginItem.action = #selector(toggleLaunchAtLogin)
        moreMenu.addItem(launchAtLoginItem)

        moreMenu.addItem(.separator())

        loggingItem.title = "File Logging"
        loggingItem.target = self
        loggingItem.action = #selector(toggleLogging)
        moreMenu.addItem(loggingItem)

        openLogItem.title = "Open Log File"
        openLogItem.target = self
        openLogItem.action = #selector(openLogFile)
        moreMenu.addItem(openLogItem)
        moreMenu.addItem(.separator())

        showPermissionsItem.title = "Show Permissions"
        showPermissionsItem.target = self
        showPermissionsItem.action = #selector(showPermissions)
        moreMenu.addItem(showPermissionsItem)
        moreItem.submenu = moreMenu
        menu.addItem(moreItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit AutoQuit", action: #selector(quitAutoQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    func render(
        isEnabled: Bool,
        gracePeriod: TimeInterval,
        isLoggingEnabled: Bool,
        isAccessibilityTrusted: Bool,
        launchAtLoginState: LaunchAtLoginState
    ) {
        enabledItem.title = isEnabled ? "AutoQuit Enabled" : "Enable AutoQuit"
        enabledItem.state = isEnabled ? .on : .off
        loggingItem.state = isLoggingEnabled ? .on : .off
        openLogItem.isEnabled = isLoggingEnabled
        permissionItem.isHidden = isAccessibilityTrusted
        showPermissionsItem.isHidden = !isAccessibilityTrusted
        graceItem.title = "Grace Period (\(Int(gracePeriod))s)"
        applyGraceSelection(gracePeriod: gracePeriod)
        applyLaunchAtLoginState(launchAtLoginState)
        applyMenuIcon(isEnabled: isEnabled)
    }

    private func configureGraceMenu() {
        graceOptionItems = gracePresets.map { seconds in
            let item = NSMenuItem(title: "\(seconds)s", action: #selector(selectGracePeriod(_:)), keyEquivalent: "")
            item.target = self
            item.tag = seconds
            graceMenu.addItem(item)
            return item
        }
    }

    private func applyGraceSelection(gracePeriod: TimeInterval) {
        let roundedGrace = Int(gracePeriod.rounded())
        for item in graceOptionItems {
            item.state = (item.tag == roundedGrace) ? .on : .off
        }
    }

    private func applyLaunchAtLoginState(_ state: LaunchAtLoginState) {
        switch state {
        case .on:
            launchAtLoginItem.title = "Launch at Login"
            launchAtLoginItem.state = .on
            launchAtLoginItem.isEnabled = true
        case .off:
            launchAtLoginItem.title = "Launch at Login"
            launchAtLoginItem.state = .off
            launchAtLoginItem.isEnabled = true
        case .requiresApproval:
            launchAtLoginItem.title = "Launch at Login (Approval Needed)"
            launchAtLoginItem.state = .mixed
            launchAtLoginItem.isEnabled = true
        case .unavailable:
            launchAtLoginItem.title = "Launch at Login (Unavailable)"
            launchAtLoginItem.state = .off
            launchAtLoginItem.isEnabled = false
        }
    }

    @objc private func toggleEnabled() {
        onToggleEnabled?()
    }

    @objc private func grantAccessibility() {
        onGrantAccessibility?()
    }

    @objc private func showPermissions() {
        onShowPermissions?()
    }

    @objc private func toggleLogging() {
        onToggleLogging?()
    }

    @objc private func selectGracePeriod(_ sender: NSMenuItem) {
        onSetGracePeriod?(TimeInterval(sender.tag))
    }

    @objc private func toggleLaunchAtLogin() {
        onToggleLaunchAtLogin?()
    }

    @objc private func openLogFile() {
        onOpenLogFile?()
    }

    @objc private func quitAutoQuit() {
        onQuitAutoQuit?()
    }

    private func applyMenuIcon(isEnabled: Bool) {
        guard let button = statusItem.button else { return }

        let name = isEnabled ? "MenuIconEnabled" : "MenuIconDisabled"
        let menuIconURL = Bundle.main.url(forResource: name, withExtension: "png")
        if let menuIconURL, let image = NSImage(contentsOf: menuIconURL) {
            image.isTemplate = false
            let targetHeight: CGFloat = 16
            let aspect = max(image.size.width, 1) / max(image.size.height, 1)
            image.size = NSSize(width: targetHeight * aspect, height: targetHeight)
            button.image = image
            button.imageScaling = .scaleProportionallyUpOrDown
            return
        }

        button.image = NSImage(systemSymbolName: "rectangle.stack.badge.minus", accessibilityDescription: "AutoQuit")
        button.image?.isTemplate = true
    }
}
