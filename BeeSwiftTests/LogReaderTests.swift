//
//  LogReaderTests.swift
//  BeeSwiftTests
//
//  Created by Theo Spears on 5/3/23.
//  Copyright 2023 APB. All rights reserved.
//

import XCTest
import OSLog

@testable import BeeSwift

final class LogReaderTests: XCTestCase {
    private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "LogReaderTests")

    override func setUp() async throws {
        logger.info("Sample Log Info")
        logger.error("Sample Log Error")
    }

    func testGetLogMessages() async throws {
        let logReader = LogReader()
        let logs = await logReader.getLogMessages(showSystemMessages: false, errorLevel: .debug)
        XCTAssert(logs.contains("Sample Log Info"))
    }

    func testFiltersByLevel() async throws {
        let logReader = LogReader()
        let logs = await logReader.getLogMessages(showSystemMessages: false, errorLevel: .error)
        XCTAssertFalse(logs.contains("Sample Log Info"))
        XCTAssert(logs.contains("Sample Log Error"))
    }

    func testSavesToFile() async throws {
        let logReader = LogReader()
        let logFile = await logReader.saveLogsToFile(showSystemMessages: false, errorLevel: .debug)

        // Confirm it contains log sample
        let contents = try String(contentsOf: logFile, encoding: .utf8)
        XCTAssert(contents.contains("Sample Log Info"))

        let fileManager = FileManager.default
        try fileManager.removeItem(atPath: logFile.path)
    }
}
