import Foundation

public protocol GoalProtocol : AnyObject {
    var id: String { get }
    var slug: String { get }
    var autodata: String? { get }
    var healthKitMetric: String? { get }
    var deadline: Int { get }
    var initDay: Int { get }
    var queued: Bool { get }
    var lastTouch: Int { get }
    var graphUrl: String { get }
    var thumbUrl: String { get }
    var safeBuf: Int { get }
    var leadTime: Int { get }
    var useDefaults: Bool { get }
    var alertStart: Int { get }
    var title: String { get }
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



}
