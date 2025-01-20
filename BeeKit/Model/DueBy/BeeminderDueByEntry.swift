// Part of BeeSwift. Copyright Beeminder

import SwiftyJSON

@objc(BeeminderDueByEntry)
public class BeeminderDueByEntry: NSObject, Codable {
    public let total: Double
    public let delta: Double
    public let formattedTotal: String
    public let formattedDelta: String
    
    init(total: Double, delta: Double, formattedTotalForBeedroid: String, formattedDeltaForBeedroid: String) {
        self.total = total
        self.delta = delta
        self.formattedTotal = formattedTotalForBeedroid
        self.formattedDelta = formattedDeltaForBeedroid
    }
    
    private enum CodingKey: String {
        case total
        case delta
        case formattedTotal = "formatted_total_for_beedroid"
        case formattedDelta = "formatted_delta_for_beedroid"
    }
    
    public init(json: JSON) {
        self.delta = json["delta"].doubleValue
        self.total = json["total"].doubleValue
        
        self.formattedDelta = json["formatted_delta_for_beedroid"].stringValue
        self.formattedTotal = json["formatted_total_for_beedroid"].stringValue
    }
}
