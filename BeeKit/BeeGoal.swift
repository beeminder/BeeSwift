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

    public var autodata: String? = ""
    public var graphUrl: String = ""
    public var healthKitMetric: String?
    public var id: String = ""
    public var pledge: Int = 0
    public var yAxis: String = ""
    public var slug: String = ""
    public var thumbUrl: String = ""
    public var title: String = ""
    public var won: Bool = false
    public var safeBuf: Int = 0
    public var limsum: String?
    public var safeSum: String = ""
    public var initDay: Int = 0
    public var deadline: Int = 0
    public var leadTime: Int = 0
    public var alertStart: Int = 0
    public var lastTouch: Int = 0
    public var useDefaults: Bool = false
    public var queued: Bool = false
    public var todayta: Bool = false
    public var hhmmFormat: Bool = false
    public var urgencyKey: String = ""
    public var recentData: Set<AnyHashable> = Set()

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
        self.yAxis = json["yaxis"].string!
        self.won =  json["won"].boolValue
        self.limsum = json["limsum"].string
        self.safeSum = json["safesum"].stringValue
        self.safeBuf = json["safebuf"].intValue
        self.useDefaults = json["use_defaults"].boolValue
        self.pledge = json["pledge"].intValue
        self.autodata = json["autodata"].string ?? ""
        
        self.graphUrl = json["graph_url"].stringValue
        self.thumbUrl = json["thumb_url"].stringValue

        self.healthKitMetric = json["healthkitmetric"].string
        self.todayta = json["todayta"].bool!
        self.hhmmFormat = json["hhmmformat"].bool!
        self.urgencyKey = json["urgencykey"].string!

        if let dataPoints = try? ExistingDataPoint.fromJSONArray(array: json["recent_data"].arrayValue) {
            self.recentData = Set(dataPoints)
        } else {
            self.recentData = Set<ExistingDataPoint>()
        }
    }



}
