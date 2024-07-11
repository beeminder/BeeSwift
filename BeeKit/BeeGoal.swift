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

public class BeeGoal {
    private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "Goal")

    public var autodata: String = ""
    public var graph_url: String?
    public var healthKitMetric: String?
    public var id: String = ""
    public var pledge: NSNumber = 0
    public var yaxis: String = ""
    public var slug: String = ""
    public var thumb_url: String?
    public var title: String = ""
    public var won: NSNumber = 0
    public var safebuf: NSNumber = 0
    public var limsum: String?
    public var safesum: String?
    public var initday: NSNumber?
    public var deadline: NSNumber = 0
    public var leadtime: NSNumber?
    public var alertstart: NSNumber?
    public var lasttouch: NSNumber?
    public var use_defaults: NSNumber?
    public var queued: Bool?
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
        self.initday = json["initday"].number!
        self.deadline = json["deadline"].number!
        self.leadtime = json["leadtime"].number!
        self.alertstart = json["alertstart"].number!

        self.lasttouch = json["lasttouch"].string.flatMap { lasttouchString in
            let lastTouchDate: Date? = {
                let df = ISO8601DateFormatter()
                df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                return df.date(from: lasttouchString)
            }()
            
            if let date = lastTouchDate {
                return NSNumber(value: date.timeIntervalSince1970)
            }
            return nil
        }

        self.queued = json["queued"].bool!
        self.yaxis = json["yaxis"].string!
        self.won = json["won"].number!
        self.limsum = json["limsum"].string
        self.safesum = json["safesum"].string
        self.safebuf = json["safebuf"].number!
        self.use_defaults = json["use_defaults"].bool! as NSNumber
        self.pledge = json["pledge"].number!
        self.autodata = json["autodata"].string ?? ""
        
        self.graph_url = json["graph_url"].string
        self.thumb_url = json["thumb_url"].string
        
        self.healthKitMetric = json["healthkitmetric"].string
        self.todayta = json["todayta"].bool!
        self.hhmmformat = json["hhmmformat"].bool!
        self.urgencykey = json["urgencykey"].string!

        self.recent_data = (try? ExistingDataPoint.fromJSONArray(array: json["recent_data"].arrayValue).reversed()) ?? []
    }

    public var countdownColor :UIColor {
        let buf = self.safebuf.intValue
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
    
    public var humanizedAutodata: String? {
        if self.autodata == "ifttt" { return "IFTTT" }
        if self.autodata == "api" { return "API" }
        if self.autodata == "apple" {
            let metric = HealthKitConfig.shared.metrics.first(where: { (metric) -> Bool in
                metric.databaseString == self.healthKitMetric
            })
            return self.healthKitMetric == nil ? "Apple" : metric?.humanText
        }
        if self.autodata.count > 0 { return self.autodata.capitalized }
        return nil
    }

    public func hideDataEntry() -> Bool {
        return self.isDataProvidedAutomatically || self.won.boolValue
    }

    public var isDataProvidedAutomatically: Bool {
        return !self.autodata.isEmpty
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

    /// The daystamp corresponding to the day of the goal's creation, thus the first day we should add data points for.
    var initDaystamp: Daystamp {
        let initDate = Date(timeIntervalSince1970: self.initday!.doubleValue)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"

        // initDate is constructed such that if we resolve it to a datetime in US Eastern Time, the date part
        // of that is guaranteed to be the user's local date on the day the goal was created.
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        let dateString = formatter.string(from: initDate)

        return try! Daystamp(fromString: dateString)
    }

}

public extension BeeGoal {
    var cacheBustingThumbUrl: String {
        let thumbUrlStr = self.thumb_url!
        return cacheBuster(thumbUrlStr)
    }
    
    var cacheBustingGraphUrl: String {
        let graphUrlStr = self.graph_url!
        return cacheBuster(graphUrlStr)
    }
}

private extension BeeGoal {
    func cacheBuster(_ originUrlStr: String) -> String {
        guard let lastTouch = self.lasttouch else {
            return originUrlStr
        }
        
        let queryCharacter = originUrlStr.range(of: "&") == nil ? "?" : "&"
        
        let cacheBustingUrlStr = "\(originUrlStr)\(queryCharacter)proctime=\(lastTouch)"
        
        return cacheBustingUrlStr
    }
}
