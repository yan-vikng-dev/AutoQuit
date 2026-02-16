import AppKit
import ServiceManagement

@MainActor
final class LoginItemManager {
    enum State {
        case on
        case off
        case requiresApproval
        case unavailable
    }

    var state: State {
        switch SMAppService.mainApp.status {
        case .enabled:
            return .on
        case .notRegistered, .notFound:
            return .off
        case .requiresApproval:
            return .requiresApproval
        @unknown default:
            return .unavailable
        }
    }

    func toggle() throws {
        switch state {
        case .on, .requiresApproval:
            try SMAppService.mainApp.unregister()
        case .off, .unavailable:
            try SMAppService.mainApp.register()
        }
    }

    @discardableResult
    func openLoginItemsSettings() -> Bool {
        let urls = [
            "x-apple.systempreferences:com.apple.LoginItems-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.users?LoginItems"
        ]

        for value in urls {
            guard let url = URL(string: value) else { continue }
            if NSWorkspace.shared.open(url) {
                return true
            }
        }
        return false
    }
}
