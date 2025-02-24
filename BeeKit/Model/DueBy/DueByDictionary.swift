// Part of BeeSwift. Copyright Beeminder

import SwiftyJSON

/// Delta and Total due by YYYYMMDD daystamp
public typealias DueByDictionary = [String: DueByEntry]

extension DueByDictionary {
    /// Creates a DueByDictionary from SwiftyJSON
    /// - Parameter json: JSON object containing due by data
    /// - Returns: Dictionary mapping daystamps to DueByEntry objects
    public init(json: JSON) {
        self = json.dictionaryValue.compactMapValues(DueByEntry.init)
    }
}
