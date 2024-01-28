// Types representing an individual data point within a goal

import Foundation
import SwiftyJSON

public protocol DataPoint {
    var requestid: String { get }
    var daystamp: Daystamp { get }
    var value: NSNumber { get }
    var comment: String { get }
}

/// A data point received from the server. This will have had an ID allocated
public struct ExistingDataPoint : DataPoint {
    public let id: String
    public let requestid: String
    public let daystamp: Daystamp
    public let value: NSNumber
    public let comment: String

    init(json: JSON) throws {
        // To maximize compatibility with server changes we only parse fields
        // which are actually used, not all that exist
        id = json["id"]["$oid"].string ?? json["id"].stringValue
        daystamp = try Daystamp(fromString: json["daystamp"].stringValue)
        value = json["value"].numberValue
        comment = json["comment"].stringValue
        requestid = json["requestid"].stringValue
    }

    static func fromJSONArray(array: [JSON]) throws -> [ExistingDataPoint] {
        return try array.map { try ExistingDataPoint(json: $0) }
    }
}

/// A data point we have created locally (e.g. from user input, or HealthKit)
public struct NewDataPoint : DataPoint {
    public let requestid: String
    public let daystamp: Daystamp
    public let value: NSNumber
    public let comment: String
}
