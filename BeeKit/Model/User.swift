import CoreData
import Foundation
import SwiftyJSON

@objc(User) public class User: NSManagedObject {
  @NSManaged public var username: String
  @NSManaged public var deadbeat: Bool
  @NSManaged public var timezone: String
  @NSManaged public var updatedAt: Date
  @NSManaged public var defaultAlertStart: Int
  @NSManaged public var defaultDeadline: Int
  @NSManaged public var defaultLeadTime: Int

  /// The model version identifier when goals were last fetched from the server.
  /// Used to detect when a full refresh is needed after data model changes.
  @NSManaged public var lastFetchedModelVersionLocal: String?

  @NSManaged public var goals: Set<Goal>
  @NSManaged func addGoalsObject(value: Goal)
  @NSManaged func removeGoalsObject(value: Goal)
  @NSManaged func addGoals(value: Set<Goal>)
  @NSManaged func removeGoals(value: Set<Goal>)

  /// The last time this record in the CoreData store was updated
  @NSManaged public var lastUpdatedLocal: Date

  public init(
    context: NSManagedObjectContext,
    username: String,
    deadbeat: Bool,
    timezone: String,
    updatedAt: Date,
    defaultAlertStart: Int,
    defaultDeadline: Int,
    defaultLeadTime: Int
  ) {
    let entity = NSEntityDescription.entity(forEntityName: "User", in: context)!
    super.init(entity: entity, insertInto: context)
    self.username = username
    self.deadbeat = deadbeat
    self.timezone = timezone
    self.updatedAt = updatedAt
    self.defaultAlertStart = defaultAlertStart
    self.defaultDeadline = defaultDeadline
    self.defaultLeadTime = defaultLeadTime

    lastUpdatedLocal = Date()
  }

  public init(context: NSManagedObjectContext, json: JSON) {
    let entity = NSEntityDescription.entity(forEntityName: "User", in: context)!
    super.init(entity: entity, insertInto: context)

    self.updateToMatch(json: json)
  }

  public func updateToMatch(json: JSON) {
    self.username = json["username"].string!
    self.deadbeat = json["deadbeat"].bool!
    self.timezone = json["timezone"].string!
    self.updatedAt = Date(timeIntervalSince1970: json["updated_at"].double!)
    self.defaultAlertStart = json["default_alertstart"].int!
    self.defaultDeadline = json["default_deadline"].int!
    self.defaultLeadTime = json["default_leadtime"].int!

    lastUpdatedLocal = Date()
  }

  @available(*, unavailable) public init() { fatalError() }

  @available(*, unavailable) public init(context: NSManagedObjectContext) { fatalError() }

  public override init(entity: NSEntityDescription, insertInto: NSManagedObjectContext?) {
    super.init(entity: entity, insertInto: insertInto)
  }
}
