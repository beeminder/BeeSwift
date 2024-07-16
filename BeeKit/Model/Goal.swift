import Foundation
import CoreData

import SwiftyJSON

@objc(Goal)
public class Goal: NSManagedObject {
    @NSManaged public var owner: User
    @NSManaged public var id: String
    @NSManaged public var slug: String

    /// Seconds after midnight that we start sending you reminders (on the day that you're scheduled to start getting them).
    @NSManaged public var alertStart: Int
    /// The name of automatic data source, if this goal has one. Will be null for manual goals.
    @NSManaged public var autodata: String?
    /// Seconds by which your deadline differs from midnight. Negative is before midnight, positive is after midnight. Allowed range is -17*3600 to 6*3600 (7am to 6am).
    @NSManaged public var deadline: Int
    /// URL for the goal's graph image. E.g., "http://static.beeminder.com/alice/weight.png".
    @NSManaged public var graphUrl: String
    /// The internal app identifier for the healthkit metric to sync to this goal
    @NSManaged public var healthKitMetric: String
    /// Whether to show data in a "timey" way, with colons. For example, this would make a 1.5 show up as 1:30.
    @NSManaged public var hhmmFormat: Bool
    /// Unix timestamp (in seconds) of the start of the bright red line.
    @NSManaged public var initDay: Int
    /// Undocumented.
    @NSManaged public var lastTouch: Int
    /// Summary of what you need to do to eke by, e.g., "+2 within 1 day".
    @NSManaged public var limSum: String
    /// Days before derailing we start sending you reminders. Zero means we start sending them on the beemergency day, when you will derail later that day.
    @NSManaged public var leadTime: Int
    /// Amount pledged (USD) on the goal.
    @NSManaged public var pledge: Int
    /// Whether the graph is currently being updated to reflect new data.
    @NSManaged public var queued: Bool
    /// The integer number of safe days. If it's a beemergency this will be zero.
    @NSManaged public var safeBuf: Int
    /// Undocumented
    @NSManaged public var safeSum: String
    /// URL for the goal's graph thumbnail image. E.g., "http://static.beeminder.com/alice/weight-thumb.png".
    @NSManaged public var thumbUrl: String
    /// The title that the user specified for the goal. E.g., "Weight Loss".
    @NSManaged public var title: String
    /// Whether there are any datapoints for today.
    @NSManaged public var todayta: Bool
    /// Sort by this key to put the goals in order of decreasing urgency. (Case-sensitive ascii or unicode sorting is assumed).
    @NSManaged public var urgencyKey: String
    /// Undocumented
    @NSManaged public var useDefaults: Bool
    /// Whether the goal has been successfully completed.
    @NSManaged public var won: Bool
    /// The label for the y-axis of the graph. E.g., "Cumulative total hours".
    @NSManaged public var yAxis: String

    @NSManaged public var recentData: NSOrderedSet

    @objc(insertObject:inRecentDataAtIndex:)
    @NSManaged private func insertIntoRecentData(_ value: DataPoint, at idx: Int)
    @objc(removeObjectFromRecentDataAtIndex:)
    @NSManaged private func removeFromRecentData(at idx: Int)
    @objc(insertRecentData:atIndexes:)
    @NSManaged private func insertIntoRecentData(_ values: [DataPoint], at indexes: NSIndexSet)
    @objc(removeRecentDataAtIndexes:)
    @NSManaged private func removeFromRecentData(at indexes: NSIndexSet)
    @objc(replaceObjectInRecentDataAtIndex:withObject:)
    @NSManaged private func replaceRecentData(at idx: Int, with value: DataPoint)
    @objc(replaceRecentDataAtIndexes:withRecentData:)
    @NSManaged private func replaceRecentData(at indexes: NSIndexSet, with values: [DataPoint])
    @objc(addRecentDataObject:)
    @NSManaged private func addToRecentData(_ value: DataPoint)
    @objc(removeRecentDataObject:)
    @NSManaged private func removeFromRecentData(_ value: DataPoint)
    @objc(addRecentData:)
    @NSManaged private func addToRecentData(_ values: NSOrderedSet)
    @objc(removeRecentData:)
    @NSManaged private func removeFromRecentData(_ values: NSOrderedSet)


    public init(
        context: NSManagedObjectContext,
        owner: User,
        id: String,
        slug: String,
        alertStart: Int,
        autodata: String?,
        deadline: Int,
        graphUrl: String,
        healthKitMetric: String,
        hhmmFormat: Bool,
        initDay: Int,
        lastTouch: Int,
        limSum: String,
        leadTime: Int,
        pledge: Int,
        queued: Bool,
        safeBuf: Int,
        safeSum: String,
        thumbUrl: String,
        title: String,
        todayta: Bool,
        urgencyKey: String,
        useDefaults: Bool,
        won: Bool,
        yAxis: String
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "Goal", in: context)!
        super.init(entity: entity, insertInto: context)
        self.owner = owner
        self.id = id
        self.slug = slug
        self.alertStart = alertStart
        self.autodata = autodata
        self.deadline = deadline
        self.graphUrl = graphUrl
        self.healthKitMetric = healthKitMetric
        self.hhmmFormat = hhmmFormat
        self.initDay = initDay
        self.lastTouch = lastTouch
        self.limSum = limSum
        self.leadTime = leadTime
        self.pledge = pledge
        self.queued = queued
        self.safeBuf = safeBuf
        self.safeSum = safeSum
        self.thumbUrl = thumbUrl
        self.title = title
        self.todayta = todayta
        self.urgencyKey = urgencyKey
        self.useDefaults = useDefaults
        self.won = won
        self.yAxis = yAxis
    }

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

        self.alertStart = json["alertstart"].intValue
        self.autodata = json["autodata"].string
        self.deadline = json["deadline"].intValue
        self.graphUrl = json["graph_url"].stringValue
        self.healthKitMetric = json["healthkitmetric"].stringValue
        self.hhmmFormat = json["hhmmformat"].boolValue
        self.initDay = json["initday"].intValue
        self.lastTouch = json["updated_at"].intValue
        self.limSum = json["limsum"].stringValue
        self.leadTime = json["leadtime"].intValue
        self.pledge = json["pledge"].intValue
        self.queued = json["queued"].boolValue
        self.safeBuf = json["safebuf"].intValue
        self.safeSum = json["safesum"].stringValue
        self.thumbUrl = json["thumb_url"].stringValue
        self.title = json["title"].stringValue
        self.todayta = json["todayta"].boolValue
        self.urgencyKey = json["urgencykey"].stringValue
        self.useDefaults = json["use_defaults"].boolValue
        self.won = json["won"].boolValue
        self.yAxis = json["yaxis"].stringValue

        // Replace recent data with results from server
        // Note at present this leaks data points in the main db. This is probably fine for now
        let newRecentData = NSOrderedSet(array: json["recent_data"].arrayValue.map {
            DataPoint.fromJSON(context: self.managedObjectContext!, goal: self, json: $0)
        })
        removeFromRecentData(recentData)
        addToRecentData(newRecentData)
    }

    public var isDataProvidedAutomatically: Bool {
        guard let autodata = self.autodata else {
            return false
        }
        return !autodata.isEmpty
    }

    public var hideDataEntry: Bool {
        return isDataProvidedAutomatically || won
    }
}
