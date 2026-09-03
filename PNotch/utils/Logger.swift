import Foundation
import os

extension Logger {
    nonisolated private static let subsystem = Bundle.main.bundleIdentifier ?? "com.pnotch.PNotch"

    nonisolated static let app = Logger(subsystem: subsystem, category: "app")
    nonisolated static let persistence = Logger(subsystem: subsystem, category: "persistence")
    nonisolated static let music = Logger(subsystem: subsystem, category: "music")
}
