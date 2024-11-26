//
//  TotalSleepMinutesTests.swift
//  BeeSwiftTests
//
//  Created by Theo Spears on 1/8/23.
//  Copyright © 2023 APB. All rights reserved.
//

import Testing
import HealthKit
@testable import BeeKit

typealias Time = (hour: Int, minute: Int, second: Int)

final class TotalSleepMinutesTests {
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
        HKCategorySample(type: sleepAnalysisCategoryType, value: value.rawValue, start: dateToday(start), end: dateToday(end))
    }

    @Test func testCountsAnyMinuteContainingSleep() throws {
        #expect(totalSleepMinutes(samples: [
            sample(value: .asleepUnspecified, start: "6:00:59", end: "6:01:01")
        ]) == 2)
    }

    @Test func testCountsAllMinutesWithinRange() throws {
        #expect(totalSleepMinutes(samples: [
            sample(value: .asleepUnspecified, start: "6:00:59", end: "6:02:01")
        ]) == 3)
    }

    @Test func testEndTimeIsExclusive() throws {
        #expect(totalSleepMinutes(samples: [
            sample(value: .asleepUnspecified, start: "6:00:00", end: "6:01:00")
        ]) == 1)
    }

    @Test func testSeparateDataPointsAreAdded() throws {
        #expect(totalSleepMinutes(samples: [
            sample(value: .asleepUnspecified, start: "6:00:59", end: "6:01:01"),
            sample(value: .asleepUnspecified, start: "7:00:59", end: "7:01:01")
        ]) == 4)
    }

    @Test func testAdjacentDataPointsAreCombined() throws {
        #expect(totalSleepMinutes(samples: [
            sample(value: .asleepUnspecified, start: "6:00:30", end: "6:01:30"),
            sample(value: .asleepUnspecified, start: "6:01:30", end: "6:02:30")
        ]) == 3)
    }

    @Test func testMinuteIsOnlyCountedOnce() throws {
        #expect(totalSleepMinutes(samples: [
            sample(value: .asleepUnspecified, start: "6:00:59", end: "6:01:01"),
            sample(value: .asleepUnspecified, start: "6:01:59", end: "6:02:01")
        ]) == 3)
    }

    @Test func testMinuteNotCountedIfMoreAwakeThanAsleep() throws {
        #expect(totalSleepMinutes(samples: [
            sample(value: .asleepUnspecified, start: "6:00:01", end: "6:00:02"),
            sample(value: .awake, start: "6:00:01", end: "6:00:30")
        ]) == 0)
    }

    @Test func testMinuteCountedAsAsleepIfThereIsATie() throws {
        #expect(totalSleepMinutes(samples: [
            sample(value: .asleepUnspecified, start: "6:00:01", end: "6:00:02"),
            sample(value: .awake, start: "6:00:01", end: "6:00:02")
        ]) == 1)
    }

    @Test func testLongOverlappingAwakeBasedOnFirstMinute() throws {
        #expect(totalSleepMinutes(samples: [
            sample(value: .asleepUnspecified, start: "6:00:30", end: "6:05:59"),
            sample(value: .awake, start: "6:00:01", end: "6:05:59")
        ]) == 0)
    }

    @Test func testLongOverlappingAsleepBasedOnFirstMinute() throws {
        #expect(totalSleepMinutes(samples: [
            sample(value: .asleepUnspecified, start: "6:00:01", end: "6:05:59"),
            sample(value: .awake, start: "6:00:30", end: "6:05:59")
        ]) == 6)
    }

    @Test func testPreceedingMinuteHasNoEffectIfSamplesDoNotOverlap() throws {
        #expect(totalSleepMinutes(samples: [
            sample(value: .asleepUnspecified, start: "6:00:01", end: "6:00:02"),
            sample(value: .awake, start: "6:00:01", end: "6:00:03"),
            sample(value: .asleepUnspecified, start: "6:01:01", end: "6:01:02"),
            sample(value: .awake, start: "6:01:01", end: "6:01:02")
        ]) == 1)
    }
}
