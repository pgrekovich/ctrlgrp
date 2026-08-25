import Foundation

/// The persisted layer of configuration. Written by hand only: ctrlgrp reads
/// this file and never writes it, so hand edits can never be clobbered.
public struct Config: Equatable, Sendable {
    public var defaults: [Slot: String]
    public var hudEnabled: Bool
    public var menuBarEnabled: Bool
    public var toggleBackEnabled: Bool

    public init(
        defaults: [Slot: String] = [:],
        hudEnabled: Bool = true,
        menuBarEnabled: Bool = true,
        toggleBackEnabled: Bool = true
    ) {
        self.defaults = defaults
        self.hudEnabled = hudEnabled
        self.menuBarEnabled = menuBarEnabled
        self.toggleBackEnabled = toggleBackEnabled
    }

    public static let empty = Config()
}

/// A parsed config plus everything questionable that was skipped along the way.
public struct ConfigParseResult: Equatable, Sendable {
    public var config: Config
    public var warnings: [String]

    public init(config: Config, warnings: [String] = []) {
        self.config = config
        self.warnings = warnings
    }
}

public enum ConfigError: Error, Equatable {
    case malformedJSON(String)
}

/// The result of a config load, distinguishing "file is fine" (even a
/// missing file, which legitimately means no default bindings) from "file
/// exists but could not be parsed". Collapsing these into one shape is what
/// caused a half-saved edit to wipe every default binding: the caller needs
/// to be able to tell them apart to know whether to keep its current
/// defaults or replace them.
public enum ConfigLoadOutcome: Equatable, Sendable {
    /// Parsed successfully. A missing file lands here too, with an empty
    /// config, because deleting the file legitimately means "no default
    /// bindings".
    case parsed(ConfigParseResult)
    /// The file exists but could not be parsed. The caller must keep
    /// whatever defaults it already has: a half-saved edit must not unbind
    /// everything.
    case unparsable(warning: String)
}

extension Config {
    private struct DTO: Decodable {
        struct Toggle: Decodable { var enabled: Bool? }
        var defaults: [String: String]?
        var hud: Toggle?
        var menubar: Toggle?
        var toggleBack: Toggle?
    }

    public static func parse(_ data: Data) throws -> ConfigParseResult {
        let dto: DTO
        do {
            dto = try JSONDecoder().decode(DTO.self, from: data)
        } catch {
            throw ConfigError.malformedJSON(error.localizedDescription)
        }

        var defaults: [Slot: String] = [:]
        var warnings: [String] = []
        for (key, bundleID) in dto.defaults ?? [:] {
            guard let slot = Slot(key: key) else {
                warnings.append("ignoring invalid slot key \"\(key)\"")
                continue
            }
            guard !bundleID.isEmpty else {
                warnings.append("ignoring empty bundle id for slot \(slot)")
                continue
            }
            defaults[slot] = bundleID
        }

        return ConfigParseResult(
            config: Config(
                defaults: defaults,
                hudEnabled: dto.hud?.enabled ?? true,
                menuBarEnabled: dto.menubar?.enabled ?? true,
                toggleBackEnabled: dto.toggleBack?.enabled ?? true
            ),
            // Dictionary iteration order is unspecified; sorting keeps the
            // warning list stable for tests and for log diffing.
            warnings: warnings.sorted()
        )
    }

    /// Reads and parses the file. A missing file is not malformed: it
    /// degrades to an empty config with a warning, same as before. A file
    /// that exists but fails to parse reports `.unparsable` instead, so the
    /// caller can keep its current defaults rather than treat "broken" the
    /// same as "empty".
    public static func load(from url: URL) -> ConfigLoadOutcome {
        guard let data = try? Data(contentsOf: url) else {
            return .parsed(ConfigParseResult(
                config: .empty,
                warnings: ["no config at \(url.path(percentEncoded: false)), starting with no default bindings"]
            ))
        }
        do {
            return .parsed(try parse(data))
        } catch {
            return .unparsable(warning: "could not parse \(url.path(percentEncoded: false)): \(error)")
        }
    }

    public static var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".config/ctrlgrp/config.json")
    }
}
