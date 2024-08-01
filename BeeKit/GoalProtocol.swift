import Foundation
import UIKit

public protocol GoalProtocol : AnyObject {
    var id: String { get }
    var slug: String { get }
    var deadline: Int { get }
    var initDay: Int { get }
    var queued: Bool { get }
    var lastTouch: String { get }
    var graphUrl: String { get }
    var thumbUrl: String { get }
    var safeBuf: Int { get }
    var leadTime: Int { get }
    var useDefaults: Bool { get }
    var alertStart: Int { get }
    var title: String { get }
    var todayta: Bool { get }
    var safeSum: String { get }
    var won: Bool { get }
    var hhmmFormat: Bool { get }
    var yAxis: String { get }
    var pledge: Int { get }
    var urgencyKey: String { get }
    var recentData: Set<DataPoint> { get }

    // Allow setters for synx test, for now
    var autodata: String? { get set }
    var healthKitMetric: String? { get set }
}

extension GoalProtocol {
    public var humanizedAutodata: String? {
        if self.autodata == "ifttt" { return "IFTTT" }
        if self.autodata == "api" { return "API" }
        if self.autodata == "apple" {
            let metric = HealthKitConfig.shared.metrics.first(where: { (metric) -> Bool in
                metric.databaseString == self.healthKitMetric
            })
            return self.healthKitMetric == nil ? "Apple" : metric?.humanText
        }
        if let autodata = self.autodata, autodata.count > 0 { return autodata.capitalized }
        return nil
    }

    public var isDataProvidedAutomatically: Bool {
        return !(self.autodata ?? "").isEmpty
    }

    /// The daystamp corresponding to the day of the goal's creation, thus the first day we should add data points for.
    var initDaystamp: Daystamp {
        let initDate = Date(timeIntervalSince1970: Double(self.initDay))

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"

        // initDate is constructed such that if we resolve it to a datetime in US Eastern Time, the date part
        // of that is guaranteed to be the user's local date on the day the goal was created.
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        let dateString = formatter.string(from: initDate)

        return try! Daystamp(fromString: dateString)
    }

    public var cacheBustingThumbUrl: String {
        let thumbUrlStr = self.thumbUrl
        return cacheBuster(thumbUrlStr)
    }

    public var cacheBustingGraphUrl: String {
        let graphUrlStr = self.graphUrl
        return cacheBuster(graphUrlStr)
    }

    private func cacheBuster(_ originUrlStr: String) -> String {
        let queryCharacter = originUrlStr.range(of: "&") == nil ? "?" : "&"

        let cacheBustingUrlStr = "\(originUrlStr)\(queryCharacter)proctime=\(self.lastTouch)"

        return cacheBustingUrlStr
    }

    public func capitalSafesum() -> String {
        return self.safeSum.prefix(1).uppercased() + self.safeSum.dropFirst(1)
    }

    public var countdownColor :UIColor {
        let buf = self.safeBuf
        if buf < 1 {
            return UIColor.beeminder.red
        }
        else if buf < 2 {
            return UIColor.beeminder.orange
        }
        else if buf < 3 {
            return UIColor.beeminder.blue
        }
        return UIColor.beeminder.green
    }

    public func hideDataEntry() -> Bool {
        return self.isDataProvidedAutomatically || self.won
    }

    public var isLinkedToHealthKit: Bool {
        return self.autodata == "apple"
    }

    /// A hint for the value the user is likely to enter, based on past data points
    public var suggestedNextValue: NSNumber? {
        let recentData = self.recentData
        for dataPoint in recentData.sorted(by: { $0.updatedAt > $1.updatedAt }) {
            let comment = dataPoint.comment
            // Ignore data points with comments suggesting they aren't a real value
            if comment.contains("#DERAIL") || comment.contains("#SELFDESTRUCT") || comment.contains("#THISWILLSELFDESTRUCT") || comment.contains("#RESTART") || comment.contains("#TARE") {
                continue
            }
            return dataPoint.value
        }
        return nil
    }
}
