// Types representing an individual data point within a goal

import Foundation
import SwiftyJSON

protocol DataPoint {
    var daystamp: String { get }
    var value: NSNumber { get }
    var comment: String { get }
}

/// A data point received from the server. This will have had an ID allocated
struct ExistingDataPoint : DataPoint {
    let id: String
    let daystamp: String
    let value: NSNumber
    let comment: String

    init(json: JSON) {
        // To maximize compatibility with server changes we only parse fields
        // which are actually used, not all that exist
        id = json["id"]["$oid"].stringValue
        daystamp = json["daystamp"].stringValue
        value = json["value"].numberValue
        comment = json["comment"].stringValue
    }

    static func fromJSONArray(array: [JSON]) -> [ExistingDataPoint] {
        return array.map { ExistingDataPoint(json: $0) }
    }
}

/// A data point we have created locally (e.g. from user input, or HealthKit)
struct NewDataPoint : DataPoint {
    let daystamp: String
    let value: NSNumber
    let comment: String
}
