import Foundation
import UIKit

extension Goal {
    public var humanizedAutodata: String? {
        if self.autodata == "ifttt" { return "IFTTT" }
        if self.autodata == "api" { return "API" }
        if self.autodata == "apple" {
            let metric = HealthKitConfig.metrics.first(where: { $0.databaseString == self.healthKitMetric })
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
        switch self.safeBuf {
        case ..<1:
            return UIColor.Beeminder.SafetyBuffer.red
        case ..<2:
            return UIColor.Beeminder.SafetyBuffer.orange
        case ..<3:
            return UIColor.Beeminder.SafetyBuffer.blue
        case ..<7:
            return UIColor.Beeminder.SafetyBuffer.green
        default:
            return UIColor.Beeminder.SafetyBuffer.forestGreen
        }
    }

    public var hideDataEntry: Bool {
        return self.isDataProvidedAutomatically || self.won
    }

    public var isLinkedToHealthKit: Bool {
        return self.autodata == "apple"
    }

    /// A hint for the value the user is likely to enter, based on past data points
    public var suggestedNextValue: NSNumber? {
        let candidateDatapoints = self.recentData
            .filter { !$0.isDummy }
            .sorted(using: [SortDescriptor(\.updatedAt, order: .reverse)])
        
        return candidateDatapoints.first?.value
    }
}
