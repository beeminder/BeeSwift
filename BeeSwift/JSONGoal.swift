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
import UserNotifications

typealias DataPoint = (daystamp: String, value: Double, comment: String)

class JSONGoal {
    var autodata: String = ""
    var delta_text: String = ""
    var graph_url: String?
    var healthKitMetric: String?
    var id: String = ""
    var lane: NSNumber?
    var losedate: NSNumber = 0
    var pledge: NSNumber = 0
    var rate: NSNumber?
    var runits: String = ""
    var yaxis: String = ""
    var slug: String = ""
    var thumb_url: String?
    var title: String = ""
    var won: NSNumber = 0
    var yaw: NSNumber = 0
    var dir: NSNumber = 0
    var safebump: NSNumber?
    var safebuf: NSNumber?
    var curval: NSNumber?
    var limsum: String?
    var safesum: String?
    var deadline: NSNumber = 0
    var leadtime: NSNumber?
    var alertstart: NSNumber?
    var lasttouch: NSNumber?
    var use_defaults: NSNumber?
    var queued: Bool?
    var todayta: Bool = false
    var hhmmformat: Bool = false
    var recent_data: Array<Any>?
    
    init(json: JSON) {
        self.id = json["id"].string!
        self.title = json["title"].string!
        self.slug = json["slug"].string!
        self.deadline = json["deadline"].number!
        self.leadtime = json["leadtime"].number!
        self.alertstart = json["alertstart"].number!
        if let lasttouchString = json["lasttouch"].string {
            let lastTouchDate: Date? = {
                let df = ISO8601DateFormatter()
                df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                return df.date(from: lasttouchString)
            }()
            
            if let date = lastTouchDate {
                self.lasttouch = NSNumber(value: date.timeIntervalSince1970)
            }
        }
        self.queued = json["queued"].bool!
        
        self.losedate = json["losedate"].number!
        self.runits = json["runits"].string!
        self.yaxis = json["yaxis"].string!
        if json["rate"].number != nil { self.rate = json["rate"].number! }
        if json["delta_text"].string != nil { self.delta_text = json["delta_text"].string! }
        self.won = json["won"].number!
        if json["lane"].number != nil { self.lane = json["lane"].number! }
        self.yaw = json["yaw"].number!
        self.dir = json["dir"].number!
        if json["limsum"].string != nil { self.limsum = json["limsum"].string! }
        if json["safesum"].string != nil { self.safesum = json["safesum"].string! }
        if json["safebuf"].number != nil { self.safebuf = json["safebuf"].number! }
        self.use_defaults = json["use_defaults"].bool! as NSNumber
        if let safebump = json["safebump"].number {
            self.safebump = safebump
        }
        if let curval = json["curval"].number {
            self.curval = curval
        }
        self.pledge = json["pledge"].number!
        let ad : String? = json["autodata"].string
        if ad != nil { self.autodata = ad! } else { self.autodata = "" }
        
        if json["graph_url"].string != nil { self.graph_url = json["graph_url"].string! }
        if json["thumb_url"].string != nil { self.thumb_url = json["thumb_url"].string! }
        
        self.healthKitMetric = json["healthkitmetric"].string
        self.todayta = json["todayta"].bool!
        self.hhmmformat = json["hhmmformat"].bool!
        
        var datapoints : Array<JSON> = json["recent_data"].arrayValue
        datapoints.reverse()
        self.recent_data = Array(datapoints)
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
    
    var countdownColor :UIColor {
        guard let buf = self.safebuf?.intValue else { return UIColor.beeminder.gray }
        if buf < 1 {
            return UIColor.red
        }
        else if buf < 2 {
            return UIColor.orange
        }
        else if buf < 3 {
            return UIColor.blue
        }
        return UIColor.beeminder.green
    }
    
    var relativeLane : NSNumber {
        return self.lane != nil ? NSNumber(value: self.lane!.int32Value * self.yaw.int32Value as Int32) : 0
    }
    
    var countdownHelperText :String {
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
    
    var humanizedRunits :String {
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
    
    func capitalSafesum() -> String {
        guard let safe = self.safesum else { return "" }
        return safe.prefix(1).uppercased() + safe.dropFirst(1)
    }
    
    var humanizedAutodata: String? {
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
    
    var attributedDeltaText :NSAttributedString {
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
    
    var deltaColors: [UIColor] {
        // yaw (number): Good side of the road (+1/-1 = above/below)
    
        return self.yaw == 1 ? deltaColorsWhenAboveIsGoodSide : deltaColorsWhenBelowIsGoodSide
    }
    
    var deltaColorsWhenBelowIsGoodSide: [UIColor] {
        return [UIColor.beeminder.green, UIColor.blue, UIColor.orange]
    }
    
    var deltaColorsWhenAboveIsGoodSide: [UIColor] {
        return deltaColorsWhenBelowIsGoodSide.reversed()
    }

    
    func hideDataEntry() -> Bool {
        return self.autodata.count > 0 || self.won.boolValue
    }
    
    func minuteStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "YYYYMMddHHmm"
        return formatter.string(from: Date())
    }
    
    func fetchRecentDatapoints(success: @escaping ((_ datapoints : [JSON]) -> ()), errorCompletion: (() -> ())?) {
        let params = ["sort" : "daystamp", "count" : 7] as [String : Any]
        RequestManager.get(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!)/goals/\(self.slug)/datapoints.json", parameters: params, success: { (response) in
            let responseJSON = JSON(response!)
            success(responseJSON.array!)
        }) { (error, errorMessage) in
            errorCompletion?()
        }
    }
    
    func datapointsMatchingDaystamp(datapoints : [JSON], daystamp : String) -> [JSON] {
        datapoints.filter { (datapoint) -> Bool in
            if let datapointStamp = datapoint["daystamp"].string {
                return datapointStamp == daystamp
            } else {
                return false
            }
        }
    }
    
    func updateDatapoint(datapoint : JSON, datapointValue : Double, success: (() -> ())?, errorCompletion: (() -> ())?) {
        let val = datapoint["value"].double
        if datapointValue == val {
            success?()
            return
        }
        let daystamp = datapoint["daystamp"].string!
        let requestId = "\(daystamp)-\(self.minuteStamp())"
        let params = [
            "access_token": CurrentUserManager.sharedManager.accessToken!,
            "value": "\(datapointValue)",
            "comment": "Auto-updated via Apple Health",
            "requestid": requestId
        ]
        let datapointID = datapoint["id"].string
        RequestManager.put(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!)/goals/\(self.slug)/datapoints/\(datapointID!).json", parameters: params, success: { (responseObject) in
            success?()
        }, errorHandler: { (error, errorMessage) in
            errorCompletion?()
        })
    }
    
