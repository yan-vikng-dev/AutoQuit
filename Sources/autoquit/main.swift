import AppKit

let app = NSApplication.shared
let delegate = AutoQuitAppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
