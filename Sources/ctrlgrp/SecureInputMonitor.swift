import AppKit
import Carbon.HIToolbox
import CtrlgrpCore
import IOKit

/// Notices when Secure Input is on, so that hotkeys macOS silently stops
/// delivering show up as a reason instead of as nothing at all. A blocked
/// hotkey never reaches ctrlgrp, so the keypress itself cannot be the
/// trigger. Checks run at the moments the mode tends to get stuck (launch,
/// unlock, wake, returning to the session) and whenever the menu opens. No
/// timer: ctrlgrp stays at zero polling.
@MainActor
final class SecureInputMonitor {
    private(set) var state: SecureInputState = .off
    private let onChange: (SecureInputState) -> Void
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []

    init(onChange: @escaping (SecureInputState) -> Void) {
        self.onChange = onChange
    }

    func start() {
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.didWakeNotification)
        observe(workspace, NSWorkspace.sessionDidBecomeActiveNotification)
        // loginwindow posts this once the lock screen is gone. Its own
        // release of Secure Input lands a moment later, and checking before
        // that would report the healthy unlock itself as a stuck one.
        observe(DistributedNotificationCenter.default(), Notification.Name("com.apple.screenIsUnlocked"))
        check()
    }

    func check() {
        let next: SecureInputState = IsSecureEventInputEnabled() ? .on(holder: currentHolder()) : .off
        guard next != state else { return }
        state = next
        onChange(next)
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                MainActor.assumeIsolated { self?.check() }
            }
        }
        observers.append((center, token))
    }

    /// Reads the holder's pid from the IORegistry root, which needs no
    /// permission, then names it the way Activity Monitor would.
    private func currentHolder() -> SecureInputHolder? {
        let root = IORegistryGetRootEntry(kIOMainPortDefault)
        defer { IOObjectRelease(root) }
        guard
            let property = IORegistryEntryCreateCFProperty(
                root, "IOConsoleUsers" as CFString, kCFAllocatorDefault, 0
            )?.takeRetainedValue(),
            let users = property as? [[String: Any]],
            let pid = secureInputHolderPID(consoleUsers: users, uid: getuid())
        else { return nil }
        return SecureInputHolder(pid: pid, name: processName(pid))
    }

    private func processName(_ pid: Int32) -> String? {
        if let name = NSRunningApplication(processIdentifier: pid)?.localizedName {
            return name
        }
        var buffer = [CChar](repeating: 0, count: Int(MAXCOMLEN) + 1)
        guard proc_name(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }
}
