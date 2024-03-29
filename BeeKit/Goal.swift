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

public class Goal {
    private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "Goal")

    // Ignore automatic datapoint updates where the difference is a smaller fraction than this. This
    // prevents effectively no-op updates due to float rounding
    private let datapointValueEpsilon = 0.00000001

    public var autodata: String = ""
    public var delta_text: String = ""
    public var graph_url: String?
    public var healthKitMetric: String?
    public var id: String = ""
    public var lane: NSNumber?
    public var losedate: NSNumber = 0
    public var pledge: NSNumber = 0
    public var rate: NSNumber?
    public var runits: String = ""
    public var yaxis: String = ""
    public var slug: String = ""
    public var thumb_url: String?
    public var title: String = ""
    public var won: NSNumber = 0
    public var yaw: NSNumber = 0
    public var dir: NSNumber = 0
    public var safebump: NSNumber?
    public var safebuf: NSNumber?
    public var curval: NSNumber?
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
    public var recent_data: [ExistingDataPoint]?

    // These are obtained from mathishard
    public var derived_goaldate: NSNumber = 0
    public var derived_goalval: NSNumber = 0
    public var derived_rate: NSNumber = 0
    
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
        self.losedate = json["losedate"].number!
        self.runits = json["runits"].string!
        self.yaxis = json["yaxis"].string!
        self.rate = json["rate"].number
        self.delta_text = json["delta_text"].string ?? ""
        self.won = json["won"].number!
        self.lane = json["lane"].number
        self.yaw = json["yaw"].number!
        self.dir = json["dir"].number!
        self.limsum = json["limsum"].string
        self.safesum = json["safesum"].string
        self.safebuf = json["safebuf"].number
        self.use_defaults = json["use_defaults"].bool! as NSNumber
        self.safebump = json["safebump"].number
        self.curval = json["curval"].number
        self.pledge = json["pledge"].number!
        self.autodata = json["autodata"].string ?? ""
        
        self.graph_url = json["graph_url"].string
        self.thumb_url = json["thumb_url"].string
        
        self.healthKitMetric = json["healthkitmetric"].string
        self.todayta = json["todayta"].bool!
        self.hhmmformat = json["hhmmformat"].bool!

        self.recent_data = (try? ExistingDataPoint.fromJSONArray(array: json["recent_data"].arrayValue).reversed()) ?? []

        // In rare cases goals can be corrupted and not have a mathishard value. We don't particularly care about
        // behavior in this rare case as long as the app does not crash, so default to a nonsense value
        self.derived_goaldate = json["mathishard"][0].number ?? 0
        self.derived_goalval = json["mathishard"][1].number ?? 0
        self.derived_rate = json["mathishard"][2].number ?? 0
    }

    var rateString :String {
        guard let r = self.rate else { return "" }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = NumberFormatter.Style.decimal
        formatter.maximumFractionDigits = 2
        return "\(formatter.string(from: r)!)/\(self.humanizedRunits)"
    }
    
    var briefLosedate :String {
        var losedateDate = Date(timeIntervalSince1970: self.losedate.doubleValue)
        if losedateDate.timeIntervalSinceNow < 0 {
            return self.won.boolValue ? "Success!" : "Lost!"
        }
        else if losedateDate.timeIntervalSinceNow < 24*60*60 {
            // add 1 second since a 3 am goal technically derails at 2:59:59
            losedateDate = losedateDate.addingTimeInterval(1)
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US")
            dateFormatter.dateFormat = "h a!"
            return dateFormatter.string(from: losedateDate)
        }
        else if losedateDate.timeIntervalSinceNow < 7*24*60*60 {
            let dateFormatter = DateFormatter()
            var calendar = Calendar.current
            calendar.locale = Locale(identifier: "en_US")
            dateFormatter.locale = Locale(identifier: "en_US")
            let hour = (calendar as NSCalendar).component(.hour, from: losedateDate)
            if hour < 6 {
                losedateDate = losedateDate.addingTimeInterval(Double(-(hour + 1)*3600))
            }
            dateFormatter.dateFormat = "EEE"
            return dateFormatter.string(from: losedateDate)
        }
        else if losedateDate.timeIntervalSinceNow > 99*24*60*60 {
            return "∞"
        }
        return "\(Int(losedateDate.timeIntervalSinceNow/(24*60*60))) days"
    }
    
    var countdownText :NSString {
        
        let losedateDate = Date(timeIntervalSince1970: self.losedate.doubleValue)
        let seconds = losedateDate.timeIntervalSinceNow
        if seconds < 0 {
            return self.won.boolValue ? "Success!" : "Lost!"
        }
        let hours = Int((seconds.truncatingRemainder(dividingBy: (3600*24)))/3600)
        let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600))/60)
        let leftoverSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))
        let days = Int(seconds/(3600*24))
        
        if (days > 0) {
            return NSString(format: "%id, %i:%02i:%02i", days, hours, minutes,leftoverSeconds)
        }
        else { // days == 0
            return NSString(format: "%i:%02i:%02i", hours, minutes,leftoverSeconds)
        }
    }
    
    public var countdownColor :UIColor {
        guard let buf = self.safebuf?.intValue else { return UIColor.beeminder.gray }
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
    
    public var relativeLane : NSNumber {
        return self.lane != nil ? NSNumber(value: self.lane!.int32Value * self.yaw.int32Value as Int32) : 0
    }
    
    public var countdownHelperText :String {
        if self.delta_text.components(separatedBy: "✔").count == 4 {
            if self.safebump != nil && self.curval != nil {
                if (self.safebump!.doubleValue - self.curval!.doubleValue <= 0) {
                    return "Ending in"
                }
            }
        }
        if self.yaw.intValue < 0 && self.dir.intValue > 0 {
            return "safe for"
        }
        return "due in"
    }
    
    public var humanizedRunits :String {
        if self.runits == "d" {
            return "day"
        }
        if self.runits == "m" {
            return "month"
        }
        if self.runits == "h" {
            return "hour"
        }
        if self.runits == "y" {
            return "year"
        }
        
        return "week"
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
    
    public var attributedDeltaText :NSAttributedString {
        if self.delta_text.count == 0 { return NSAttributedString.init(string: "") }
        let modelName = UIDevice.current.modelName
        if modelName.contains("iPhone 5") || modelName.contains("iPad Mini") || modelName.contains("iPad 4") {
            return NSAttributedString(string: self.delta_text)
        }
        if self.delta_text.components(separatedBy: "✔").count == 4 {
            if (self.safebump!.doubleValue - self.curval!.doubleValue > 0) {
                let attString :NSMutableAttributedString = NSMutableAttributedString(string: String(format: "+ %.2f", self.safebump!.doubleValue - self.curval!.doubleValue))
                attString.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.beeminder.green, range: NSRange(location: 0, length: attString.string.count))
                return attString
            }
            return NSMutableAttributedString(string: "")
        }
        var spaceIndices :Array<Int> = [0]
        
        for i in 0...self.delta_text.count - 1 {
            if self.delta_text[delta_text.index(delta_text.startIndex, offsetBy: i)] == " " {
                spaceIndices.append(i)
            }
        }
        
        spaceIndices.append(self.delta_text.count)
        
        let attString :NSMutableAttributedString = NSMutableAttributedString(string: self.delta_text)
        
        for i in 0..<spaceIndices.count {
            if i + 1 >= spaceIndices.count {
                continue
            }
            var color = self.deltaColors.first
            if i < self.deltaColors.count {
                color = self.deltaColors[i]
            }
            attString.addAttribute(NSAttributedString.Key.foregroundColor, value: color as Any, range: NSRange(location: spaceIndices[i], length: spaceIndices[i + 1] - spaceIndices[i]))
        }
        
        attString.mutableString.replaceOccurrences(of: "✔", with: "", options: NSString.CompareOptions.literal, range: NSRange(location: 0, length: attString.string.count))
        
        return attString
    }
    
    public var deltaColors: [UIColor] {
        // yaw (number): Good side of the road (+1/-1 = above/below)
    
        return self.yaw == 1 ? deltaColorsWhenAboveIsGoodSide : deltaColorsWhenBelowIsGoodSide
    }
    
    public var deltaColorsWhenBelowIsGoodSide: [UIColor] {
        return [UIColor.beeminder.green, UIColor.beeminder.blue, UIColor.beeminder.orange]
    }
    
    public var deltaColorsWhenAboveIsGoodSide: [UIColor] {
        return deltaColorsWhenBelowIsGoodSide.reversed()
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
            if comment.contains("#DERAIL") || comment.contains("#SELFDESTRUCT") || comment.contains("#RESTART") || comment.contains("#TARE") {
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

    func fetchRecentDatapoints(success: @escaping ((_ datapoints : [ExistingDataPoint]) -> ()), errorCompletion: (() -> ())?) {
        Task { @MainActor in
            let params = ["sort" : "daystamp", "count" : 7] as [String : Any]
            do {
                let response = try await ServiceLocator.requestManager.get(url: "api/v1/users/{username}/goals/\(self.slug)/datapoints.json", parameters: params)
                let responseJSON = JSON(response!)
                success(try ExistingDataPoint.fromJSONArray(array: responseJSON.arrayValue))
            } catch {
                errorCompletion?()
            }
        }
    }
    
    func datapointsMatchingDaystamp(datapoints : [ExistingDataPoint], daystamp : Daystamp) -> [ExistingDataPoint] {
        datapoints.filter { (datapoint) -> Bool in
            return daystamp == datapoint.daystamp
        }
    }
    
    func updateDatapoint(datapoint : ExistingDataPoint, datapointValue : NSNumber, success: (() -> ())?, errorCompletion: (() -> ())?) {
        Task { @MainActor in
            let val = datapoint.value
            if datapointValue == val {
                success?()
                return
            }
            let params = [
                "value": "\(datapointValue)",
                "comment": "Auto-updated via Apple Health",
            ]
            do {
                let _ = try await ServiceLocator.requestManager.put(url: "api/v1/users/{username}/goals/\(self.slug)/datapoints/\(datapoint.id).json", parameters: params)
                success?()
            } catch {
                errorCompletion?()
            }
        }
    }
    
    func deleteDatapoint(datapoint : ExistingDataPoint) {
        Task { @MainActor in
            do {
                let _ = try await ServiceLocator.requestManager.delete(url: "api/v1/users/{username}/goals/\(self.slug)/datapoints/\(datapoint.id)", parameters: nil)
            } catch {
                logger.error("Error deleting datapoint: \(error)")
            }
        }
    }
    
    func postDatapoint(params : [String : String], success : ((Any?) -> Void)?, failure : ((Error?, String?) -> Void)?) {
        Task { @MainActor in
            do {
                let response = try await ServiceLocator.requestManager.post(url: "api/v1/users/{username}/goals/\(self.slug)/datapoints.json", parameters: params)
                success?(response)
            } catch {
                failure?(error, error.localizedDescription)
            }
        }
    }

    func fetchDatapoints(sort: String, per: Int, page: Int) async throws -> [ExistingDataPoint] {
        let params = ["sort" : sort, "per" : per, "page": page] as [String : Any]
        let response = try await ServiceLocator.requestManager.get(url: "api/v1/users/{username}/goals/\(self.slug)/datapoints.json", parameters: params)
        let responseJSON = JSON(response!)
        return try ExistingDataPoint.fromJSONArray(array: responseJSON.arrayValue)
    }

    /// Retrieve all data points on or after the daystamp provided
    /// Estimates how many data points are needed to fetch the correct data points, and then performs additional requests if needed
    /// to guarantee all matching points have been fetched.
    func datapointsSince(daystamp: Daystamp) async throws -> [ExistingDataPoint] {
        // Estimate how many points we need, based on one point per day
        let daysSince = Daystamp.now(deadline: self.deadline.intValue) - daystamp

        // We want an additional fudge factor because
        // (a) We want to include the starting day itself
        // (b) we need to receive a data point before the chosen day to make sure all possible data points for the chosen day has been fetched
        // (c) We'd rather not do multiple round trips if needed, so allow for some days having multiple data points
        var pageSize = daysSince + 5

        // While we don't have a point that preceeds the provided daystamp
        var fetchedDatapoints = try await fetchDatapoints(sort: "daystamp", per: pageSize, page: 1)
        if fetchedDatapoints.isEmpty {
            return []
        }

        while fetchedDatapoints.map({ point in point.daystamp }).min()! >= daystamp {
            let additionalDatapoints = try await fetchDatapoints(sort: "daystamp", per: pageSize, page: 2)

            // If we recieve an empty page we have fetched all points
            if additionalDatapoints.isEmpty {
                break
            }

            fetchedDatapoints.append(contentsOf: additionalDatapoints)

            // Double our page size to perform exponential fetch. This way even if our initial estimate is very wrong
            // we will not perform too many requests
            pageSize *= 2
        }

        // We will have fetched at least some points which are too old. Filter them out before returning
        return fetchedDatapoints.filter { point in point.daystamp >= daystamp }
    }

    func updateToMatchDataPoints(healthKitDataPoints : [DataPoint]) async throws {
        guard let firstDaystamp = healthKitDataPoints.map({ point in point.daystamp }).min() else { return }

        let datapoints = try await datapointsSince(daystamp: try! Daystamp(fromString: firstDaystamp.description))

        for newDataPoint in healthKitDataPoints {
            try await self.updateToMatchDataPoint(newDataPoint: newDataPoint, recentDatapoints: datapoints)
        }
    }

    private func updateToMatchDataPoint(newDataPoint : DataPoint, recentDatapoints: [ExistingDataPoint]) async throws {
        var matchingDatapoints = datapointsMatchingDaystamp(datapoints: recentDatapoints, daystamp: newDataPoint.daystamp)
        if matchingDatapoints.count == 0 {
            // If there are not already data points for this day, do not add points
            // from before the creation of the goal. This avoids immediate derailment
            //on do less goals, and excessive safety buffer on do-more goals.
            if newDataPoint.daystamp < self.initDaystamp {
                return
            }

            let params = ["urtext": "\(newDataPoint.daystamp.day) \(newDataPoint.value) \"\(newDataPoint.comment)\"", "requestid": newDataPoint.requestid]

            logger.notice("Creating new datapoint for \(self.id, privacy: .public) on \(newDataPoint.daystamp, privacy: .public): \(newDataPoint.value, privacy: .private)")

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                postDatapoint(params: params, success: { (responseObject) in
                    continuation.resume()
                }, failure: { (error, errorMessage) in
                    continuation.resume(throwing: error!)
                })
            }
        } else if matchingDatapoints.count >= 1 {
            let firstDatapoint = matchingDatapoints.remove(at: 0)
            matchingDatapoints.forEach { datapoint in
                deleteDatapoint(datapoint: datapoint)
            }

            if !isApproximatelyEqual(firstDatapoint.value.doubleValue, newDataPoint.value.doubleValue) {
                logger.notice("Updating datapoint for \(self.id) on \(firstDatapoint.daystamp, privacy: .public) from \(firstDatapoint.value) to \(newDataPoint.value)")

                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    updateDatapoint(datapoint: firstDatapoint, datapointValue: newDataPoint.value, success: {
                        continuation.resume()
                    }, errorCompletion: {
                        continuation.resume(throwing: HealthKitError("Error updating data point"))
                    })
                }
            }
        }
    }

    /// Compares two datapoint values for equality, allowing a certain epsilon
    private func isApproximatelyEqual(_ first: Double, _ second: Double) -> Bool {
        // Zero is never approximately equal to another number (as a relative different makes no sense)
        if first == 0.0 && second == 0.0 {
            return true
        }
        if first == 0.0 || second == 0.0 {
            return false
        }

        let allowedDelta = ((first / 2) + (second / 2)) * datapointValueEpsilon

        return fabs(first - second) < allowedDelta
    }
}

public extension Goal {
    var cacheBustingThumbUrl: String {
        let thumbUrlStr = self.thumb_url!
        return cacheBuster(thumbUrlStr)
    }
    
    var cacheBustingGraphUrl: String {
        let graphUrlStr = self.graph_url!
        return cacheBuster(graphUrlStr)
    }
}

private extension Goal {
    func cacheBuster(_ originUrlStr: String) -> String {
        guard let lastTouch = self.lasttouch else {
            return originUrlStr
        }
        
        let queryCharacter = originUrlStr.range(of: "&") == nil ? "?" : "&"
        
        let cacheBustingUrlStr = "\(originUrlStr)\(queryCharacter)proctime=\(lastTouch)"
        
        return cacheBustingUrlStr
    }
}
