import Foundation

/// The persisted layer of configuration. Written by hand only: ctrlgrp reads
/// this file and never writes it, so hand edits can never be clobbered.
public struct Config: Equatable, Sendable {
    public var defaults: [Slot: String]
    public var hudEnabled: Bool

    public init(defaults: [Slot: String] = [:], hudEnabled: Bool = true) {
        self.defaults = defaults
        self.hudEnabled = hudEnabled
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

extension Config {
    private struct DTO: Decodable {
        struct HUD: Decodable { var enabled: Bool? }
        var defaults: [String: String]?
        var hud: HUD?
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
            config: Config(defaults: defaults, hudEnabled: dto.hud?.enabled ?? true),
            // Dictionary iteration order is unspecified; sorting keeps the
            // warning list stable for tests and for log diffing.
            warnings: warnings.sorted()
        )
    }

    /// Reads and parses the file, degrading to an empty config with a warning.
    /// A missing or broken config must never stop the app from starting.
    public static func load(from url: URL) -> ConfigParseResult {
        guard let data = try? Data(contentsOf: url) else {
            return ConfigParseResult(
                config: .empty,
                warnings: ["no config at \(url.path()), starting with no default bindings"]
            )
        }
        do {
            return try parse(data)
        } catch {
            return ConfigParseResult(
                config: .empty,
                warnings: ["could not parse \(url.path()): \(error)"]
            )
        }
    }

    public static var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".config/ctrlgrp/config.json")
    }
}
