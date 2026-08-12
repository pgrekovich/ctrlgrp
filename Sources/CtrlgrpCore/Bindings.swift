/// The two-layer binding model.
///
/// `defaults` come from the config file and survive reboots. The session
/// overlay comes from option+shift+N and is deliberately never persisted: a
/// restart returns to the hand-written defaults, the way a new RTS match
/// starts with fresh control groups.
@MainActor
public final class Bindings {
    private var defaults: [Slot: String]
    private var session: [Slot: String] = [:]

    public init(defaults: [Slot: String] = [:]) {
        self.defaults = defaults
    }

    /// Applies a reloaded config. Session bindings outrank defaults and must
    /// survive a config reload, so they are left untouched here.
    public func updateDefaults(_ newDefaults: [Slot: String]) {
        defaults = newDefaults
    }

    public func bind(_ bundleID: String, to slot: Slot) {
        session[slot] = bundleID
    }

    public func effective(_ slot: Slot) -> String? {
        session[slot] ?? defaults[slot]
    }

    public var effectiveAll: [Slot: String] {
        defaults.merging(session) { _, sessionValue in sessionValue }
    }
}
