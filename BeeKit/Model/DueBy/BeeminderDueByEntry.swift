// Part of BeeSwift. Copyright Beeminder

import SwiftyJSON

@objc(BeeminderDueByEntry)
public class BeeminderDueByEntry: NSObject, Codable {
    public let total: Double
    public let delta: Double
    public let formatted_total_for_beedroid: String
    public let formatted_delta_for_beedroid: String
    
    init(total: Double, delta: Double, formatted_total_for_beedroid: String, formatted_delta_for_beedroid: String) {
        self.total = total
        self.delta = delta
        self.formatted_total_for_beedroid = formatted_total_for_beedroid
        self.formatted_delta_for_beedroid = formatted_delta_for_beedroid
    }
    
    public init(json: JSON) {
        self.delta = json["delta"].doubleValue
        self.total = json["total"].doubleValue

        self.formatted_delta_for_beedroid = json["formatted_delta_for_beedroid"].stringValue
        self.formatted_total_for_beedroid = json["formatted_total_for_beedroid"].stringValue
    }
}
