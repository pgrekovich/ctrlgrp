import AppKit
import CtrlgrpCore

/// Owns the app's state and wires the pieces together.
@MainActor
final class AppCoordinator {
    private let bindings: Bindings
    private let tracker = FrontmostTracker()
    private let activator = AppActivator()
    private let hudEnabled: Bool
    private let menuBarEnabled: Bool
    private var hotkeys: HotkeyManager?
    private var watcher: ConfigWatcher?
    private var statusItem: StatusItemController?
    private let hud = HUDPanel()

    init() {
        switch Config.load(from: Config.defaultURL) {
        case .parsed(let loaded):
            for warning in loaded.warnings { Log.warn(warning) }
            bindings = Bindings(defaults: loaded.config.defaults)
            hudEnabled = loaded.config.hudEnabled
            menuBarEnabled = loaded.config.menuBarEnabled
        case .unparsable(let warning):
            // Nothing to preserve yet: this is the first read of the process.
            Log.warn(warning)
            bindings = Bindings(defaults: Config.empty.defaults)
            hudEnabled = Config.empty.hudEnabled
            menuBarEnabled = Config.empty.menuBarEnabled
        }
    }

    func start() {
        observeFrontmostChanges()
        if let current = activator.frontmostBundleID {
            tracker.didActivate(current)
        }

        let hotkeys = HotkeyManager { [weak self] trigger in
            self?.handle(trigger)
        }
        let failures = hotkeys.register(includeHUD: hudEnabled)
        if failures.isEmpty {
            Log.info("ready, \(bindings.effectiveAll.count) slots bound")
        } else {
            Log.warn("could not register: \(failures.joined(separator: ", "))")
        }
        self.hotkeys = hotkeys

        let watcher = ConfigWatcher(url: Config.defaultURL) { [weak self] in
            self?.reloadConfig()
        }
        watcher.start()
        self.watcher = watcher

        // Like the HUD flag, read once at launch: a status item appearing and
        // vanishing on config edits would be more surprising than a restart.
        if menuBarEnabled {
            statusItem = StatusItemController(configURL: Config.defaultURL) { [weak self] in
                self?.reloadConfig()
            }
        }
    }

    private func reloadConfig() {
        switch Config.load(from: Config.defaultURL) {
        case .parsed(let loaded):
            for warning in loaded.warnings { Log.warn(warning) }
            // Session bindings outrank defaults and survive a reload by design.
            bindings.updateDefaults(loaded.config.defaults)
            Log.info("reloaded config, \(bindings.effectiveAll.count) slots bound")
            hud.refresh(bindings: bindings.effectiveAll)
        case .unparsable(let warning):
            // A half-saved edit must not unbind everything: keep whatever
            // defaults are already loaded and leave the HUD as it is. Logged
            // symmetrically with the success path so the log itself is
            // evidence that nothing was unbound.
            Log.warn(warning)
            Log.warn("keeping previous config, \(bindings.effectiveAll.count) slots still bound")
        }
    }

    private func handle(_ trigger: HotkeyManager.Trigger) {
        switch trigger {
        case .focus(let slot):
            let situation = activator.situation(
                target: bindings.effective(slot),
                previous: tracker.previous
            )
            activator.perform(decideSwitch(situation))
        case .bind(let slot):
            guard let bundleID = activator.frontmostBundleID else {
                Log.warn("no frontmost app to bind")
                return
            }
            // Binding ctrlgrp itself would produce a slot that can never come
            // forward, since the app has no windows.
            guard bundleID != Bundle.main.bundleIdentifier else { return }
            bindings.bind(bundleID, to: slot)
            Log.info("bound slot \(slot) to \(bundleID)")
            // Pop the HUD up rather than only refreshing an open one: seeing the
            // new binding land next to the existing ones IS the confirmation
            // that the keypress registered. Still gated by the config switch, so
            // hud.enabled false means never.
            if hudEnabled { hud.present(bindings: bindings.effectiveAll) }
        case .toggleHUD:
            hud.toggle(bindings: bindings.effectiveAll)
            // Logged because this path has no other observable: an invisible
            // panel and a hotkey that never fired look identical otherwise,
            // which is exactly how a zero-sized panel went unnoticed once.
            Log.info("hud toggled, now \(hud.isVisible ? "visible" : "hidden")")
        }
    }

    private func observeFrontmostChanges() {
        // Workspace notifications come from the workspace's own centre, not
        // the default one.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication,
                let bundleID = app.bundleIdentifier,
                // Never record ctrlgrp itself: with a menu bar item the app has
                // clickable UI, and if interacting with it ever counts as an
                // activation, "previous" would collapse onto ctrlgrp and
                // toggle-back would silently stop working.
                bundleID != Bundle.main.bundleIdentifier
            else { return }

            MainActor.assumeIsolated {
                self?.tracker.didActivate(bundleID)
            }
        }
    }
}
