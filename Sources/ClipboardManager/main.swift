import AppKit

// Entry point: create the shared application, attach our delegate, and run.
let app      = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
