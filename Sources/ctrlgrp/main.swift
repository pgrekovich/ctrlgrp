import AppKit

let app = NSApplication.shared
// Accessory policy: no dock icon, no menu bar, never steals focus.
app.setActivationPolicy(.accessory)
LoginItem.ensureRegistered()

let coordinator = AppCoordinator()
coordinator.start()

app.run()
