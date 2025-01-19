// Part of BeeSwift. Copyright Beeminder

import SwiftyJSON

public class BeeminderDueByEntry: NSObject, NSSecureCoding, Codable {
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
    
    public static var supportsSecureCoding: Bool { true }

    private enum CodingKey: String {
        case total
        case delta
        case formattedTotalForBeedroid
        case formattedDeltaForBeedroid
    }
    
    public func encode(with coder: NSCoder) {
        coder.encode(total, forKey: CodingKey.total.rawValue)
        coder.encode(delta, forKey: CodingKey.delta.rawValue)
        coder.encode(formatted_total_for_beedroid, forKey: CodingKey.formattedTotalForBeedroid.rawValue)
        coder.encode(formatted_delta_for_beedroid, forKey: CodingKey.formattedDeltaForBeedroid.rawValue)
    }
    
    public required convenience init?(coder: NSCoder) {
        let total = coder.decodeDouble(forKey: CodingKey.total.rawValue)
        let delta = coder.decodeDouble(forKey: CodingKey.delta.rawValue)
        
        guard
            let formatted_total_for_beedroid = coder.decodeObject(of: NSString.self, forKey: CodingKey.formattedTotalForBeedroid.rawValue) as? String,
            let formatted_delta_for_beedroid = coder.decodeObject(of: NSString.self, forKey: CodingKey.formattedDeltaForBeedroid.rawValue) as? String
        else { return nil }
        
        self.init(total: total,
                  delta: delta,
                  formatted_total_for_beedroid: formatted_total_for_beedroid,
                  formatted_delta_for_beedroid: formatted_delta_for_beedroid)
    }
}
