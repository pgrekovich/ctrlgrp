import Testing
import CtrlgrpCore

/// Pins the "is this bundle path an installed location" predicate. This is
/// the third attempt at this guard: a `.contains` substring check
/// false-matched `~/Applications/...`, and a dead equality check against
/// `deletingLastPathComponent()` (which keeps the trailing slash) never
/// matched a real install either. Neither defect was ever exercised, because
/// running the guard for real would register a real login item. These tests
/// are the mechanical evidence that was missing.
@Test func installedAppInApplicationsIsInstalled() {
    #expect(isInstalledLocation(bundlePath: "/Applications/ctrlgrp.app"))
}

@Test func installedAppInApplicationsSubfolderIsInstalled() {
    // macOS genuinely allows app subfolders under /Applications.
    #expect(isInstalledLocation(bundlePath: "/Applications/Utilities/ctrlgrp.app"))
}

@Test func repoCheckoutIsNotInstalled() {
    #expect(!isInstalledLocation(bundlePath: "/Users/pgrekovich/Projects/lab/ctrlgrp/ctrlgrp.app"))
}

@Test func homeDirectoryNamedApplicationsIsNotInstalled() {
    // Pins the original substring bug: "/Users/x/Applications/..." contains
    // "/Applications" but is not under the real /Applications.
    #expect(!isInstalledLocation(bundlePath: "/Users/x/Applications/dev/ctrlgrp.app"))
}

@Test func bareApplicationsDirectoryIsNotInstalled() {
    #expect(!isInstalledLocation(bundlePath: "/Applications"))
}

@Test func emptyPathIsNotInstalled() {
    #expect(!isInstalledLocation(bundlePath: ""))
}
