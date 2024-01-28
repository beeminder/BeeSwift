import XCTest
@testable import BeeKit

final class DaystampTests: XCTestCase {
    var previousTimezone: TimeZone!

    let OneHourInSeconds = 60 * 60

    func testFormatsAsString() throws {
        let daystamp = Daystamp(year: 2023, month: 7, day: 11)
        XCTAssertEqual(daystamp.description, "20230711")
    }

    func testParsesFromString() throws {
        let daystamp = try Daystamp(fromString: "20230711")
        XCTAssertEqual(daystamp.year, 2023)
        XCTAssertEqual(daystamp.month, 7)
        XCTAssertEqual(daystamp.day, 11)
    }

    func testConvertsFromDate() throws {
        let date = date(year: 1970, month: 1, day: 1, hour: 0, minute: 0)
        let daystamp = Daystamp(fromDate: date, deadline: 0)
        XCTAssertEqual(daystamp.year, 1970)
        XCTAssertEqual(daystamp.month, 1)
        XCTAssertEqual(daystamp.day, 1)
    }

    func testConvertsFromDateWithPositiveDeadlineLaterInDay() throws {
        let date = date(year: 1970, month: 1, day: 1, hour: 0, minute: 0)
        let daystamp = Daystamp(fromDate: date, deadline: OneHourInSeconds)
        XCTAssertEqual(daystamp.year, 1969)
        XCTAssertEqual(daystamp.month, 12)
        XCTAssertEqual(daystamp.day, 31)
    }

    func testConvertsFromDateWithPositiveDeadlineEarlierInDay() throws {
        let date = date(year: 1970, month: 1, day: 1, hour: 2, minute: 0)
        let daystamp = Daystamp(fromDate: date, deadline: OneHourInSeconds)
        XCTAssertEqual(daystamp.year, 1970)
        XCTAssertEqual(daystamp.month, 1)
        XCTAssertEqual(daystamp.day, 1)
    }

    func testConvertsFromDateWithNegativeDeadlineLaterInDay() throws {
        let date = date(year: 1970, month: 1, day: 1, hour: 0, minute: 0)
        let daystamp = Daystamp(fromDate: date, deadline: -OneHourInSeconds)
        XCTAssertEqual(daystamp.year, 1970)
        XCTAssertEqual(daystamp.month, 1)
        XCTAssertEqual(daystamp.day, 1)
    }

    func testConvertsFromDateWithNegativeDeadlineEarlierInDay() throws {
        let date = date(year: 1970, month: 1, day: 1, hour: 23, minute: 0)
        let daystamp = Daystamp(fromDate: date, deadline: -2 * OneHourInSeconds)
        XCTAssertEqual(daystamp.year, 1970)
        XCTAssertEqual(daystamp.month, 1)
        XCTAssertEqual(daystamp.day, 2)
    }

    func testConvertsFromDateAtStartOfNegativeDaystamp() throws {
        // Ensure there is not an off-by one error when importing values right on the datestamp boundary
        let date = date(year: 1970, month: 1, day: 1, hour: 23, minute: 0)
        let daystamp = Daystamp(fromDate: date, deadline: -OneHourInSeconds)
        XCTAssertEqual(daystamp, Daystamp(year: 1970, month: 1, day: 2))
    }

    func testConvertsFromDateAtStartOfPositiveDaystamp() throws {
        // Ensure there is not an off-by one error when importing values right on the datestamp boundary
        let date = date(year: 1970, month: 1, day: 1, hour: 1, minute: 0)
        let daystamp = Daystamp(fromDate: date, deadline: OneHourInSeconds)
        XCTAssertEqual(daystamp, Daystamp(year: 1970, month: 1, day: 1))
    }

    func testComparesCorrectly() throws {
        XCTAssertLessThan(Daystamp(year: 2023, month: 7, day: 11), Daystamp(year: 2023, month: 7, day: 12))
        XCTAssertLessThan(Daystamp(year: 2023, month: 7, day: 11), Daystamp(year: 2023, month: 8, day: 10))
        XCTAssertLessThan(Daystamp(year: 2023, month: 7, day: 11), Daystamp(year: 2024, month: 6, day: 10))
        XCTAssertEqual(Daystamp(year: 2023, month: 7, day: 11), Daystamp(year: 2023, month: 7, day: 11))
    }

    func testCanAddToDaystamp() throws {
        XCTAssertEqual(Daystamp(year: 2023, month: 7, day: 11) + 1, Daystamp(year: 2023, month: 7, day: 12))
        XCTAssertEqual(Daystamp(year: 2023, month: 7, day: 11) + 30, Daystamp(year: 2023, month: 8, day: 10))
        XCTAssertEqual(Daystamp(year: 2023, month: 7, day: 11) + 365, Daystamp(year: 2024, month: 7, day: 10)) // Leap year!
    }

    func testCanSubtractFromDaystamp() throws {
        XCTAssertEqual(Daystamp(year: 2023, month: 7, day: 11) - 1, Daystamp(year: 2023, month: 7, day: 10))
        XCTAssertEqual(Daystamp(year: 2023, month: 7, day: 11) - 30, Daystamp(year: 2023, month: 6, day: 11))
        XCTAssertEqual(Daystamp(year: 2023, month: 7, day: 11) - 365, Daystamp(year: 2022, month: 7, day: 11))
    }

    func testCanCountDaysBetweenDaystamps() throws {
        XCTAssertEqual(Daystamp(year: 2023, month: 7, day: 12) - Daystamp(year: 2023, month: 7, day: 11), 1)
        XCTAssertEqual(Daystamp(year: 2023, month: 8, day: 10) - Daystamp(year: 2023, month: 7, day: 11), 30)
        XCTAssertEqual(Daystamp(year: 2024, month: 6, day: 11) - Daystamp(year: 2023, month: 6, day: 11), 366) // Leap year!
    }

    func testCanCalculateBoundsForZeroDeadline() throws {
        XCTAssertEqual(Daystamp(year: 1970, month: 1, day: 1).start(deadline: 0), date(year: 1970, month: 1, day: 1, hour: 0, minute: 0))
        XCTAssertEqual(Daystamp(year: 1970, month: 1, day: 1).end(deadline: 0), date(year: 1970, month: 1, day: 2, hour: 0, minute: 0))
    }

    func testCanCalculateBoundsForNegativeDeadline() throws {
        XCTAssertEqual(Daystamp(year: 1970, month: 1, day: 1).start(deadline: -OneHourInSeconds), date(year: 1969, month: 12, day: 31, hour: 23, minute: 0))
        XCTAssertEqual(Daystamp(year: 1970, month: 1, day: 1).end(deadline: -OneHourInSeconds), date(year: 1970, month: 1, day: 1, hour: 23, minute: 0))
    }

    func testCanCalculateBoundsForPositiveDeadline() throws {
        XCTAssertEqual(Daystamp(year: 1970, month: 1, day: 1).start(deadline: OneHourInSeconds), date(year: 1970, month: 1, day: 1, hour: 1, minute: 0))
        XCTAssertEqual(Daystamp(year: 1970, month: 1, day: 1).end(deadline: OneHourInSeconds), date(year: 1970, month: 1, day: 2, hour: 1, minute: 0))
    }

    func date(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        return Calendar.current.date(from: components)!
    }

    func testCanIterateOverRange() throws {
        let daystamp = Daystamp(year: 1970, month: 1, day: 1)
        let range = daystamp...(daystamp + 3)
        XCTAssertEqual(Array(range), [daystamp, daystamp + 1, daystamp + 2, daystamp + 3])
    }
}
