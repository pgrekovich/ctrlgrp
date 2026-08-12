import Carbon.HIToolbox

enum KeyCodes {
    /// Physical key codes for the digit row. Binding by key code rather than
    /// character keeps the hotkeys identical on EN, RU and PL layouts.
    /// The values are deliberately not sequential: on ANSI hardware 5 is 23
    /// and 6 is 22, so these must come from the named constants.
    static let digits: [Int: Int] = [
        1: kVK_ANSI_1, 2: kVK_ANSI_2, 3: kVK_ANSI_3, 4: kVK_ANSI_4, 5: kVK_ANSI_5,
        6: kVK_ANSI_6, 7: kVK_ANSI_7, 8: kVK_ANSI_8, 9: kVK_ANSI_9, 0: kVK_ANSI_0,
    ]

    static let grave = kVK_ANSI_Grave
}
