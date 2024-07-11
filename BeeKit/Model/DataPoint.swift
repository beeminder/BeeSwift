import Foundation
import CoreData

import SwiftyJSON

@objc(DataPoint)
public class DataPoint: NSManagedObject {
    // Server identified for the datapoint, globally unique.
    @NSManaged public var id: String?
    // Goal this datapoint is associated with
    @NSManaged public var goal: Goal

    // An optional comment about the datapoint.
    // TODO: Check if this can be null
    @NSManaged public var comment: String
    // The date of the datapoint (e.g., "20150831"). Raw value in the datastore
    @NSManaged private var daystampRaw: String
    // If a datapoint was created via the API and this parameter was included, it will be echoed back.
    @NSManaged public var requestid: String?
    // The value, e.g., how much you weighed on the day indicated by the timestamp.
    @NSManaged public var value: NSNumber

    public init(context: NSManagedObjectContext, goal: Goal, id: String?, comment: String, daystamp: Daystamp, requestid: String?, value: NSNumber) {
        let entity = NSEntityDescription.entity(forEntityName: "DataPoint", in: context)!
        super.init(entity: entity, insertInto: context)
        self.goal = goal
        self.id = id
        self.comment = comment
        self.daystamp = daystamp
        self.requestid = requestid
        self.value = value
    }

    @available(*, unavailable)
    public init() {
        fatalError()
    }

    @available(*, unavailable)
    public init(context: NSManagedObjectContext) {
        fatalError()
    }

    public override init(entity: NSEntityDescription, insertInto: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: insertInto)
    }

    private init(context: NSManagedObjectContext, id: String, goal: Goal, json: JSON) {
        let entity = NSEntityDescription.entity(forEntityName: "DataPoint", in: context)!
        super.init(entity: entity, insertInto: context)
        self.id = id
        self.goal = goal

        self.updateToMatch(json: json)
    }

    /// Produce a DataPoint matching the supplied JSON, either creating a new one or re-using an existing object in the datastore
    public static func fromJSON(context: NSManagedObjectContext, goal: Goal, json: JSON) -> DataPoint {
        // Check for an existing datapoint with the relevant ID, if so use it
        let id = json["id"].stringValue

        let fetchRequest = NSFetchRequest<DataPoint>(entityName: "DataPoint")
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        fetchRequest.fetchLimit = 1
        if let existing = try? context.fetch(fetchRequest).first {
            existing.updateToMatch(json: json)
            return existing
        }

        return DataPoint(context: context, id: id, goal: goal, json: json)
    }

    public func updateToMatch(json: JSON) {
        daystampRaw = json["daystamp"].stringValue
        value = json["value"].numberValue
        comment = json["comment"].stringValue
        requestid = json["requestid"].stringValue
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