    func deleteDatapoint(datapoint : JSON) {
        let datapointID = datapoint["id"].string
        RequestManager.delete(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!)/goals/\(self.slug)/datapoints/\(datapointID!)", parameters: nil, success: { (response) in
            //
        }) { (error, errorMessage) in
            //
        }
    }
    
    func postDatapoint(params : [String : String], success : ((Any?) -> Void)?, failure : ((Error?, String?) -> Void)?) {
        RequestManager.post(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!)/goals/\(self.slug)/datapoints.json", parameters: params, success: success, errorHandler: failure)
    }

    func updateToMatchDataPoints(healthKitDataPoints : [DataPoint]) async throws {
        let datapoints = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[JSON], Error>) in
            self.fetchRecentDatapoints(success: { datapoints in
                continuation.resume(returning: datapoints)
            }, errorCompletion: {
                continuation.resume(throwing: HealthKitError("Could not fetch recent datapoints"))
            })
        }

        for newDataPoint in healthKitDataPoints {
            try await self.updateToMatchDataPoint(newDataPoint: newDataPoint, recentDatapoints: datapoints)
        }
    }

    private func updateToMatchDataPoint(newDataPoint : DataPoint, recentDatapoints: [JSON]) async throws {
        let (daystamp, datapointValue, comment) = newDataPoint

        var matchingDatapoints = datapointsMatchingDaystamp(datapoints: recentDatapoints, daystamp: daystamp)
        if matchingDatapoints.count == 0 {
            let requestId = "\(daystamp)-\(minuteStamp())"
            let params = ["access_token": CurrentUserManager.sharedManager.accessToken!, "urtext": "\(daystamp.suffix(2)) \(datapointValue) \"\(comment)\"", "requestid": requestId]

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

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                updateDatapoint(datapoint: firstDatapoint, datapointValue: datapointValue, success: {
                    continuation.resume()
                }, errorCompletion: {
                    continuation.resume(throwing: HealthKitError("Error updating data point"))
                })
            }
        }
    }
}

extension JSONGoal {
    var cacheBustingThumbUrl: String {
        let thumbUrlStr = self.thumb_url!
        return cacheBuster(thumbUrlStr)
    }
    
    var cacheBustingGraphUrl: String {
        let graphUrlStr = self.graph_url!
        return cacheBuster(graphUrlStr)
    }
}

private extension JSONGoal {
    func cacheBuster(_ originUrlStr: String) -> String {
        guard let lastTouch = self.lasttouch else {
            return originUrlStr
        }
        
        let queryCharacter = originUrlStr.range(of: "&") == nil ? "?" : "&"
        
        let cacheBustingUrlStr = "\(originUrlStr)\(queryCharacter)proctime=\(lastTouch)"
        
        return cacheBustingUrlStr
    }
}

extension JSONGoal {
    var isDataProvidedAutomatically: Bool {
        return !self.autodata.isEmpty
    }
}
