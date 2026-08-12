import Foundation
import ServiceManagement

enum LoginItem {
    /// Registers the app to start at login. Skipped when running out of the
    /// build directory, so development runs never install a login item that
    /// points at a path that will be deleted.
    static func ensureRegistered() {
        guard Bundle.main.bundleURL.path().contains("/Applications/") else { return }

        let service = SMAppService.mainApp
        switch service.status {
        case .enabled:
            return
        case .requiresApproval:
            Log.warn("login item needs approval in System Settings > General > Login Items")
        case .notRegistered, .notFound:
            do {
                try service.register()
                Log.info("registered as a login item")
            } catch {
                Log.warn("could not register login item: \(error.localizedDescription)")
            }
        @unknown default:
            return
        }
    }
}
