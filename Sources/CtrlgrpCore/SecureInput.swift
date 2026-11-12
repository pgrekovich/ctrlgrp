import Foundation

/// Secure Event Input is the system-wide mode a password field turns on so
/// other processes cannot read keystrokes. While it is on, macOS also stops
/// delivering global hotkeys whose only modifiers are option or option+shift
/// on keys that type a character, which is every hotkey ctrlgrp registers.
/// The usual culprit is not an app at all: after a screen unlock, loginwindow
/// can leave the mode switched on until the next logout.
public struct SecureInputHolder: Equatable, Sendable {
    public var pid: Int32
    /// What the process calls itself, when it could be resolved.
    public var name: String?

    public init(pid: Int32, name: String?) {
        self.pid = pid
        self.name = name
    }
}

/// Whether Secure Input is on, and who holds it when the registry says.
public enum SecureInputState: Equatable, Sendable {
    case off
    case on(holder: SecureInputHolder?)
}

/// Finds which process holds Secure Input for the given user, from the
/// `IOConsoleUsers` array on the IORegistry root. Each entry is one login
/// session, and the pid key is present only where the mode is on. Fast user
/// switching leaves several entries around, so the match is on the user id
/// rather than on whichever entry comes first.
public func secureInputHolderPID(consoleUsers: [[String: Any]], uid: UInt32) -> Int32? {
    for session in consoleUsers {
        guard let sessionUID = session["kCGSSessionUserIDKey"] as? Int,
              sessionUID == Int(uid),
              let pid = session["kCGSSessionSecureInputPID"] as? Int,
              pid > 0
        else { continue }
        return Int32(pid)
    }
    return nil
}

/// The warning shown while Secure Input is on: what is broken, then what
/// clears it, as two lines so the menu can show them separately.
public func secureInputWarning(holder: SecureInputHolder?) -> (headline: String, remedy: String) {
    let headline = "Hotkeys blocked by Secure Input"
    guard let holder else {
        return (headline, "Held by an unknown process")
    }
    if holder.name == "loginwindow" {
        // Locking again does not help: each lock stacks more enables than
        // the unlock removes. Only a fresh loginwindow resets it.
        return (headline, "Stuck in loginwindow: log out and back in")
    }
    let who = holder.name ?? "pid \(holder.pid)"
    return (headline, "Held by \(who): leave its password field or quit it")
}
