import AppKit

let app = NSApplication.shared
// Accessory policy: no dock icon, no menu bar, never steals focus.
app.setActivationPolicy(.accessory)

let hotkeys = HotkeyManager { trigger in
    switch trigger {
    case .focus(let slot): Log.info("focus slot \(slot)")
    case .bind(let slot): Log.info("bind slot \(slot)")
    case .toggleHUD: Log.info("toggle hud")
    }
}

let failures = hotkeys.register(includeHUD: true)
if failures.isEmpty {
    Log.info("registered all hotkeys")
} else {
    Log.warn("could not register: \(failures.joined(separator: ", "))")
}

app.run()
