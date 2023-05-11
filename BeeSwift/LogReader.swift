//  LogReader.swift
//  BeeSwift
//
//  Wrapper for fetching logs from the system log store

import Foundation
import OSLog


@available(iOS 15.0, *)
class LogReader {
    private var allMessagesTask: Task<[OSLogEntryLog], Never>!

    init() {
        allMessagesTask = Task.detached(priority: .userInitiated) {
            do {
                let store = try OSLogStore(scope: .currentProcessIdentifier)
                let position = store.position(timeIntervalSinceLatestBoot: 1)
                return try store
                    .getEntries(at: position)
                    .compactMap { $0 as? OSLogEntryLog }
            } catch {
                return []
            }
        }
    }

    func getLogMessages(showSystemMessages: Bool, errorLevel: OSLogEntryLog.Level) async -> String {
        return await allMessagesTask.value
            .filter { showSystemMessages || $0.subsystem == Bundle.main.bundleIdentifier! }
            .filter { $0.level.rawValue >= errorLevel.rawValue }
            .map { "[\($0.date.formatted())] [\($0.category)] \($0.composedMessage)" }
            .joined(separator: "\n")
    }

    func saveLogsToFile(showSystemMessages: Bool, errorLevel: OSLogEntryLog.Level) async -> URL {
        // Create a temporary log file
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(logFileName())
        let tempFileURL = URL(fileURLWithPath: tempFile.path)

        // Write the logs to the temporary file
        let logs = await getLogMessages(showSystemMessages: showSystemMessages, errorLevel: errorLevel)
        try? logs.write(to: tempFileURL, atomically: true, encoding: .utf8)

        return tempFileURL
    }

    func logFileName() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
        let date = dateFormatter.string(from: Date())
        return "BeeSwift Logs \(date).txt"
    }
}
