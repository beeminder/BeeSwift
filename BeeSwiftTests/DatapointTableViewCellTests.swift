//
//  DatapointTableViewCellTests.swift
//  BeeSwiftTests
//

import XCTest

@testable import BeeKit
@testable import BeeSwift

final class DatapointTableViewCellTests: XCTestCase {

  // MARK: - formatDay tests

  func testFormatDaySameMonthAndYear() {
    let now = Date()
    let calendar = Calendar.current
    let currentYear = calendar.component(.year, from: now)
    let currentMonth = calendar.component(.month, from: now)

    let datapoint = MockDataPoint(
      daystamp: Daystamp(year: currentYear, month: currentMonth, day: 15),
      value: 1.0,
      comment: "",
    )

    XCTAssertEqual(DatapointTableViewCell.formatDay(datapoint: datapoint), "15")
  }

  func testFormatDaySingleDigitDay() {
    let now = Date()
    let calendar = Calendar.current
    let currentYear = calendar.component(.year, from: now)
    let currentMonth = calendar.component(.month, from: now)

    let datapoint = MockDataPoint(
      daystamp: Daystamp(year: currentYear, month: currentMonth, day: 5),
      value: 1.0,
      comment: "",
    )

    XCTAssertEqual(DatapointTableViewCell.formatDay(datapoint: datapoint), "5")
  }

  func testFormatDayDifferentMonth() {
    let now = Date()
    let calendar = Calendar.current
    let currentYear = calendar.component(.year, from: now)
    let currentMonth = calendar.component(.month, from: now)
    let previousMonth = currentMonth == 1 ? 12 : currentMonth - 1

    let datapoint = MockDataPoint(
      daystamp: Daystamp(year: currentYear, month: previousMonth, day: 25),
      value: 1.0,
      comment: "",
    )

    XCTAssertEqual(DatapointTableViewCell.formatDay(datapoint: datapoint), "\(previousMonth)/25")
  }

  func testFormatDayDifferentYear() {
    let now = Date()
    let calendar = Calendar.current
    let currentYear = calendar.component(.year, from: now)
    let currentMonth = calendar.component(.month, from: now)

    let datapoint = MockDataPoint(
      daystamp: Daystamp(year: currentYear - 1, month: currentMonth, day: 31),
      value: 1.0,
      comment: "",
    )

    XCTAssertEqual(DatapointTableViewCell.formatDay(datapoint: datapoint), "\(currentMonth)/31")
  }

  // MARK: - calculatePercentileWidth tests

  func testCalculatePercentileWidthEmptyArray() {
    let result = DatapointTableViewCell.calculatePercentileWidth(widths: [], fallback: 10)
    XCTAssertEqual(result, 10)
  }

  func testCalculatePercentileWidthSingleElement() {
    let result = DatapointTableViewCell.calculatePercentileWidth(widths: [50], fallback: 10)
    XCTAssertEqual(result, 50)
  }

  func testCalculatePercentileWidthAllSameWidths() {
    let result = DatapointTableViewCell.calculatePercentileWidth(widths: [30, 30, 30, 30], fallback: 10)
    XCTAssertEqual(result, 30)
  }

  func testCalculatePercentileWidthMaxUnder60ReturnsMax() {
    // When max <= 60, always return max regardless of distribution
    let result = DatapointTableViewCell.calculatePercentileWidth(widths: [10, 10, 10, 55], fallback: 10)
    XCTAssertEqual(result, 55)
  }

  func testCalculatePercentileWidthMaxWithinThresholdReturnsMax() {
    // When max <= p75 * 1.5, return max
    // p75 of [40, 40, 40, 55] is 40, threshold is 40 * 1.5 = 60
    // max (55) <= 60, so returns max
    let result = DatapointTableViewCell.calculatePercentileWidth(widths: [40, 40, 40, 55], fallback: 10)
    XCTAssertEqual(result, 55)
  }

  func testCalculatePercentileWidthMaxExceedsThresholdReturnsP75() {
    // When max > p75 * 1.5 and max > 60, return p75
    // p75 of [40, 40, 40, 100] is 40, threshold is 40 * 1.5 = 60
    // max (100) > 60 and > threshold, so returns p75
    let result = DatapointTableViewCell.calculatePercentileWidth(widths: [40, 40, 40, 100], fallback: 10)
    XCTAssertEqual(result, 40)
  }

  func testCalculatePercentileWidthLargeOutlier() {
    // Simulate a dataset with one very long value
    let widths: [CGFloat] = [20, 22, 21, 23, 20, 21, 22, 150]
    let result = DatapointTableViewCell.calculatePercentileWidth(widths: widths, fallback: 10)
    // p75 should be around 22-23, max (150) far exceeds threshold
    XCTAssertLessThan(result, 30, "Should return p75, not max")
  }
}

// MARK: - Mock DataPoint

private struct MockDataPoint: BeeDataPoint {
  let requestid: String = "test"
  let daystamp: Daystamp
  let value: NSNumber
  let comment: String

  init(daystamp: Daystamp, value: Double, comment: String) {
    self.daystamp = daystamp
    self.value = NSNumber(value: value)
    self.comment = comment
  }
}
