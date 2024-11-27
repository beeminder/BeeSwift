import Testing
@testable import BeeKit

final class DaystampTests {
    var previousTimezone: TimeZone!

    let OneHourInSeconds = 60 * 60


    @Test func testFormatsAsString() async throws {
        let daystamp = Daystamp(year: 2023, month: 7, day: 11)
        #expect(daystamp.description == "20230711")
    }

    @Test func testParsesFromString() async throws {
        let daystamp = try Daystamp(fromString: "20230711")
        #expect(daystamp.year == 2023)
        #expect(daystamp.month == 7)
        #expect(daystamp.day == 11)
    }

    @Test func testConvertsFromDate() async throws {
        let date = date(year: 1970, month: 1, day: 1, hour: 0, minute: 0)
        let daystamp = Daystamp(fromDate: date, deadline: 0)
        #expect(daystamp.year == 1970)
        #expect(daystamp.month == 1)
        #expect(daystamp.day == 1)
    }

    @Test func testConvertsFromDateWithPositiveDeadlineLaterInDay() async throws {
        let date = date(year: 1970, month: 1, day: 1, hour: 0, minute: 0)
        let daystamp = Daystamp(fromDate: date, deadline: OneHourInSeconds)
        #expect(daystamp.year == 1969)
        #expect(daystamp.month == 12)
        #expect(daystamp.day == 31)
    }

    @Test func testConvertsFromDateWithPositiveDeadlineEarlierInDay() async throws {
        let date = date(year: 1970, month: 1, day: 1, hour: 2, minute: 0)
        let daystamp = Daystamp(fromDate: date, deadline: OneHourInSeconds)
        #expect(daystamp.year == 1970)
        #expect(daystamp.month == 1)
        #expect(daystamp.day == 1)
    }

    @Test func testConvertsFromDateWithNegativeDeadlineLaterInDay() async throws {
        let date = date(year: 1970, month: 1, day: 1, hour: 0, minute: 0)
        let daystamp = Daystamp(fromDate: date, deadline: -OneHourInSeconds)
        #expect(daystamp.year == 1970)
        #expect(daystamp.month == 1)
        #expect(daystamp.day == 1)
    }

    @Test func testConvertsFromDateWithNegativeDeadlineEarlierInDay() async throws {
        let date = date(year: 1970, month: 1, day: 1, hour: 23, minute: 0)
        let daystamp = Daystamp(fromDate: date, deadline: -2 * OneHourInSeconds)
        #expect(daystamp.year == 1970)
        #expect(daystamp.month == 1)
        #expect(daystamp.day == 2)
    }

    @Test func testConvertsFromDateAtStartOfNegativeDaystamp() async throws {
        // Ensure there is not an off-by one error when importing values right on the datestamp boundary
        let date = date(year: 1970, month: 1, day: 1, hour: 23, minute: 0)
        let daystamp = Daystamp(fromDate: date, deadline: -OneHourInSeconds)
        #expect(daystamp == Daystamp(year: 1970, month: 1, day: 2))
    }

    @Test func testConvertsFromDateAtStartOfPositiveDaystamp() async throws {
        // Ensure there is not an off-by one error when importing values right on the datestamp boundary
        let date = date(year: 1970, month: 1, day: 1, hour: 1, minute: 0)
        let daystamp = Daystamp(fromDate: date, deadline: OneHourInSeconds)
        #expect(daystamp == Daystamp(year: 1970, month: 1, day: 1))
    }

    @Test func testComparesCorrectly() async throws {
        #expect(Daystamp(year: 2023, month: 7, day: 11) < Daystamp(year: 2023, month: 7, day: 12))
        #expect(Daystamp(year: 2023, month: 7, day: 11) < Daystamp(year: 2023, month: 8, day: 10))
        #expect(Daystamp(year: 2023, month: 7, day: 11) < Daystamp(year: 2024, month: 6, day: 10))
        #expect(Daystamp(year: 2023, month: 7, day: 11) == Daystamp(year: 2023, month: 7, day: 11))
    }

    @Test func testCanAddToDaystamp() async throws {
        #expect(Daystamp(year: 2023, month: 7, day: 11) + 1 == Daystamp(year: 2023, month: 7, day: 12))
        #expect(Daystamp(year: 2023, month: 7, day: 11) + 30 == Daystamp(year: 2023, month: 8, day: 10))
        #expect(Daystamp(year: 2023, month: 7, day: 11) + 365 == Daystamp(year: 2024, month: 7, day: 10)) // Leap year!
    }

    @Test func testCanSubtractFromDaystamp() async throws {
        #expect(Daystamp(year: 2023, month: 7, day: 11) - 1 == Daystamp(year: 2023, month: 7, day: 10))
        #expect(Daystamp(year: 2023, month: 7, day: 11) - 30 == Daystamp(year: 2023, month: 6, day: 11))
        #expect(Daystamp(year: 2023, month: 7, day: 11) - 365 ==  Daystamp(year: 2022, month: 7, day: 11))
    }

    @Test func testCanCountDaysBetweenDaystamps() async throws {
        #expect(Daystamp(year: 2023, month: 7, day: 12) - Daystamp(year: 2023, month: 7, day: 11) == 1)
        #expect(Daystamp(year: 2023, month: 8, day: 10) - Daystamp(year: 2023, month: 7, day: 11) == 30)
        #expect(Daystamp(year: 2024, month: 6, day: 11) - Daystamp(year: 2023, month: 6, day: 11) == 366) // Leap year!
    }

    @Test func testCanCalculateBoundsForZeroDeadline() async throws {
        #expect(Daystamp(year: 1970, month: 1, day: 1).start(deadline: 0) == date(year: 1970, month: 1, day: 1, hour: 0, minute: 0))
        #expect(Daystamp(year: 1970, month: 1, day: 1).end(deadline: 0) == date(year: 1970, month: 1, day: 2, hour: 0, minute: 0))
    }

    @Test func testCanCalculateBoundsForNegativeDeadline() async throws {
        #expect(Daystamp(year: 1970, month: 1, day: 1).start(deadline: -OneHourInSeconds) == date(year: 1969, month: 12, day: 31, hour: 23, minute: 0))
        #expect(Daystamp(year: 1970, month: 1, day: 1).end(deadline: -OneHourInSeconds) == date(year: 1970, month: 1, day: 1, hour: 23, minute: 0))
    }

    @Test func testCanCalculateBoundsForPositiveDeadline() async throws {
        #expect(Daystamp(year: 1970, month: 1, day: 1).start(deadline: OneHourInSeconds) == date(year: 1970, month: 1, day: 1, hour: 1, minute: 0))
        #expect(Daystamp(year: 1970, month: 1, day: 1).end(deadline: OneHourInSeconds) == date(year: 1970, month: 1, day: 2, hour: 1, minute: 0))
    }

    @Test func testCanIterateOverRange() async throws {
        let daystamp = Daystamp(year: 1970, month: 1, day: 1)
        let range = daystamp...(daystamp + 3)
        #expect(Array(range) == [daystamp, daystamp + 1, daystamp + 2, daystamp + 3])
    }
}

private extension DaystampTests {
    func date(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        return Calendar.current.date(from: components)!
    }
}
