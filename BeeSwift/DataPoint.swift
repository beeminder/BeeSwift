// Types representing an individual data point within a goal

import Foundation
import SwiftyJSON

protocol DataPoint {
    var daystamp: String { get }
    var value: NSNumber { get }
    var comment: String { get }
}

struct ExistingDataPoint : DataPoint {
    let id: String
    let daystamp: String
    let value: NSNumber
    let comment: String

    init(json: JSON) {
        id = json["id"]["$oid"].stringValue
        daystamp = json["daystamp"].stringValue
        value = json["value"].numberValue
        comment = json["comment"].stringValue
    }

    static func fromJSONArray(array: [JSON]) -> [ExistingDataPoint] {
        return array.map { ExistingDataPoint(json: $0) }
    }
}

struct NewDataPoint : DataPoint {
    let daystamp: String
    let value: NSNumber
    let comment: String
}
