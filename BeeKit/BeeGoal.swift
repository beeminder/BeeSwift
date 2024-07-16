//
//  JSONgoal.swift
//  BeeSwift
//
//  Created by Andy Brett on 9/13/19.
//  Copyright © 2019 APB. All rights reserved.
//

import Foundation
import SwiftyJSON
import HealthKit
import OSLog
import UserNotifications
import UIKit

public class BeeGoal : GoalProtocol {
    private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "Goal")

    public var autodata: String? = ""
    public var graphUrl: String = ""
    public var healthKitMetric: String?
    public var id: String = ""
    public var pledge: NSNumber = 0
    public var yaxis: String = ""
    public var slug: String = ""
    public var thumbUrl: String = ""
    public var title: String = ""
    public var won: NSNumber = 0
    public var safeBuf: Int = 0
    public var limsum: String?
    public var safesum: String?
    public var initDay: Int = 0
    public var deadline: Int = 0
    public var leadTime: Int = 0
    public var alertStart: Int = 0
    public var lastTouch: Int = 0
    public var useDefaults: Bool = false
    public var queued: Bool = false
    public var todayta: Bool = false
    public var hhmmformat: Bool = false
    public var urgencykey: String = ""
    public var recent_data: [ExistingDataPoint]?
    
    public init(json: JSON) {
        self.id = json["id"].string!
        self.updateToMatch(json: json)
    }

    // Should only be called from GoalManager
    internal func updateToMatch(json: JSON) {
        assert(self.id == json["id"].string!, "Cannot change goal id. Tried to change from \(id) to \(json["id"].string ?? "")")

        self.title = json["title"].string!
        self.slug = json["slug"].string!
        self.initDay = json["initday"].intValue
        self.deadline = json["deadline"].intValue
        self.leadTime = json["leadtime"].intValue
        self.alertStart = json["alertstart"].intValue

        self.lastTouch = json["lasttouch"].string.flatMap { lasttouchString in
            let lastTouchDate: Date? = {
                let df = ISO8601DateFormatter()
                df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                return df.date(from: lasttouchString)
            }()
            
            if let date = lastTouchDate {
                return Int(date.timeIntervalSince1970)
            }
            return nil
        } ?? 0

        self.queued = json["queued"].bool!
        self.yaxis = json["yaxis"].string!
        self.won = json["won"].number!
        self.limsum = json["limsum"].string
        self.safesum = json["safesum"].string
        self.safeBuf = json["safebuf"].intValue
        self.useDefaults = json["use_defaults"].boolValue
        self.pledge = json["pledge"].number!
        self.autodata = json["autodata"].string ?? ""
        
        self.graphUrl = json["graph_url"].stringValue
        self.thumbUrl = json["thumb_url"].stringValue

        self.healthKitMetric = json["healthkitmetric"].string
        self.todayta = json["todayta"].bool!
        self.hhmmformat = json["hhmmformat"].bool!
        self.urgencykey = json["urgencykey"].string!

        self.recent_data = (try? ExistingDataPoint.fromJSONArray(array: json["recent_data"].arrayValue).reversed()) ?? []
    }

    public var countdownColor :UIColor {
        let buf = self.safeBuf
        if buf < 1 {
            return UIColor.beeminder.red
        }
        else if buf < 2 {
            return UIColor.beeminder.orange
        }
        else if buf < 3 {
            return UIColor.beeminder.blue
        }
        return UIColor.beeminder.green
    }
    
    public func capitalSafesum() -> String {
        guard let safe = self.safesum else { return "" }
        return safe.prefix(1).uppercased() + safe.dropFirst(1)
    }
    
    public func hideDataEntry() -> Bool {
        return self.isDataProvidedAutomatically || self.won.boolValue
    }

    public var isLinkedToHealthKit: Bool {
        return self.autodata == "apple"
    }

    /// A hint for the value the user is likely to enter, based on past data points
    public var suggestedNextValue: NSNumber? {
        guard let recentData = self.recent_data else { return nil }
        for dataPoint in recentData.reversed() {
            let comment = dataPoint.comment
            // Ignore data points with comments suggesting they aren't a real value
            if comment.contains("#DERAIL") || comment.contains("#SELFDESTRUCT") || comment.contains("#THISWILLSELFDESTRUCT") || comment.contains("#RESTART") || comment.contains("#TARE") {
                continue
            }
            return dataPoint.value
        }
        return nil
    }


}
