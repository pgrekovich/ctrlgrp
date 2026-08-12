import Testing
import CtrlgrpCore

private let one = Slot(digit: 1)!
private let two = Slot(digit: 2)!
private let three = Slot(digit: 3)!

@MainActor
@Test func fallsBackToDefaults() {
    let bindings = Bindings(defaults: [one: "com.apple.Safari"])
    #expect(bindings.effective(one) == "com.apple.Safari")
}

@MainActor
@Test func unboundSlotIsNil() {
    let bindings = Bindings(defaults: [one: "com.apple.Safari"])
    #expect(bindings.effective(two) == nil)
}

@MainActor
@Test func sessionBindingWinsOverDefault() {
    let bindings = Bindings(defaults: [one: "com.apple.Safari"])
    bindings.bind("com.google.Chrome", to: one)
    #expect(bindings.effective(one) == "com.google.Chrome")
}

@MainActor
@Test func rebindingOverwritesTheSessionValue() {
    let bindings = Bindings()
    bindings.bind("com.apple.Mail", to: three)
    bindings.bind("com.apple.Notes", to: three)
    #expect(bindings.effective(three) == "com.apple.Notes")
}

@MainActor
@Test func reloadingDefaultsPreservesSessionBindings() {
    let bindings = Bindings(defaults: [one: "com.apple.Safari", two: "com.apple.Mail"])
    bindings.bind("com.google.Chrome", to: one)

    bindings.updateDefaults([one: "com.apple.Music", two: "com.apple.Notes"])

    #expect(bindings.effective(one) == "com.google.Chrome")
    #expect(bindings.effective(two) == "com.apple.Notes")
}

@MainActor
@Test func effectiveAllMergesBothLayers() {
    let bindings = Bindings(defaults: [one: "com.apple.Safari", two: "com.apple.Mail"])
    bindings.bind("com.google.Chrome", to: one)
    bindings.bind("com.apple.Notes", to: three)

    #expect(bindings.effectiveAll == [
        one: "com.google.Chrome",
        two: "com.apple.Mail",
        three: "com.apple.Notes",
    ])
}
