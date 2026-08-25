import AppKit
import CtrlgrpCore

/// The AppKit side of switching: reads the state `decideSwitch` needs, then
/// carries out whatever it decided.
@MainActor
final class AppActivator {
    private let workspace = NSWorkspace.shared

    var frontmostBundleID: String? {
        workspace.frontmostApplication?.bundleIdentifier
    }

    func situation(target: String?, previous: String?, toggleBackEnabled: Bool) -> Situation {
        guard let target else {
            return Situation(
                target: nil,
                previous: previous,
                toggleBackEnabled: toggleBackEnabled
            )
        }
        let running = runningApp(target)
        return Situation(
            target: target,
            isTargetFrontmost: frontmostBundleID == target,
            isTargetRunning: running != nil,
            isTargetWindowless: running.map { !hasWindows($0) } ?? false,
            isTargetInstalled: workspace.urlForApplication(withBundleIdentifier: target) != nil,
            previous: previous,
            isPreviousRunning: previous.map { runningApp($0) != nil } ?? false,
            toggleBackEnabled: toggleBackEnabled
        )
    }

    func perform(_ action: SwitchAction) {
        switch action {
        case .doNothing:
            break
        case .activate(let bundleID):
            guard let app = runningApp(bundleID) else {
                // It quit between the decision and now; launching is the
                // closest thing to what the user asked for.
                launch(bundleID)
                return
            }
            if !app.activate() {
                Log.warn("could not activate \(bundleID)")
            }
        case .activateIfRunning(let bundleID):
            // No launch fallback here, deliberately: this is a toggle back, and
            // if the app quit in the meantime the user gets to stay put rather
            // than have it reappear.
            guard let app = runningApp(bundleID) else { return }
            if !app.activate() {
                Log.warn("could not activate \(bundleID)")
            }
        case .reopen(let bundleID):
            // Opening an already-running app through LaunchServices is what a
            // Dock click does: the app gets a reopen event and responds by
            // making a window. Plain activate() would only move focus.
            launch(bundleID)
        case .launch(let bundleID):
            launch(bundleID)
        case .appMissing(let bundleID):
            Log.warn("no application installed for \(bundleID)")
        }
    }

    private func runningApp(_ bundleID: String) -> NSRunningApplication? {
        workspace.runningApplications.first { $0.bundleIdentifier == bundleID }
    }

    /// Whether the app has a window the user could actually see after a plain
    /// activate. Only on-screen counts: apps keep phantom off-screen layer-0
    /// windows around (Chromium and Ghostty hold half a dozen with all windows
    /// closed), so "owns any window at all" is always true and useless.
    /// Minimized, hidden and other-Space windows are off-screen too and land
    /// on the reopen path, which treats them exactly like a Dock click:
    /// restore, unhide, or switch Spaces. Layer 0 excludes menu bar extras and
    /// overlays; the alpha check excludes invisible helper windows. Owner,
    /// layer and alpha come back without any permission (only window *names*
    /// need Screen Recording), so this keeps the zero-permissions promise.
    /// If the list is unavailable, assume windows exist and degrade to a
    /// plain activate.
    private func hasWindows(_ app: NSRunningApplication) -> Bool {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let infos = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]]
        else { return true }
        return infos.contains { info in
            info[kCGWindowOwnerPID as String] as? pid_t == app.processIdentifier
                && info[kCGWindowLayer as String] as? Int == 0
                && (info[kCGWindowAlpha as String] as? Double ?? 1) > 0
        }
    }

    private func launch(_ bundleID: String) {
        guard let url = workspace.urlForApplication(withBundleIdentifier: bundleID) else {
            Log.warn("no application installed for \(bundleID)")
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        workspace.openApplication(at: url, configuration: configuration) { _, error in
            if let error {
                Log.warn("could not launch \(bundleID): \(error.localizedDescription)")
            }
        }
    }
}
