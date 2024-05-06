import Foundation
import CoreData

import SwiftyJSON

@objc(Goal)
public class Goal: NSManagedObject {
    @NSManaged public var owner: User
    @NSManaged public var id: String
    @NSManaged public var slug: String

    @NSManaged public var autodata: String?
    @NSManaged public var deadline: Int
    @NSManaged public var limSum: String
    @NSManaged public var thumbUrl: String
    @NSManaged public var won: Bool

    public init(context: NSManagedObjectContext, owner: User, id: String, slug: String) {
        let entity = NSEntityDescription.entity(forEntityName: "Goal", in: context)!
        super.init(entity: entity, insertInto: context)
        self.owner = owner
        self.id = id
        self.slug = slug
    }

    // Question: Should this type know about JSON, or should there be an adapter / extension?
    public init(context: NSManagedObjectContext, owner: User, json: JSON) {
        let entity = NSEntityDescription.entity(forEntityName: "Goal", in: context)!
        super.init(entity: entity, insertInto: context)
        self.owner = owner
        self.id = json["id"].stringValue

        self.updateToMatch(json: json)
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
    
    // Question: Should this type know about JSON, or should there be an adapter / extension?
    public func updateToMatch(json: JSON) {
        self.slug = json["slug"].stringValue
    }

    public var isDataProvidedAutomatically: Bool {
        guard let autodata = self.autodata else {
            return false
        }
        return !autodata.isEmpty
    }

    public var hideDataEntry: Bool {
        // TODO: Implement this
        return isDataProvidedAutomatically || won
    }
}
