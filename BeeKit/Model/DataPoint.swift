import Foundation
import CoreData

public class DataPoint: NSManagedObject {
    @NSManaged public var id: String

    public init(context: NSManagedObjectContext, id: String) {
        let entity = NSEntityDescription.entity(forEntityName: "DataPoint", in: context)!
        super.init(entity: entity, insertInto: context)
        self.id = id
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
