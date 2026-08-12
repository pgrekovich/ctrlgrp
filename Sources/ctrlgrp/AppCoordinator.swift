import AppKit
import CtrlgrpCore

/// Owns the app's state and wires the pieces together.
@MainActor
final class AppCoordinator {
    private let bindings: Bindings
    private let tracker = FrontmostTracker()
    private let activator = AppActivator()
    private let hudEnabled: Bool
    private var hotkeys: HotkeyManager?

    init() {
        let loaded = Config.load(from: Config.defaultURL)
        for warning in loaded.warnings { Log.warn(warning) }
        bindings = Bindings(defaults: loaded.config.defaults)
        hudEnabled = loaded.config.hudEnabled
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
    }

    private func handle(_ trigger: HotkeyManager.Trigger) {
        switch trigger {
        case .focus(let slot):
            let situation = activator.situation(
                target: bindings.effective(slot),
                previous: tracker.previous
            )
            activator.perform(decideSwitch(situation))
        case .bind:
            break // Task 8
        case .toggleHUD:
            break // Task 10
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
                let bundleID = app.bundleIdentifier
            else { return }

            MainActor.assumeIsolated {
                self?.tracker.didActivate(bundleID)
            }
        }
    }
}
