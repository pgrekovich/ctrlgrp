import Testing
import CtrlgrpCore

@Test func emptySlotDoesNothing() {
    #expect(decideSwitch(Situation(target: nil, previous: "com.apple.Mail")) == .doNothing)
}

@Test func runningAppInBackgroundGetsActivated() {
    let situation = Situation(
        target: "com.apple.Safari",
        isTargetRunning: true,
        previous: "com.apple.Mail"
    )
    #expect(decideSwitch(situation) == .activate("com.apple.Safari"))
}

@Test func runningAppWithoutWindowsGetsReopened() {
    let situation = Situation(
        target: "com.apple.Safari",
        isTargetRunning: true,
        isTargetWindowless: true,
        previous: "com.apple.Mail"
    )
    #expect(decideSwitch(situation) == .reopen("com.apple.Safari"))
}

@Test func installedButNotRunningAppGetsLaunched() {
    let situation = Situation(target: "com.apple.Safari", isTargetRunning: false)
    #expect(decideSwitch(situation) == .launch("com.apple.Safari"))
}

@Test func uninstalledAppIsReportedMissing() {
    let situation = Situation(
        target: "com.example.Gone",
        isTargetRunning: false,
        isTargetInstalled: false
    )
    #expect(decideSwitch(situation) == .appMissing("com.example.Gone"))
}

@Test func pressingTheFocusedSlotTogglesBackToThePreviousApp() {
    let situation = Situation(
        target: "com.apple.Safari",
        isTargetFrontmost: true,
        isTargetRunning: true,
        previous: "com.apple.Mail"
    )
    #expect(decideSwitch(situation) == .activateIfRunning("com.apple.Mail"))
}

@Test func pressingTheFocusedSlotDoesNothingWhenToggleBackIsDisabled() {
    let situation = Situation(
        target: "com.apple.Safari",
        isTargetFrontmost: true,
        isTargetRunning: true,
        previous: "com.apple.Mail",
        toggleBackEnabled: false
    )
    #expect(decideSwitch(situation) == .doNothing)
}

@Test func togglingBackToAnAppTheUserQuitDoesNothing() {
    let situation = Situation(
        target: "com.apple.Safari",
        isTargetFrontmost: true,
        isTargetRunning: true,
        previous: "com.apple.Terminal",
        isPreviousRunning: false
    )
    #expect(decideSwitch(situation) == .doNothing)
}

@Test func aDirectCallStillLaunchesEvenWhenThePreviousAppIsGone() {
    let situation = Situation(
        target: "com.google.Chrome",
        isTargetFrontmost: false,
        isTargetRunning: false,
        previous: "com.apple.Terminal",
        isPreviousRunning: false
    )
    #expect(decideSwitch(situation) == .launch("com.google.Chrome"))
}

@Test func focusedSlotWithNoPreviousAppDoesNothing() {
    let situation = Situation(
        target: "com.apple.Safari",
        isTargetFrontmost: true,
        isTargetRunning: true,
        previous: nil
    )
    #expect(decideSwitch(situation) == .doNothing)
}

@Test func focusedSlotWhosePreviousIsItselfDoesNothing() {
    let situation = Situation(
        target: "com.apple.Safari",
        isTargetFrontmost: true,
        isTargetRunning: true,
        previous: "com.apple.Safari"
    )
    #expect(decideSwitch(situation) == .doNothing)
}
