import Foundation

public protocol GoalProtocol {
    var slug: String { get }
    var autodata: String? { get }
    var healthKitMetric: String? { get }
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



}
