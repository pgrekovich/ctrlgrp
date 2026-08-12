import Foundation
import os

/// Logs to the unified system log, and mirrors to stderr so `make run` shows
/// everything in the terminal during development.
enum Log {
    private static let logger = Logger(subsystem: "com.pgrekovich.ctrlgrp", category: "ctrlgrp")

    static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
        echo(message)
    }

    static func warn(_ message: String) {
        logger.warning("\(message, privacy: .public)")
        echo("warning: \(message)")
    }

    private static func echo(_ message: String) {
        FileHandle.standardError.write(Data("ctrlgrp: \(message)\n".utf8))
    }
}
