/// Remembers which app was frontmost before the current one, which is what
/// pressing an already-focused slot toggles back to.
@MainActor
public final class FrontmostTracker {
    public private(set) var current: String?
    public private(set) var previous: String?

    public init(current: String? = nil) {
        self.current = current
    }

    /// Feed every frontmost change. Repeats of the current app are ignored so
    /// `previous` always names a genuinely different app, which keeps
    /// toggle-back from degenerating into a no-op.
    public func didActivate(_ bundleID: String) {
        guard bundleID != current else { return }
        previous = current
        current = bundleID
    }
}
