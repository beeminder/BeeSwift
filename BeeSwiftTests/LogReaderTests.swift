//
//  LogReaderTests.swift
//  BeeSwiftTests
//
//  Created by Theo Spears on 5/3/23.
//  Copyright © 2023 APB. All rights reserved.
//

import Testing
import OSLog

@testable import BeeSwift

final class LogReaderTests {
    private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "LogReaderTests")

    init() {
        logger.info("Sample Log Info")
        logger.error("Sample Log Error")
    }

    @Test func testGetLogMessages() async throws {
        let logReader = LogReader()
        let logs = await logReader.getLogMessages(showSystemMessages: false, errorLevel: .debug)
        #expect(logs.contains("Sample Log Info"))
    }

    @Test func testFiltersByLevel() async throws {
        let logReader = LogReader()
        let logs = await logReader.getLogMessages(showSystemMessages: false, errorLevel: .error)
        #expect(!logs.contains("Sample Log Info"))
        #expect(logs.contains("Sample Log Error"))
    }

    @Test func testSavesToFile() async throws {
        let logReader = LogReader()
        let logFile = await logReader.saveLogsToFile(showSystemMessages: false, errorLevel: .debug)

        // Confirm it contains log sample
        let contents = try String(contentsOf: logFile, encoding: .utf8)
        #expect(contents.contains("Sample Log Info"))

        let fileManager = FileManager.default
        try fileManager.removeItem(atPath: logFile.path)
    }
}
