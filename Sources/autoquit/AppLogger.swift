import AppKit
import Foundation

final class AppLogger: @unchecked Sendable {
    static let shared = AppLogger()

    private let enabledKey = "AutoQuit.FileLoggingEnabled"
    private let queue = DispatchQueue(label: "dev.yan.autoquit.logger")
    private let stateQueue = DispatchQueue(label: "dev.yan.autoquit.logger.state")
    private let fileManager = FileManager.default

    private var _isEnabled: Bool
    var isEnabled: Bool {
        stateQueue.sync { _isEnabled }
    }

    private init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: enabledKey) == nil {
            defaults.set(true, forKey: enabledKey)
        }
        _isEnabled = defaults.bool(forKey: enabledKey)
    }

    func setEnabled(_ enabled: Bool) {
        stateQueue.sync {
            _isEnabled = enabled
        }
        UserDefaults.standard.set(enabled, forKey: enabledKey)
        if enabled {
            log(component: "Logger", message: "File logging enabled")
        }
    }

    func log(component: String, message: String) {
        guard stateQueue.sync(execute: { _isEnabled }) else { return }
        let line = "\(timestamp()) [\(component)] \(message)\n"
        queue.async { [weak self] in
            guard let self else { return }
            self.ensureLogDirectory()
            let url = self.logFileURL()
            if !self.fileManager.fileExists(atPath: url.path) {
                _ = self.fileManager.createFile(atPath: url.path, contents: nil)
            }
            if let data = line.data(using: .utf8),
               let handle = try? FileHandle(forWritingTo: url) {
                do {
                    try handle.seekToEnd()
                    try handle.write(contentsOf: data)
                    try handle.close()
                } catch {
                    try? handle.close()
                }
            }
        }
    }

    @MainActor
    func openLogFile() {
        ensureLogDirectory()
        let url = logFileURL()
        if !fileManager.fileExists(atPath: url.path) {
            _ = fileManager.createFile(atPath: url.path, contents: nil)
        }
        NSWorkspace.shared.open(url)
    }

    func clearLogFile() {
        queue.async { [weak self] in
            guard let self else { return }
            self.ensureLogDirectory()
            let url = self.logFileURL()
            do {
                try Data().write(to: url, options: .atomic)
            } catch {
                // Intentionally ignored; logging should never interrupt app flow.
            }
        }
    }

    private func timestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }

    private func ensureLogDirectory() {
        let dir = logDirectoryURL()
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    private func logDirectoryURL() -> URL {
        let base = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library")
        return base.appendingPathComponent("Logs/AutoQuit", isDirectory: true)
    }

    private func logFileURL() -> URL {
        logDirectoryURL().appendingPathComponent("autoquit.log")
    }
}
