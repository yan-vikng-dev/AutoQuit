import AppKit

@MainActor
final class StatusMenuController {
    var onToggleEnabled: (() -> Void)?
    var onToggleLogging: (() -> Void)?
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
    private let permissionItem = NSMenuItem()
    private let moreItem = NSMenuItem()
    private let moreMenu = NSMenu()
    private let showPermissionsItem = NSMenuItem()

    init() {
        if let button = statusItem.button {
            applyMenuIcon(isEnabled: true)
            button.toolTip = "AutoQuit"
        }

        enabledItem.target = self
        enabledItem.action = #selector(toggleEnabled)
        menu.addItem(enabledItem)

        loggingItem.target = self
        loggingItem.action = #selector(toggleLogging)
        menu.addItem(loggingItem)

        openLogItem.title = "Open Log File"
        openLogItem.target = self
        openLogItem.action = #selector(openLogFile)
        menu.addItem(openLogItem)

        permissionItem.title = "Grant Accessibility Permission"
        permissionItem.target = self
        permissionItem.action = #selector(grantAccessibility)
        menu.addItem(permissionItem)

        moreItem.title = "More"
        showPermissionsItem.title = "Show Permissions"
        showPermissionsItem.target = self
        showPermissionsItem.action = #selector(showPermissions)
        moreMenu.addItem(showPermissionsItem)
        moreItem.submenu = moreMenu
        menu.addItem(moreItem)

        graceItem.isEnabled = false
        menu.addItem(graceItem)
        menu.addItem(.separator())

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit AutoQuit", action: #selector(quitAutoQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    func render(isEnabled: Bool, gracePeriod: TimeInterval, isLoggingEnabled: Bool, isAccessibilityTrusted: Bool) {
        enabledItem.title = isEnabled ? "Disable AutoQuit" : "Enable AutoQuit"
        loggingItem.title = isLoggingEnabled ? "Disable File Logging" : "Enable File Logging"
        openLogItem.isHidden = !isLoggingEnabled
        permissionItem.isHidden = isAccessibilityTrusted
        moreItem.isHidden = !isAccessibilityTrusted
        graceItem.title = "Grace Period: \(Int(gracePeriod))s"
        applyMenuIcon(isEnabled: isEnabled)
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
