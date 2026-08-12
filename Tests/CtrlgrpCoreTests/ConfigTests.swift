import Foundation
import Testing
import CtrlgrpCore

private func parse(_ json: String) throws -> ConfigParseResult {
    try Config.parse(Data(json.utf8))
}

@Test func parsesDefaultsAndHUDFlag() throws {
    let result = try parse("""
    { "defaults": { "1": "com.google.Chrome", "3": "com.googlecode.iterm2" },
      "hud": { "enabled": false } }
    """)
    #expect(result.config.defaults[Slot(digit: 1)!] == "com.google.Chrome")
    #expect(result.config.defaults[Slot(digit: 3)!] == "com.googlecode.iterm2")
    #expect(result.config.hudEnabled == false)
    #expect(result.warnings.isEmpty)
}

@Test func hudDefaultsToEnabledWhenAbsent() throws {
    let result = try parse(#"{ "defaults": { "1": "com.apple.Safari" } }"#)
    #expect(result.config.hudEnabled == true)
}

@Test func emptyObjectYieldsEmptyConfig() throws {
    let result = try parse("{}")
    #expect(result.config.defaults.isEmpty)
    #expect(result.config.hudEnabled == true)
    #expect(result.warnings.isEmpty)
}

@Test func skipsInvalidSlotKeysWithWarnings() throws {
    let result = try parse("""
    { "defaults": { "1": "com.apple.Safari", "12": "com.apple.Mail", "x": "com.apple.Notes" } }
    """)
    #expect(result.config.defaults.count == 1)
    #expect(result.warnings.count == 2)
    #expect(result.warnings.contains { $0.contains("\"12\"") })
    #expect(result.warnings.contains { $0.contains("\"x\"") })
}

@Test func skipsEmptyBundleIDWithWarning() throws {
    let result = try parse(#"{ "defaults": { "5": "" } }"#)
    #expect(result.config.defaults.isEmpty)
    #expect(result.warnings.count == 1)
}

@Test func warningsAreSortedForDeterminism() throws {
    let result = try parse("""
    { "defaults": { "99": "a", "zz": "b", "40": "c" } }
    """)
    #expect(result.warnings == result.warnings.sorted())
}

@Test func malformedJSONThrows() {
    #expect(throws: ConfigError.self) {
        _ = try parse("{ this is not json ")
    }
}

@Test func loadReturnsEmptyConfigAndWarningForMissingFile() {
    let missing = URL(filePath: "/tmp/ctrlgrp-does-not-exist-\(UUID().uuidString).json")
    let result = Config.load(from: missing)
    #expect(result.config == Config.empty)
    #expect(result.warnings.count == 1)
}

@Test func loadReadsAFileFromDisk() throws {
    let url = URL(filePath: NSTemporaryDirectory()).appending(path: "ctrlgrp-\(UUID().uuidString).json")
    try Data(#"{ "defaults": { "2": "com.apple.Terminal" } }"#.utf8).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }

    let result = Config.load(from: url)
    #expect(result.config.defaults[Slot(digit: 2)!] == "com.apple.Terminal")
    #expect(result.warnings.isEmpty)
}

@Test func loadReportsBrokenJSONWithoutThrowing() throws {
    let url = URL(filePath: NSTemporaryDirectory()).appending(path: "ctrlgrp-\(UUID().uuidString).json")
    try Data("{ broken".utf8).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }

    let result = Config.load(from: url)
    #expect(result.config == Config.empty)
    #expect(result.warnings.count == 1)
}

@Test func defaultURLPointsAtXDGStyleConfigPath() {
    #expect(Config.defaultURL.path().hasSuffix(".config/ctrlgrp/config.json"))
}
