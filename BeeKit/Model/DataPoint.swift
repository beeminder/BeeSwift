import Foundation
import SwiftData

import SwiftyJSON

@Model public class DataPoint: BeeDataPoint {
    // Server identified for the datapoint, globally unique.
    public var id: String
    // Goal this datapoint is associated with
    public var goal: Goal

    // An optional comment about the datapoint.
    // TODO: Check if this can be null
    public var comment: String
    // The date of the datapoint (e.g., "20150831"). Raw value in the datastore
    private var daystampRaw: String
    // If a datapoint was created via the API and this parameter was included, it will be echoed back.
    public var requestid: String
    // The value, e.g., how much you weighed on the day indicated by the timestamp.
    public var value: NSNumber

    public var updatedAt: Int

    /// The last time this record in the CoreData store was updated
    public var lastModifiedLocal: Date

    public init(goal: Goal, id: String, comment: String, daystamp: Daystamp, requestid: String, value: NSNumber, updatedAt: Int) {
        self.goal = goal
        self.id = id
        self.comment = comment
        self.daystamp = daystamp
        self.requestid = requestid
        self.value = value
        self.updatedAt = updatedAt
        lastModifiedLocal = Date()
    }

    private init(id: String, goal: Goal, json: JSON) {
        self.id = id
        self.goal = goal

        self.updateToMatch(json: json)
    }

    /// Produce a DataPoint matching the supplied JSON, either creating a new one or re-using an existing object in the datastore
    public static func fromJSON(goal: Goal, json: JSON) -> DataPoint {
        // Check for an existing datapoint with the relevant ID, if so use it
        let id = json["id"].string!

        // TODO: Learn to find existing instance
//        let fetchRequest = NSFetchRequest<DataPoint>(entityName: "DataPoint")
//        fetchRequest.predicate = NSPredicate(format: "id == %@", id)
//        fetchRequest.fetchLimit = 1
//        if let existing = try? context.fetch(fetchRequest).first {
//            existing.updateToMatch(json: json)
//            return existing
//        }

        return DataPoint(id: id, goal: goal, json: json)
    }

    public func updateToMatch(json: JSON) {
        daystampRaw = json["daystamp"].stringValue
        value = json["value"].numberValue
        comment = json["comment"].stringValue
        requestid = json["requestid"].stringValue
        updatedAt = json["updated_at"].intValue
        lastModifiedLocal = Date()
    }

    public var daystamp: Daystamp {
        get {
            return try! Daystamp(fromString: daystampRaw)
        }
        set {
            daystampRaw = newValue.description
        }
    }
}

extension DataPoint {
    private static var metaPointHashtags = Set(["#DERAIL", "#SELFDESTRUCT", "#THISWILLSELFDESTRUCT", "#RESTART", "#TARE"])

    /// Is this a DataPoint containing metadata, rather than a real value
    /// DataPoints are used to track certain events, like automatic pessimistic values, goal restarts, derailments, etc. These should sometimes
    /// be treated differently, e.g. not deleted as part of syncing with HealthKit
    public var isMeta: Bool {
        DataPoint.metaPointHashtags.contains { comment.contains($0) }
    }
}
