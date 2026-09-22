import XCTest

@testable import BeeKit

final class BeeDataPointTests: XCTestCase {
  private func datapoint(value: Double) -> NewDataPoint {
    NewDataPoint(
      requestid: "test",
      daystamp: Daystamp(year: 2024, month: 1, day: 1),
      value: NSNumber(value: value),
      comment: "",
    )
  }

  func testFormattedValueWithoutHHMMFormat() {
    XCTAssertEqual(datapoint(value: 42.5).formattedValue(hhmmFormat: false), "42.5")
  }

  func testFormattedValueWithoutHHMMFormatInteger() {
    XCTAssertEqual(datapoint(value: 100).formattedValue(hhmmFormat: false), "100")
  }

  func testFormattedValueWithHHMMFormat() {
    XCTAssertEqual(datapoint(value: 1.5).formattedValue(hhmmFormat: true), "1:30")
  }

  func testFormattedValueWithHHMMFormatZeroMinutes() {
    XCTAssertEqual(datapoint(value: 2.0).formattedValue(hhmmFormat: true), "2:00")
  }

  func testFormattedValueWithHHMMFormatLargeHours() {
    XCTAssertEqual(datapoint(value: 123.75).formattedValue(hhmmFormat: true), "123:45")
  }

  func testFormattedValueWithHHMMFormatRoundingTo60() {
    // 0.999... * 60 could round to 60 without proper handling; must never render as "1:60".
    let result = datapoint(value: 1.999).formattedValue(hhmmFormat: true)
    XCTAssertFalse(result.contains(":60"), "Minutes should never be 60, got \(result)")
  }
}
