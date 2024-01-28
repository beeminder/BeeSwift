import Foundation

public struct Daystamp: CustomStringConvertible, Strideable, Comparable, Equatable, Hashable {
    public typealias Stride = Int

    private static let daystampPattern = try! NSRegularExpression(pattern: "^(?<year>\\d{4})(?<month>\\d{2})(?<day>\\d{2})$")
    private static let minutesInDay = 24 * 60

    private static let calendar = {
        var calendar = Calendar(identifier: .iso8601)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone.autoupdatingCurrent
        return calendar
    }()

    public let year, month, day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(fromString daystamp: String) throws {
        let range = NSRange(location: 0, length: daystamp.utf16.count)
        guard let matchResult = Daystamp.daystampPattern.firstMatch(in: daystamp, range: range) else {
            // TODO: This should throw an error instead
            fatalError("That wasn't a daystamp!")
        }

        // Errors here are impossible as the regex has verifed these ranges exist and are numbers
        let year = Int(daystamp[Range(matchResult.range(withName: "year"), in: daystamp)!])!
        let month = Int(daystamp[Range(matchResult.range(withName: "month"), in: daystamp)!])!
        let day = Int(daystamp[Range(matchResult.range(withName: "day"), in: daystamp)!])!

        self.init(year: year, month: month, day: day)
    }

    init(fromDate date: Date, deadline: Int) {
        let minutesAfterMidnight = Daystamp.calendar.component(.hour, from: date) * 60 + Daystamp.calendar.component(.minute, from: date)

        let dayOffsetFromDeadline = if deadline < 0 {
            // This is an early deadline. If the time is after the deadline we need to instead consider it the next day
            if minutesAfterMidnight > Daystamp.minutesInDay + deadline {
                1
            } else {
                0
            }
        } else {
            // This is a late deadline. If the time is before the deadline, we should consider it the previous day
            if minutesAfterMidnight < deadline {
                -1
            } else {
                0
            }
        }
        let adjustedDate = Daystamp.calendar.date(byAdding: DateComponents(calendar:Daystamp.calendar, day: dayOffsetFromDeadline), to: date)!

        self.init(fromDate: adjustedDate)
    }

    /// Private constructor to make a daystamp from the components of a date which is used internally by the class for date math
    /// Public users of the class should use init(fromDate:deadline) to make sure deadline adjustments are done correctly.
    private init(fromDate date: Date) {
        let components = Daystamp.calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: components.year!, month: components.month!, day: components.day!)
    }

    static func now(deadline: Int) -> Daystamp {
        return Daystamp(fromDate: Date(), deadline: deadline)
    }

    /// The Date corresponding to the start of this Daystamp (inclusive)
    /// Note this uses the system timezone to determine when days start and end, which may not match the user's timezone
    func start(deadline: Int) -> Date {
        return Daystamp.calendar.date(from: DateComponents(calendar: Daystamp.calendar, year: year, month: month, day: day, minute: deadline))!
    }

    /// The Date corresponding to the end of this Daystamp (exclusive)
    /// Note this uses the system timezone to determine when days start and end, which may not match the user's timezone
    func end(deadline: Int) -> Date {
        return self.advanced(by: 1).start(deadline: deadline)
    }

    public static func + (lhs: Daystamp, rhs: Int) -> Daystamp {
        return lhs.advanced(by: rhs)
    }

    public static func - (lhs: Daystamp, rhs: Int) -> Daystamp {
        return lhs.advanced(by: -rhs)
    }

    public static func - (lhs: Daystamp, rhs: Daystamp) -> Int {
        return rhs.distance(to: lhs)
    }

    // Trait: CustomStringConvertible

    public var description: String {
        return String(format: "%04d%02d%02d", year, month, day)
    }

    // Trait: Strideable

    public func distance(to other: Daystamp) -> Int {

        let selfDate = Daystamp.calendar.date(from: DateComponents(calendar: Daystamp.calendar, year: year, month: month, day: day))!
        let otherDate = Daystamp.calendar.date(from: DateComponents(calendar: Daystamp.calendar, year: other.year, month: other.month, day: other.day))!

        return Calendar.current.dateComponents([.day], from: selfDate, to: otherDate).day!
    }

    public func advanced(by n: Int) -> Daystamp {
        let date = Daystamp.calendar.date(from: DateComponents(calendar: Daystamp.calendar, year: year, month: month, day: day))!

        let adjustedDate = Daystamp.calendar.date(byAdding: DateComponents(calendar:Daystamp.calendar, day: n), to: date)!
        return Daystamp(fromDate: adjustedDate)
    }

    // Trait: Comparable

    public static func < (lhs: Daystamp, rhs: Daystamp) -> Bool {
        if lhs.year < rhs.year {
            return true
        } else if lhs.year > rhs.year {
            return false
        }

        if lhs.month < rhs.month {
            return true
        } else if lhs.month > rhs.month {
            return false
        }

        return lhs.day < rhs.day
    }

    // Trait: Equatable
    // This is generated automatically for structs by the compiler

    // Trait: Hashable
    // This is generated automatically for structs by the compiler
}
