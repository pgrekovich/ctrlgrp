import Foundation
import Testing
import CtrlgrpCore

@Test func noHolderWhenNoSessionHasSecureInput() {
    let users: [[String: Any]] = [
        ["kCGSSessionUserIDKey": 501, "kCGSSessionOnConsoleKey": true],
    ]
    #expect(secureInputHolderPID(consoleUsers: users, uid: 501) == nil)
}

@Test func findsTheHolderInTheCurrentUsersSession() {
    let users: [[String: Any]] = [
        ["kCGSSessionUserIDKey": 501, "kCGSSessionSecureInputPID": 408],
    ]
    #expect(secureInputHolderPID(consoleUsers: users, uid: 501) == 408)
}

@Test func ignoresAnotherUsersSession() {
    // Fast user switching: the other user's password field is not ours to
    // report, and it does not block our hotkeys.
    let users: [[String: Any]] = [
        ["kCGSSessionUserIDKey": 502, "kCGSSessionSecureInputPID": 777],
        ["kCGSSessionUserIDKey": 501],
    ]
    #expect(secureInputHolderPID(consoleUsers: users, uid: 501) == nil)
}

@Test func readsRegistryNumbersAsTheyActuallyArrive() {
    // IORegistry hands back NSNumber, not Swift Int.
    let users: [[String: Any]] = [
        [
            "kCGSSessionUserIDKey": NSNumber(value: 501),
            "kCGSSessionSecureInputPID": NSNumber(value: 408),
        ],
    ]
    #expect(secureInputHolderPID(consoleUsers: users, uid: 501) == 408)
}

@Test func stuckLoginWindowTellsTheUserToLogOut() {
    let warning = secureInputWarning(holder: SecureInputHolder(pid: 408, name: "loginwindow"))
    #expect(warning.headline == "Hotkeys blocked by Secure Input")
    #expect(warning.remedy == "Stuck in loginwindow: log out and back in")
}

@Test func appHolderIsNamed() {
    let warning = secureInputWarning(holder: SecureInputHolder(pid: 1433, name: "1Password"))
    #expect(warning.remedy == "Held by 1Password: leave its password field or quit it")
}

@Test func unnamedHolderFallsBackToThePid() {
    let warning = secureInputWarning(holder: SecureInputHolder(pid: 1433, name: nil))
    #expect(warning.remedy == "Held by pid 1433: leave its password field or quit it")
}

@Test func unknownHolderStillWarns() {
    let warning = secureInputWarning(holder: nil)
    #expect(warning.headline == "Hotkeys blocked by Secure Input")
    #expect(warning.remedy == "Held by an unknown process")
}
