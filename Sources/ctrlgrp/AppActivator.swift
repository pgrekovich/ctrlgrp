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

    func situation(target: String?, previous: String?) -> Situation {
        guard let target else {
            return Situation(target: nil, previous: previous)
        }
        return Situation(
            target: target,
            isTargetFrontmost: frontmostBundleID == target,
            isTargetRunning: runningApp(target) != nil,
            isTargetInstalled: workspace.urlForApplication(withBundleIdentifier: target) != nil,
            previous: previous
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
        case .launch(let bundleID):
            launch(bundleID)
        case .appMissing(let bundleID):
            Log.warn("no application installed for \(bundleID)")
        }
    }

    private func runningApp(_ bundleID: String) -> NSRunningApplication? {
        workspace.runningApplications.first { $0.bundleIdentifier == bundleID }
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
