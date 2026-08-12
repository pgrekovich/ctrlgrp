/// Whether a bundle path counts as an "installed" location, for features
/// that must only activate on a real, permanent install (currently: login
/// item registration). A pure string predicate on purpose: it must never
/// touch `Bundle`, `URL`, or the file system, because those cannot be driven
/// from a unit test without either mocking the bundle or actually installing
/// the app. This guard has already failed twice while looking correct by
/// eye (a substring check that matched `~/Applications/...`, then a dead
/// equality check against a path that still had its trailing slash), so it
/// is only allowed to change again with tests pinning the intended behavior.
public func isInstalledLocation(bundlePath: String) -> Bool {
    bundlePath.hasPrefix("/Applications/")
}
