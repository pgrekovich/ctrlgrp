/// What pressing a slot should do. Deciding and doing are split so the whole
/// behavioural contract stays a pure function.
public enum SwitchAction: Equatable, Sendable {
    case doNothing
    /// Directly asked for: if the app vanished between this decision and the
    /// action, launching it is the closest thing to what was asked.
    case activate(String)
    /// Reached by toggling back rather than by being asked for. Going back must
    /// never resurrect an app the user deliberately quit, so this action refuses
    /// to launch even if the app disappears mid-flight.
    case activateIfRunning(String)
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
    public var isPreviousRunning: Bool

    public init(
        target: String?,
        isTargetFrontmost: Bool = false,
        isTargetRunning: Bool = false,
        isTargetInstalled: Bool = true,
        previous: String? = nil,
        isPreviousRunning: Bool = true
    ) {
        self.target = target
        self.isTargetFrontmost = isTargetFrontmost
        self.isTargetRunning = isTargetRunning
        self.isTargetInstalled = isTargetInstalled
        self.previous = previous
        self.isPreviousRunning = isPreviousRunning
    }
}

public func decideSwitch(_ situation: Situation) -> SwitchAction {
    guard let target = situation.target else { return .doNothing }

    if situation.isTargetFrontmost {
        guard let previous = situation.previous, previous != target else { return .doNothing }
        // Going back is a navigation, not a request to start something: if the
        // app you came from is gone, there is nowhere to go and pressing again
        // leaves you where you are.
        guard situation.isPreviousRunning else { return .doNothing }
        return .activateIfRunning(previous)
    }

    if situation.isTargetRunning { return .activate(target) }
    guard situation.isTargetInstalled else { return .appMissing(target) }
    return .launch(target)
}
