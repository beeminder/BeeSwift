import Foundation
import CoreData

public class User: NSManagedObject {
    @NSManaged public var username: String
    @NSManaged public var deadbeat: Bool
    @NSManaged public var timezone: String
    @NSManaged public var defaultAlertStart: Int32
    @NSManaged public var defaultDeadline: Int32
    @NSManaged public var defaultLeadTime: Int32

    @NSManaged public var goals: Set<Goal>
    @NSManaged func addGoalsObject(value: Goal)
    @NSManaged func removeGoalsObject(value: Goal)
    @NSManaged func addGoals(value: Set<Goal>)
    @NSManaged func removeGoals(value: Set<Goal>)

    public init(context: NSManagedObjectContext,
                username: String,
                deadbeat: Bool,
                timezone: String,
                defaultAlertStart: Int32,
                defaultDeadline: Int32,
                defaultLeadTime: Int32
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "User", in: context)!
        super.init(entity: entity, insertInto: context)
        self.username = username
        self.deadbeat = deadbeat
        self.timezone = timezone
        self.defaultAlertStart = defaultAlertStart
        self.defaultDeadline = defaultDeadline
        self.defaultLeadTime = defaultLeadTime
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
}
