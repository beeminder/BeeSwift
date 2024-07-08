import Foundation
import CoreData

@objc(DataPoint)
public class DataPoint: NSManagedObject {
    @NSManaged public var id: String?
    @NSManaged public var goal: Goal

    @NSManaged public var comment: String
    @NSManaged private var daystampRaw: String
    @NSManaged public var requestid: String?
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

    public var daystamp: Daystamp {
        get {
            return try! Daystamp(fromString: daystampRaw)
        }
        set {
            daystampRaw = newValue.description
        }
    }
}
