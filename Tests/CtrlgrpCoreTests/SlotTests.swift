import Testing
import CtrlgrpCore

@Test func slotAcceptsEveryDigit() {
    for digit in 0...9 {
        #expect(Slot(digit: digit)?.digit == digit)
    }
}

@Test func slotRejectsOutOfRangeDigits() {
    #expect(Slot(digit: 10) == nil)
    #expect(Slot(digit: -1) == nil)
}

@Test func slotParsesSingleCharacterKeys() {
    #expect(Slot(key: "3")?.digit == 3)
    #expect(Slot(key: "0")?.digit == 0)
}

@Test func slotRejectsNonDigitKeys() {
    #expect(Slot(key: "12") == nil)
    #expect(Slot(key: "a") == nil)
    #expect(Slot(key: "") == nil)
    #expect(Slot(key: " 1") == nil)
}

@Test func slotDescriptionIsTheDigit() {
    #expect(Slot(digit: 7)?.description == "7")
}

@Test func allSlotsAreInKeyboardOrder() {
    #expect(Slot.all.map(\.digit) == [1, 2, 3, 4, 5, 6, 7, 8, 9, 0])
}
