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
    @NSManaged public var healthKitMetric: String?
    /// Whether to show data in a "timey" way, with colons. For example, this would make a 1.5 show up as 1:30.
    @NSManaged public var hhmmFormat: Bool
    /// Unix timestamp (in seconds) of the start of the bright red line.
    @NSManaged public var initDay: Int
    /// Undocumented.
    @NSManaged public var lastTouch: String
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

    @NSManaged public var recentData: Set<DataPoint>

    @objc(addRecentDataObject:)
    @NSManaged public func addToRecentData(_ value: DataPoint)
    @objc(removeRecentDataObject:)
    @NSManaged public func removeFromRecentData(_ value: DataPoint)
    @objc(addRecentData:)
    @NSManaged public func addToRecentData(_ values: Set<DataPoint>)
    @objc(removeRecentData:)
    @NSManaged public func removeFromRecentData(_ values: Set<DataPoint>)
    
    @NSManaged public var dueByTable: DueByTable
    
    
    

    /// The last time this record in the CoreData store was updated
    @NSManaged public var lastModifiedLocal: Date

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
        yAxis: String,
        dueBy: String?
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

        lastModifiedLocal = Date()
    }

    public init(context: NSManagedObjectContext, owner: User, json: JSON) {
        let entity = NSEntityDescription.entity(forEntityName: "Goal", in: context)!
        super.init(entity: entity, insertInto: context)
        self.owner = owner
        self.id = json["id"].string!

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
        self.dueByTable = DueByTable(dueByJson: json["dueby"])


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

@objc(DueByTableValueTransformer)
public class DueByTableValueTransformer: ValueTransformer {
    public override class func transformedValueClass() -> AnyClass {
        return NSData.self
    }
    
    public override func transformedValue(_ value: Any?) -> Any? {
        guard let dueByTable = value as? DueByTable else { return nil }
        do {
            return try JSONEncoder().encode(dueByTable)
        } catch {
            print("Error encoding due by table: \(error)")
        }
        return nil
    }

    public override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = (value as? Data) else { return nil }
        do {
            return try JSONDecoder().decode(DueByTable.self, from: data)
        } catch {
            print("Error decoding dictionary: \(error)")
            return nil
        }
    }
    
    public static var name: NSValueTransformerName {
        .init(rawValue: String(describing: DueByTableValueTransformer.self))
    }
    
    public static func register() {
        ValueTransformer.setValueTransformer(DueByTableValueTransformer(),
                                             forName: DueByTableValueTransformer.name)
    }
}

@objc(DueByTable)
public class DueByTable: NSObject, NSSecureCoding, Codable {
    public private(set) var entries: [String: BeeminderDueByEntry]
    
    private enum Key: String {
        case entries
    }
    
    public init(entries: [String: BeeminderDueByEntry]) {
        self.entries = entries
    }
    
    public static var supportsSecureCoding: Bool { true }
    
    public func encode(with coder: NSCoder) {
        coder.encode(entries, forKey: Key.entries.rawValue)
    }
    
    public required convenience init?(coder: NSCoder) {
        let entries = coder.decodeObject(forKey: Key.entries.rawValue) as? [String: BeeminderDueByEntry] ?? [:]
        
        self.init(entries: entries)
    }
    
    convenience init(dueByJson: JSON?) {
        var entries: [String : BeeminderDueByEntry] {
            dueByJson?.dictionary?.compactMapValues(BeeminderDueByEntry.init)
            ?? dueByJson?.dictionary?.mapValues(BeeminderDueByEntry.init)
            ?? [:]
        }
        self.init(entries: entries)
    }
}

public class BeeminderDueByEntry: NSObject, NSSecureCoding, Codable {
    public let total: Double
    public let delta: Double
    public let formatted_total_for_beedroid: String
    public let formatted_delta_for_beedroid: String
    
    public init(json: JSON) {
        self.delta = json["delta"].doubleValue
        self.total = json["total"].doubleValue
        
        self.formatted_delta_for_beedroid = json["formatted_delta_for_beedroid"].stringValue
        self.formatted_total_for_beedroid = json["formatted_total_for_beedroid"].stringValue
    }
    
    init(total: Double, delta: Double, formatted_total_for_beedroid: String, formatted_delta_for_beedroid: String) {
        self.total = total
        self.delta = delta
        self.formatted_total_for_beedroid = formatted_total_for_beedroid
        self.formatted_delta_for_beedroid = formatted_delta_for_beedroid
    }
    
    public static var supportsSecureCoding: Bool { true }

    private enum Key: String {
        case total
        case delta
        case formattedTotalForBeedroid
        case formattedDeltaForBeedroid
    }
    
    public func encode(with coder: NSCoder) {
        coder.encode(total, forKey: Key.total.rawValue)
        coder.encode(delta, forKey: Key.delta.rawValue)
        coder.encode(formatted_total_for_beedroid, forKey: Key.formattedTotalForBeedroid.rawValue)
        coder.encode(formatted_delta_for_beedroid, forKey: Key.formattedDeltaForBeedroid.rawValue)
    }
    
    public required convenience init?(coder: NSCoder) {
        let total = coder.decodeDouble(forKey: Key.total.rawValue)
        let delta = coder.decodeDouble(forKey: Key.delta.rawValue)
        
        guard
            let formatted_total_for_beedroid = coder.decodeObject(of: NSString.self, forKey: Key.formattedTotalForBeedroid.rawValue) as? String,
            let formatted_delta_for_beedroid = coder.decodeObject(of: NSString.self, forKey: Key.formattedDeltaForBeedroid.rawValue) as? String
        else { return nil }
        
        self.init(total: total,
                  delta: delta,
                  formatted_total_for_beedroid: formatted_total_for_beedroid,
                  formatted_delta_for_beedroid: formatted_delta_for_beedroid)
    }
}
