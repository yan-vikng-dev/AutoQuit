import AppKit

@MainActor
final class StatusMenuController {
    private enum MenuItemTag: Int {
        case toggleEnabled
        case toggleLaunchAtLogin
        case grantAccessibility
        case showPermissions
        case toggleLogging
        case openLogFile
        case clearLogFile
        case hide
        case quit
    }

    var onToggleEnabled: (() -> Void)?
    var onToggleLogging: (() -> Void)?
    var onSetGracePeriod: ((TimeInterval) -> Void)?
    var onToggleLaunchAtLogin: (() -> Void)?
    var onOpenLogFile: (() -> Void)?
    var onClearLogFile: (() -> Void)?
    var onGrantAccessibility: (() -> Void)?
    var onShowPermissions: (() -> Void)?
    var onHideAutoQuit: (() -> Void)?
    var onQuitAutoQuit: (() -> Void)?

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let enabledItem = NSMenuItem()
    private let loggingItem = NSMenuItem()
    private let openLogItem = NSMenuItem()
    private let clearLogItem = NSMenuItem()
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
            button.target = self
            button.action = #selector(handleStatusItemClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        configureMenuItem(enabledItem, title: "AutoQuit Enabled", tag: .toggleEnabled)
        menu.addItem(enabledItem)

        configureMenuItem(launchAtLoginItem, title: "Launch at Login Enabled", tag: .toggleLaunchAtLogin)
        menu.addItem(launchAtLoginItem)

        configureMenuItem(permissionItem, title: "Grant Accessibility Permission", tag: .grantAccessibility)
        menu.addItem(permissionItem)

        graceItem.title = "Grace Period"
        configureGraceMenu()
        graceItem.submenu = graceMenu
        menu.addItem(graceItem)

        moreItem.title = "More"
        configureMenuItem(showPermissionsItem, title: "Show Permissions", tag: .showPermissions)
        moreMenu.addItem(showPermissionsItem)
        moreMenu.addItem(.separator())

        configureMenuItem(loggingItem, title: "File Logging", tag: .toggleLogging)
        moreMenu.addItem(loggingItem)

        configureMenuItem(openLogItem, title: "Open Log File", tag: .openLogFile)
        moreMenu.addItem(openLogItem)

        configureMenuItem(clearLogItem, title: "Clear Log File", tag: .clearLogFile)
        moreMenu.addItem(clearLogItem)
        moreItem.submenu = moreMenu
        menu.addItem(moreItem)

        menu.addItem(.separator())

        let hideItem = NSMenuItem()
        configureMenuItem(hideItem, title: "Hide AutoQuit", tag: .hide)
        menu.addItem(hideItem)

        let quitItem = NSMenuItem()
        configureMenuItem(quitItem, title: "Quit AutoQuit", tag: .quit, keyEquivalent: "q")
        menu.addItem(quitItem)
    }

    func render(
        isEnabled: Bool,
        gracePeriod: TimeInterval,
        isLoggingEnabled: Bool,
        isAccessibilityTrusted: Bool,
        launchAtLoginState: LoginItemManager.State
    ) {
        enabledItem.title = isEnabled ? "AutoQuit Enabled" : "Enable AutoQuit"
        enabledItem.state = isEnabled ? .on : .off
        loggingItem.state = isLoggingEnabled ? .on : .off
        openLogItem.isEnabled = isLoggingEnabled
        clearLogItem.isEnabled = isLoggingEnabled
        permissionItem.isHidden = isAccessibilityTrusted
        showPermissionsItem.isHidden = !isAccessibilityTrusted
        graceItem.title = "Grace Period (\(Int(gracePeriod))s)"
        applyGraceSelection(gracePeriod: gracePeriod)
        applyLaunchAtLoginState(launchAtLoginState)
        applyMenuIcon(isEnabled: isEnabled)
    }

    func setStatusItemHidden(_ hidden: Bool) {
        statusItem.isVisible = !hidden
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

    private func applyLaunchAtLoginState(_ state: LoginItemManager.State) {
        let presentation: (title: String, state: NSControl.StateValue, enabled: Bool)
        switch state {
        case .on:
            presentation = ("Launch at Login Enabled", .on, true)
        case .off:
            presentation = ("Enable Launch at Login", .off, true)
        case .requiresApproval:
            presentation = ("Launch at Login Enabled (Approval Needed)", .mixed, true)
        case .unavailable:
            presentation = ("Launch at Login (Unavailable)", .off, false)
        }
        launchAtLoginItem.title = presentation.title
        launchAtLoginItem.state = presentation.state
        launchAtLoginItem.isEnabled = presentation.enabled
    }

    private func configureMenuItem(_ item: NSMenuItem, title: String, tag: MenuItemTag, keyEquivalent: String = "") {
        item.title = title
        item.tag = tag.rawValue
        item.target = self
        item.action = #selector(handleMenuItem(_:))
        item.keyEquivalent = keyEquivalent
    }

    @objc private func handleMenuItem(_ sender: NSMenuItem) {
        guard let tag = MenuItemTag(rawValue: sender.tag) else { return }
        switch tag {
        case .toggleEnabled:
            onToggleEnabled?()
        case .toggleLaunchAtLogin:
            onToggleLaunchAtLogin?()
        case .grantAccessibility:
            onGrantAccessibility?()
        case .showPermissions:
            onShowPermissions?()
        case .toggleLogging:
            onToggleLogging?()
        case .openLogFile:
            onOpenLogFile?()
        case .clearLogFile:
            onClearLogFile?()
        case .hide:
            onHideAutoQuit?()
        case .quit:
            onQuitAutoQuit?()
        }
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            showMenu(from: sender)
            return
        }

        let isRightClick = event.type == .rightMouseUp || (event.type == .leftMouseUp && event.modifierFlags.contains(.control))
        if isRightClick {
            onToggleEnabled?()
            return
        }

        showMenu(from: sender)
    }

    private func showMenu(from sender: NSStatusBarButton) {
        let menuPoint = NSPoint(x: 0, y: sender.bounds.minY - 4)
        menu.popUp(positioning: nil, at: menuPoint, in: sender)
    }

    @objc private func selectGracePeriod(_ sender: NSMenuItem) {
        onSetGracePeriod?(TimeInterval(sender.tag))
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
