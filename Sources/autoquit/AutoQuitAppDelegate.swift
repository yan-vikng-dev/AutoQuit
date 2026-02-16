import AppKit
import CoreServices

@MainActor
final class AutoQuitAppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: AppCoordinator?
    private var launchSource: AppCoordinator.LaunchSource = .unknown
    private let logger = AppLogger.shared

    func applicationWillFinishLaunching(_ notification: Notification) {
        launchSource = detectLaunchSource()
        logger.log(component: "Startup", message: "Launch source detected=\(launchSource.rawValue)")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        coordinator = AppCoordinator()
        coordinator?.start(launchSource: launchSource)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        coordinator?.restoreStatusItemIfHidden()
        return false
    }

    private func detectLaunchSource() -> AppCoordinator.LaunchSource {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else {
            logger.log(component: "Startup", message: "Launch source check: no current AppleEvent")
            return .unknown
        }
        guard event.eventID == AEEventID(kAEOpenApplication) else {
            logger.log(component: "Startup", message: "Launch source check: unexpected eventID=\(event.eventID)")
            return .unknown
        }
        guard let descriptor = event.paramDescriptor(forKeyword: AEKeyword(keyAEPropData)) else {
            logger.log(component: "Startup", message: "Launch source check: missing keyAEPropData descriptor")
            return .unknown
        }
        let isLoginItem = descriptor.enumCodeValue == AEKeyword(keyAELaunchedAsLogInItem)
        logger.log(
            component: "Startup",
            message: "Launch source check: keyAEPropData enumCodeValue=\(descriptor.enumCodeValue) loginItem=\(isLoginItem)"
        )
        return isLoginItem ? .loginItem : .nonLogin
    }
}
