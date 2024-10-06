import Foundation
import SwiftData

import SwiftyJSON

@Model public class Goal {
    public var owner: User
    public var id: String
    public var slug: String

    /// Seconds after midnight that we start sending you reminders (on the day that you're scheduled to start getting them).
    public var alertStart: Int
    /// The name of automatic data source, if this goal has one. Will be null for manual goals.
    public var autodata: String?
    /// Seconds by which your deadline differs from midnight. Negative is before midnight, positive is after midnight. Allowed range is -17*3600 to 6*3600 (7am to 6am).
    public var deadline: Int
    /// URL for the goal's graph image. E.g., "http://static.beeminder.com/alice/weight.png".
    public var graphUrl: String
    /// The internal app identifier for the healthkit metric to sync to this goal
    public var healthKitMetric: String?
    /// Whether to show data in a "timey" way, with colons. For example, this would make a 1.5 show up as 1:30.
    public var hhmmFormat: Bool
    /// Unix timestamp (in seconds) of the start of the bright red line.
    public var initDay: Int
    /// Undocumented.
    public var lastTouch: String
    /// Summary of what you need to do to eke by, e.g., "+2 within 1 day".
    public var limSum: String
    /// Days before derailing we start sending you reminders. Zero means we start sending them on the beemergency day, when you will derail later that day.
    public var leadTime: Int
    /// Amount pledged (USD) on the goal.
    public var pledge: Int
    /// Whether the graph is currently being updated to reflect new data.
    public var queued: Bool
    /// The integer number of safe days. If it's a beemergency this will be zero.
    public var safeBuf: Int
    /// Undocumented
    public var safeSum: String
    /// URL for the goal's graph thumbnail image. E.g., "http://static.beeminder.com/alice/weight-thumb.png".
    public var thumbUrl: String
    /// The title that the user specified for the goal. E.g., "Weight Loss".
    public var title: String
    /// Whether there are any datapoints for today.
    public var todayta: Bool
    /// Sort by this key to put the goals in order of decreasing urgency. (Case-sensitive ascii or unicode sorting is assumed).
    public var urgencyKey: String
    /// Undocumented
    public var useDefaults: Bool
    /// Whether the goal has been successfully completed.
    public var won: Bool
    /// The label for the y-axis of the graph. E.g., "Cumulative total hours".
    public var yAxis: String

    @Relationship(deleteRule: .cascade) var data: Set<DataPoint>

    public var recentData: Set<DataPoint>


    /// The last time this record in the CoreData store was updated
    public var lastModifiedLocal: Date

    public init(
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
        lastTouch: String,
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

        lastModifiedLocal = Date()
    }

    public init(owner: User, json: JSON) {
        self.owner = owner
        self.id = json["id"].string!

        self.updateToMatch(json: json)
    }

    // Question: Should this type know about JSON, or should there be an adapter / extension?
    public func updateToMatch(json: JSON) {
        self.slug = json["slug"].string!

        self.alertStart = json["alertstart"].intValue
        self.autodata = json["autodata"].string
        self.deadline = json["deadline"].intValue
        self.graphUrl = json["graph_url"].stringValue
        self.healthKitMetric = json["healthkitmetric"].string
        self.hhmmFormat = json["hhmmformat"].boolValue
        self.initDay = json["initday"].intValue
        self.lastTouch = json["lasttouch"].stringValue
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
        let newRecentData = Set<DataPoint>(json["recent_data"].arrayValue.map {
            DataPoint.fromJSON(context: self.managedObjectContext!, goal: self, json: $0)
        })

        removeFromRecentData(recentData)
        addToRecentData(newRecentData)

        lastModifiedLocal = Date()
    }
}
