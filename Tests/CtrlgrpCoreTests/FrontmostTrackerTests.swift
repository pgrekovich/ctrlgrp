import Testing
import CtrlgrpCore

@MainActor
@Test func startsEmpty() {
    let tracker = FrontmostTracker()
    #expect(tracker.current == nil)
    #expect(tracker.previous == nil)
}

@MainActor
@Test func firstActivationHasNoPrevious() {
    let tracker = FrontmostTracker()
    tracker.didActivate("com.apple.Safari")
    #expect(tracker.current == "com.apple.Safari")
    #expect(tracker.previous == nil)
}

@MainActor
@Test func remembersTheAppBeforeTheCurrentOne() {
    let tracker = FrontmostTracker()
    tracker.didActivate("com.apple.Safari")
    tracker.didActivate("com.apple.Mail")
    tracker.didActivate("com.apple.Notes")
    #expect(tracker.current == "com.apple.Notes")
    #expect(tracker.previous == "com.apple.Mail")
}

@MainActor
@Test func repeatedActivationOfTheSameAppDoesNotShiftHistory() {
    let tracker = FrontmostTracker()
    tracker.didActivate("com.apple.Safari")
    tracker.didActivate("com.apple.Mail")
    tracker.didActivate("com.apple.Mail")
    #expect(tracker.current == "com.apple.Mail")
    #expect(tracker.previous == "com.apple.Safari")
}

@MainActor
@Test func bouncingBetweenTwoAppsKeepsBothEndsValid() {
    let tracker = FrontmostTracker()
    tracker.didActivate("com.apple.Safari")
    tracker.didActivate("com.apple.Mail")
    tracker.didActivate("com.apple.Safari")
    #expect(tracker.current == "com.apple.Safari")
    #expect(tracker.previous == "com.apple.Mail")
}
