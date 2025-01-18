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
    
    convenience init(dueByJson: JSON?) {
        var entries: [String : BeeminderDueByEntry] {
            dueByJson?.dictionary?.compactMapValues(BeeminderDueByEntry.init)
            ?? dueByJson?.dictionary?.mapValues(BeeminderDueByEntry.init)
            ?? [:]
        }
        self.init(entries: entries)
    }
}
