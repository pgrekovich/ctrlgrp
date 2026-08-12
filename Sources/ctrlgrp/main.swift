import AppKit

let app = NSApplication.shared
// Accessory policy: no dock icon, no menu bar, never steals focus.
app.setActivationPolicy(.accessory)

let coordinator = AppCoordinator()
coordinator.start()

app.run()
