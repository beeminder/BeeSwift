// Part of BeeSwift. Copyright Beeminder

import SwiftyJSON

@objc(DueByTable)
public class DueByTable: NSObject, NSSecureCoding, Codable {
    /// a dictionary of due by deltas and totals to daystamp strings
    public private(set) var entries: [String: BeeminderDueByEntry]
    
    private enum Key: String {
        case entries
    }
    
    public init(entries: [String: BeeminderDueByEntry]) {
        self.entries = entries
    }
    
    public static var supportsSecureCoding: Bool { true }
    
    public func encode(with coder: NSCoder) {
        coder.encode(entries, forKey: Key.entries.rawValue)
    }
    
    public required convenience init?(coder: NSCoder) {
        let entries = coder.decodeObject(of: NSDictionary.self, forKey: Key.entries.rawValue) as? [String: BeeminderDueByEntry] ?? [:]
        
        self.init(entries: entries)
    }
    
    // Implement custom decoding of the dynamic key : valueType
    required public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.entries = try container.decode([String: BeeminderDueByEntry].self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(entries)
    }
}
