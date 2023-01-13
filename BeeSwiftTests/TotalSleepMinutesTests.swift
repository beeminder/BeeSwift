//
//  TotalSleepMinutesTests.swift
//  BeeSwiftTests
//
//  Created by Theo Spears on 1/8/23.
//  Copyright © 2023 APB. All rights reserved.
//

import XCTest
import HealthKit
@testable import BeeSwift

typealias Time = (hour: Int, minute: Int, second: Int)

final class TotalSleepMinutesTests: XCTestCase {
    let midnightToday = Calendar(identifier: .gregorian).startOfDay(for: Date())
    let sleepAnalysisCategoryType = HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier.sleepAnalysis)!

    func parseTime(_ time: String) -> Time {
        let components = time.components(separatedBy: ":")
        return (hour: Int(components[0])!, minute: Int(components[1])!, second: Int(components[2])!)
    }

    func dateToday(_ timeStr: String) -> Date {
        let time = parseTime(timeStr)
        return midnightToday.addingTimeInterval(TimeInterval(time.hour * 60 * 60 + time.minute * 60 + time.second))
    }

    func sample(value: HKCategoryValueSleepAnalysis, start: String, end: String) -> HKCategorySample {
        return HKCategorySample(type: sleepAnalysisCategoryType, value: value.rawValue, start: dateToday(start), end: dateToday(end))
    }

    func testCountsAnyMinuteContainingSleep() throws {
        XCTAssertEqual(totalSleepMinutes(samples: [
            sample(value: .asleep, start: "6:00:59", end: "6:01:01")
        ]), 2)
    }

    func testCountsAllMinutesWithinRange() throws {
        XCTAssertEqual(totalSleepMinutes(samples: [
            sample(value: .asleep, start: "6:00:59", end: "6:02:01")
        ]), 3)
    }

    func testEndTimeIsExclusive() throws {
        XCTAssertEqual(totalSleepMinutes(samples: [
            sample(value: .asleep, start: "6:00:00", end: "6:01:00")
        ]), 1)
    }

    func testSeparateDataPointsAreAdded() throws {
        XCTAssertEqual(totalSleepMinutes(samples: [
            sample(value: .asleep, start: "6:00:59", end: "6:01:01"),
            sample(value: .asleep, start: "7:00:59", end: "7:01:01")
        ]), 4)
    }

    func testAdjacentDataPointsAreCombined() throws {
        XCTAssertEqual(totalSleepMinutes(samples: [
            sample(value: .asleep, start: "6:00:30", end: "6:01:30"),
            sample(value: .asleep, start: "6:01:30", end: "6:02:30")
        ]), 3)
    }

    func testMinuteIsOnlyCountedOnce() throws {
        XCTAssertEqual(totalSleepMinutes(samples: [
            sample(value: .asleep, start: "6:00:59", end: "6:01:01"),
            sample(value: .asleep, start: "6:01:59", end: "6:02:01")
        ]), 3)
    }

    func testMinuteNotCountedIfMoreAwakeThanAsleep() throws {
        XCTAssertEqual(totalSleepMinutes(samples: [
            sample(value: .asleep, start: "6:00:01", end: "6:00:02"),
            sample(value: .awake, start: "6:00:01", end: "6:00:30")
        ]), 0)
    }

    func testMinuteCountedAsAsleepIfThereIsATie() throws {
        XCTAssertEqual(totalSleepMinutes(samples: [
            sample(value: .asleep, start: "6:00:01", end: "6:00:02"),
            sample(value: .awake, start: "6:00:01", end: "6:00:02")
        ]), 1)
    }

    func testLongOverlappingAwakeBasedOnFirstMinute() throws {
        XCTAssertEqual(totalSleepMinutes(samples: [
            sample(value: .asleep, start: "6:00:30", end: "6:05:59"),
            sample(value: .awake, start: "6:00:01", end: "6:05:59")
        ]), 0)
    }

    func testLongOverlappingAsleepBasedOnFirstMinute() throws {
        XCTAssertEqual(totalSleepMinutes(samples: [
            sample(value: .asleep, start: "6:00:01", end: "6:05:59"),
            sample(value: .awake, start: "6:00:30", end: "6:05:59")
        ]), 6)
    }

    func testPreceedingMinuteHasNoEffectIfSamplesDoNotOverlap() throws {
        XCTAssertEqual(totalSleepMinutes(samples: [
            sample(value: .asleep, start: "6:00:01", end: "6:00:02"),
            sample(value: .awake, start: "6:00:01", end: "6:00:03"),
            sample(value: .asleep, start: "6:01:01", end: "6:01:02"),
            sample(value: .awake, start: "6:01:01", end: "6:01:02")
        ]), 1)
    }
}
