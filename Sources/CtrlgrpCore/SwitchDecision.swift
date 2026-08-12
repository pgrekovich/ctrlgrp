/// What pressing a slot should do. Deciding and doing are split so the whole
/// behavioural contract stays a pure function.
public enum SwitchAction: Equatable, Sendable {
    case doNothing
    case activate(String)
    case launch(String)
    case appMissing(String)
}

/// Everything the decision needs to know about the world at keypress time.
public struct Situation: Equatable, Sendable {
    public var target: String?
    public var isTargetFrontmost: Bool
    public var isTargetRunning: Bool
    public var isTargetInstalled: Bool
    public var previous: String?

    public init(
        target: String?,
        isTargetFrontmost: Bool = false,
        isTargetRunning: Bool = false,
        isTargetInstalled: Bool = true,
        previous: String? = nil
    ) {
        self.target = target
        self.isTargetFrontmost = isTargetFrontmost
        self.isTargetRunning = isTargetRunning
        self.isTargetInstalled = isTargetInstalled
        self.previous = previous
    }
}

public func decideSwitch(_ situation: Situation) -> SwitchAction {
    guard let target = situation.target else { return .doNothing }

    if situation.isTargetFrontmost {
        guard let previous = situation.previous, previous != target else { return .doNothing }
        return .activate(previous)
    }

    if situation.isTargetRunning { return .activate(target) }
    guard situation.isTargetInstalled else { return .appMissing(target) }
    return .launch(target)
}
