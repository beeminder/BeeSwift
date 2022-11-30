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
        // TODO: But ["id"]["$oid"] also exists! What is the shape here? What should we send the server. Questions abound.
        id = json["id"].stringValue
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
