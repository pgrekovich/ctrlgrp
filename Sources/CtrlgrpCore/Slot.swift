/// One of the ten control-group slots, named by the digit key that selects it.
public struct Slot: Hashable, Sendable, CustomStringConvertible {
    public let digit: Int

    public init?(digit: Int) {
        guard (0...9).contains(digit) else { return nil }
        self.digit = digit
    }

    /// Parses a config key such as "3". Rejects anything that is not exactly
    /// one digit, so "12" and " 1" are errors rather than silent matches.
    public init?(key: String) {
        guard key.count == 1, let digit = Int(key) else { return nil }
        self.init(digit: digit)
    }

    public var description: String { String(digit) }

    /// Slots in the order the keys sit on the keyboard: 1 through 9, then 0.
    public static let all: [Slot] = ((1...9).map { $0 } + [0]).compactMap(Slot.init(digit:))
}
