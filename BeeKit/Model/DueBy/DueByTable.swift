// Part of BeeSwift. Copyright Beeminder

import SwiftyJSON

@objc(DueByTable)
public class DueByTable: NSObject, Codable {
    /// a dictionary of due by deltas and totals to daystamp strings
    public private(set) var entries: [String: BeeminderDueByEntry]
    
    private enum Key: String {
        case entries
    }
    
    public init(entries: [String: BeeminderDueByEntry]) {
        self.entries = entries
    }

    convenience init(dueByJson: JSON?) {
        let entries = dueByJson?.dictionary?.mapValues(BeeminderDueByEntry.init) ?? [:]
        self.init(entries: entries)
    }

    public override var debugDescription: String {
        "DueByTable\n" +
        "yyyymmdd : delta\n" +
        entries
            .sorted { $0.key < $1.key }
            .map { key, value in
                "\(key) : \(value.formatted_delta_for_beedroid)"
            }
            .joined(separator: "\n")
    }
}
