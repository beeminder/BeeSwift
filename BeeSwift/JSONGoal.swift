//
//  JSONself.swift
//  BeeSwift
//
//  Created by Andy Brett on 9/13/19.
//  Copyright © 2019 APB. All rights reserved.
//

import Foundation
import SwiftyJSON
import HealthKit
import UserNotifications

class JSONGoal {
    var autodata: String = ""
    var burner: String = ""
    var delta_text: String = ""
    var graph_url: String?
    var healthKitMetric: String?
    var id: String = ""
    var lane: NSNumber?
    var losedate: NSNumber = 0
    var panic: NSNumber = 0
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
    var baremin: String?
    var limsum: String?
    var safesum: String?
    var deadline: NSNumber = 0
    var leadtime: NSNumber?
    var alertstart: NSNumber?
    var lasttouch: NSNumber?
    var use_defaults: NSNumber?
    var queued: Bool?
    var recent_data: Array<Any>?
    
    init(json: JSON) {
        self.id = json["id"].string!
        self.title = json["title"].string!
        self.burner = json["burner"].string!
        self.slug = json["slug"].string!
        self.panic = json["panic"].number!
        self.deadline = json["deadline"].number!
        self.leadtime = json["leadtime"].number!
        self.alertstart = json["alertstart"].number!
        if let lasttouchString = json["lasttouch"].string {
            let lastTouchDate: Date? = {
                if #available(iOS 11.0, *) {
                    let df = ISO8601DateFormatter()
                    df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    return df.date(from: lasttouchString)
                } else {
                    let df = DateFormatter()
                    df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                    return df.date(from: lasttouchString)
                }
            }()
            
            if let date = lastTouchDate {
                self.lasttouch = NSNumber(value: date.timeIntervalSince1970)
            }
        }
        self.queued = json["queued"].bool!
        
        self.losedate = json["losedate"].number!
        self.runits = json["runits"].string!
        self.yaxis = json["yaxis"].string!
        self.baremin = json["baremin"].string!
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
    
    var cacheBustingThumbUrl :String {
        if self.thumb_url!.range(of: "&") == nil {
            return "\(self.thumb_url!)?t=\(Date().timeIntervalSince1970)"
        }
        return "\(self.thumb_url!)&t=\(Date().timeIntervalSince1970)"
    }
    
    var cacheBustingGraphUrl :String {
        if self.graph_url!.range(of: "&") == nil {
            return "\(self.graph_url!)?t=\(Date().timeIntervalSince1970)"
        }
        return "\(self.graph_url!)&t=\(Date().timeIntervalSince1970)"
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
        guard let buf = self.safebuf?.intValue else { return UIColor.beeGrayColor() }
        if buf < 1 {
            return UIColor.red
        }
        else if buf < 2 {
            return UIColor.orange
        }
        else if buf < 3 {
            return UIColor.blue
        }
        return UIColor.beeGreenColor()
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
    
    func humanizedAutodata() -> String? {
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
                attString.addAttribute(NSAttributedStringKey.foregroundColor, value: UIColor.beeGreenColor(), range: NSRange(location: 0, length: attString.string.count))
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
            attString.addAttribute(NSAttributedStringKey.foregroundColor, value: color as Any, range: NSRange(location: spaceIndices[i], length: spaceIndices[i + 1] - spaceIndices[i]))
        }
        
        attString.mutableString.replaceOccurrences(of: "✔", with: "", options: NSString.CompareOptions.literal, range: NSRange(location: 0, length: attString.string.count))
        
        return attString
    }
    
    var deltaColors :Array<UIColor> {
        if self.yaw == 1 {
            return [UIColor.orange, UIColor.blue, UIColor.beeGreenColor()]
        }
        return [UIColor.beeGreenColor(), UIColor.blue, UIColor.orange]
    }
    
    func hkQuantityTypeIdentifier() -> HKQuantityTypeIdentifier? {
        return HealthKitConfig.shared.metrics.first { (metric) -> Bool in
            metric.databaseString == self.healthKitMetric
            }?.hkIdentifier
    }
    
    func hkCategoryTypeIdentifier() -> HKCategoryTypeIdentifier? {
        return HealthKitConfig.shared.metrics.first { (metric) -> Bool in
            metric.databaseString == self.healthKitMetric
            }?.hkCategoryTypeIdentifier
    }
    
    func hkSampleType() -> HKSampleType? {
        if self.hkQuantityTypeIdentifier() != nil {
            return HKObjectType.quantityType(forIdentifier: self.hkQuantityTypeIdentifier()!)
        }
        if self.hkCategoryTypeIdentifier() != nil {
            return HKObjectType.categoryType(forIdentifier: self.hkCategoryTypeIdentifier()!)
        }
        return nil
    }
    
    
    
    func hkObserverQuery() -> HKObserverQuery? {
        guard let sampleType = self.hkSampleType() else { return nil }
        return HKObserverQuery(sampleType: sampleType, predicate: nil, updateHandler: { (query, completionHandler, error) in
            self.hkQueryForLast(days: 1, success: nil, errorCompletion: nil)
            self.setUnlockNotification()
            completionHandler()
        })
    }
    
    func hkPermissionType() -> HKObjectType? {
        if self.hkQuantityTypeIdentifier() != nil {
            return HKObjectType.quantityType(forIdentifier: self.hkQuantityTypeIdentifier()!)
        } else if self.hkCategoryTypeIdentifier() != nil {
            return HKObjectType.categoryType(forIdentifier: self.hkCategoryTypeIdentifier()!)
        }
        return nil
    }
    
    func hideDataEntry() -> Bool {
        return self.autodata.count > 0 || self.won.boolValue
    }
    
    func minuteStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "YYYYMMddHHmm"
        return formatter.string(from: Date())
    }
    
    func hkDatapointValueForSample(sample: HKSample, units: HKUnit?) -> Double {
        if let s = sample as? HKQuantitySample, let u = units {
            return s.quantity.doubleValue(for: u)
        } else if let s = sample as? HKCategorySample {
            if (self.healthKitMetric == "timeAsleep" && s.value != HKCategoryValueSleepAnalysis.asleep.rawValue) ||
                (self.healthKitMetric == "timeInBed" && s.value != HKCategoryValueSleepAnalysis.inBed.rawValue) {
                return 0
            } else if self.hkCategoryTypeIdentifier() == .appleStandHour {
                return Double(s.value)
            } else if self.hkCategoryTypeIdentifier() == .sleepAnalysis {
                return s.endDate.timeIntervalSince(s.startDate)/3600.0
            }
            if self.hkCategoryTypeIdentifier() == .mindfulSession {
                return s.endDate.timeIntervalSince(s.startDate)/60.0
            }
        }
        return 0
    }
    
    func hkDatapointValueForSamples(samples : [HKSample], units: HKUnit?) -> Double {
        var datapointValue : Double = 0
        if self.healthKitMetric == "weight" {
            let weights = samples.map { (sample) -> Double? in
                let s = sample as? HKQuantitySample
                if s != nil { return (s?.quantity.doubleValue(for: units!))! }
                else {
                    return nil
                }
            }
            let weight = weights.min { (w1, w2) -> Bool in
                if w1 == nil { return true }
                if w2 == nil { return false }
                return w2! > w1!
            }
            if weight != nil {
                datapointValue = weight as! Double
            }
            return datapointValue
        }
        
        var uniqueSamples : [HKSample] = []
        samples.forEach { (sample) in
            var dupe = false
            uniqueSamples.forEach({ (seenSample) in
                if seenSample.startDate == sample.startDate &&
                    seenSample.endDate == sample.endDate &&
                    seenSample.device  == sample.device {
                    dupe = true
                }
            })
            if !dupe { uniqueSamples.append(sample) }
        }
        
        uniqueSamples.forEach { (sample) in
            datapointValue += self.hkDatapointValueForSample(sample: sample, units: units)
        }
        return datapointValue
    }
    
    func setupActivitySummaryQuery() {
        guard let healthStore = HealthStoreManager.sharedManager.healthStore else { return }
        guard let categoryType = self.hkCategoryTypeIdentifier() else { return }
        if categoryType != .appleStandHour { return }
        
        let calendar = Calendar.current
        
        let components = calendar.dateComponents(in: TimeZone.current, from: Date())
        let localMidnightThisMorning = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: calendar.date(from: components)!)
        let localMidnightTonight = calendar.date(byAdding: .day, value: 1, to: localMidnightThisMorning!)
        
        guard let startDate = calendar.date(byAdding: .second, value: self.deadline.intValue, to: localMidnightThisMorning!) else { return }
        guard let endDate = calendar.date(byAdding: .second, value: self.deadline.intValue, to: localMidnightTonight!) else { return }
        
        let startDateComponents = calendar.dateComponents([.day,.month,.year], from: startDate)
        let endDateComponents = calendar.dateComponents([.day,.month,.year], from: endDate)
        
        let startDC = DateComponents(calendar: Calendar.current, timeZone: TimeZone.current, era: nil, year: startDateComponents.year, month: startDateComponents.month, day: startDateComponents.day, hour: nil, minute: nil, second: nil, nanosecond: nil, weekday: nil, weekdayOrdinal: nil, quarter: nil, weekOfMonth: nil, weekOfYear: nil, yearForWeekOfYear: nil)
        
        let endDC = DateComponents(calendar: Calendar.current, timeZone: TimeZone.current, era: nil, year: endDateComponents.year, month: endDateComponents.month, day: endDateComponents.day, hour: nil, minute: nil, second: nil, nanosecond: nil, weekday: nil, weekdayOrdinal: nil, quarter: nil, weekOfMonth: nil, weekOfYear: nil, yearForWeekOfYear: nil)
        
        let summariesWithinRange = HKQuery.predicate(forActivitySummariesBetweenStart: startDC, end: endDC)
        
        let query = HKActivitySummaryQuery(predicate: nil) { (query, summaries, error) -> Void in
            guard let activitySummaries = summaries else {
                guard let queryError = error else {
                    fatalError("*** Did not return a valid error object. ***")
                }
                print(queryError)
                return
            }
            if self.hasRecentlyUpdatedHealthData() { return }
            self.updateBeeminderWithActivitySummaries(summaries: activitySummaries, success: nil, errorCompletion: nil)
            
        }
        query.updateHandler = self.activitySummaryUpdateHandler
        healthStore.execute(query)
    }
    
    func activitySummaryUpdateHandler(query: HKActivitySummaryQuery, summaries: [HKActivitySummary]?, error: Error?) {
        guard let activitySummaries = summaries else {
            guard let queryError = error else {
                fatalError("*** Did not return a valid error object. ***")
            }
            print(queryError)
            return
        }
        self.updateBeeminderWithActivitySummaries(summaries: activitySummaries, success: nil, errorCompletion: nil)
    }
    
    func updateBeeminderWithActivitySummaries(summaries: [HKActivitySummary]?, success: (() -> ())?, errorCompletion: (() -> ())?) {
        summaries?.forEach({ (summary) in
            let calendar = Calendar.current
            let dateComponents = summary.dateComponents(for: Calendar.current)
            guard let summaryDate = calendar.date(from: dateComponents) else { return }
            // ignore anything older than 7 days
            if summaryDate.compare(Date(timeIntervalSinceNow: -604800)) == ComparisonResult.orderedAscending {
                return
            }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd"
            let daystamp = formatter.string(from: summaryDate)
            let standHours = summary.appleStandHours
            self.updateBeeminderWithValue(datapointValue: standHours.doubleValue(for: HKUnit.count()), daystamp: daystamp, success: {
                success?()
            }, errorCompletion: {
                errorCompletion?()
            })
        })
    }
    
    func setupHKStatisticsCollectionQuery() {
        guard let healthStore = HealthStoreManager.sharedManager.healthStore else { return }
        guard let quantityTypeIdentifier = self.hkQuantityTypeIdentifier() else { return }
        guard let quantityType = HKObjectType.quantityType(forIdentifier: self.hkQuantityTypeIdentifier()!) else { return }
        
        let calendar = Calendar.current
        var interval = DateComponents()
        interval.day = 1
        
        var anchorComponents = calendar.dateComponents([.day, .month, .year, .weekday], from: Date())
        anchorComponents.hour = 0
        anchorComponents.minute = 0
        anchorComponents.second = 0
        
        guard let midnight = calendar.date(from: anchorComponents) else {
            fatalError("*** unable to create a valid date from the given components ***")
        }
        let anchorDate = calendar.date(byAdding: .second, value: self.deadline.intValue, to: midnight)!
        
        var options : HKStatisticsOptions
        if quantityType.aggregationStyle == .cumulative {
            options = .cumulativeSum
        } else {
            options = .discreteMin
        }
        
        let query = HKStatisticsCollectionQuery(quantityType: quantityType,
                                                quantitySamplePredicate: nil,
                                                options: options,
                                                anchorDate: anchorDate,
                                                intervalComponents: interval)
        query.initialResultsHandler = {
            query, collection, error in
            
            guard let statsCollection = collection else {
                // Perform proper error handling here
                return
            }
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + .seconds(5), execute: {
                self.updateBeeminderWithStatsCollection(collection: statsCollection, success: nil, errorCompletion: nil)
                self.setUnlockNotification()
            })
        }
        
        query.statisticsUpdateHandler = {
            query, statistics, collection, error in
            
            if HKHealthStore.isHealthDataAvailable() {
                guard let statsCollection = collection else {
                    // Perform proper error handling here
                    return
                }
                
                self.updateBeeminderWithStatsCollection(collection: statsCollection, success: nil, errorCompletion: nil)
                self.setUnlockNotification()
            }
        }
        healthStore.execute(query)
    }
    
    func setUnlockNotification() {
        if UserDefaults.standard.bool(forKey: Constants.healthSyncRemindersPreferenceKey) == false { return }
        
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        let content = UNMutableNotificationContent()
        content.title = "Health Sync"
        content.body = "Unlock your phone to sync your Health data with Beeminder."
        let date = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        
        var trigger : UNNotificationTrigger
        if hour < 9 {
            // data synced before 9 am. Schedule for nine hours from now.
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 32400.0, repeats: false)
        }
        else if hour >= 9 && hour < 17 {
            // data synced during the day, before 5 pm. schedule for 8 pm.
            var components = DateComponents()
            components.hour = 20
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        } else {
            // data synced after 5 pm. Schedule for 9 am next morning.
            var components = DateComponents()
            components.hour = 9
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        }
        
        let notification = UNNotificationRequest.init(identifier: "foo", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(notification, withCompletionHandler: nil)
    }
    
    func updateBeeminderWithStatsCollection(collection : HKStatisticsCollection, success: (() -> ())?, errorCompletion: (() -> ())?) {
        guard let healthStore = HealthStoreManager.sharedManager.healthStore else { return }
        
        let endDate = Date()
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -5, to: endDate) else {
            return
        }
        
        collection.enumerateStatistics(from: startDate, to: endDate) { [unowned self] statistics, stop in
            healthStore.preferredUnits(for: [statistics.quantityType], completion: { (units, error) in
                guard let unit = units.first?.value else { return }
                var datapointValue : Double?
                
                guard let quantityTypeIdentifier = self.hkQuantityTypeIdentifier() else {
                    return
                }
                guard let quantityType = HKObjectType.quantityType(forIdentifier: quantityTypeIdentifier) else {
                    fatalError("*** Unable to create a quantity type ***")
                }
                
                
                if quantityType.aggregationStyle == .cumulative {
                    let quantity = statistics.sumQuantity()
                    datapointValue = quantity?.doubleValue(for: unit)
                } else if quantityType.aggregationStyle == .discrete {
                    let quantity = statistics.minimumQuantity()
                    datapointValue = quantity?.doubleValue(for: unit)
                }
                
                guard datapointValue != nil else { return }
                
                let startDate = statistics.startDate
                let endDate = statistics.endDate
                
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyyMMdd"
                let datapointDate = self.deadline.intValue >= 0 ? startDate : endDate
                let daystamp = formatter.string(from: datapointDate)
                
                self.updateBeeminderWithValue(datapointValue: datapointValue!, daystamp: daystamp, success: success, errorCompletion: errorCompletion)
            })
        }
    }
    
    func updateBeeminderWithValue(datapointValue : Double, daystamp : String, success: (() -> ())?, errorCompletion: (() -> ())?) {
        
        if datapointValue == 0  { return }
        
        
        let params = ["sort" : "daystamp", "count" : 7] as [String : Any]
        
        RequestManager.get(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!)/goals/\(self.slug)/datapoints.json", parameters: params, success: { (response) in
            let responseJSON = JSON(response)
            var datapoints = responseJSON.array!
            datapoints = datapoints.filter { (datapoint) -> Bool in
                if let datapointStamp = datapoint["daystamp"].string {
                    return datapointStamp == daystamp
                } else {
                    return false
                }
            }
            
            if datapoints.count == 0 {
                let requestId = "\(daystamp)-\(self.minuteStamp())"
                let params = ["access_token": CurrentUserManager.sharedManager.accessToken!, "urtext": "\(daystamp.suffix(2)) \(datapointValue) \"Automatically entered via iOS Health app\"", "requestid": requestId]
                self.postDatapoint(params: params, success: { (responseObject) in
                    success?()
                }, failure: { (error) in
                    print(error)
                    errorCompletion?()
                })
            } else if datapoints.count >= 1 {
                var first = true
                datapoints.forEach({ (datapoint) in
                    guard let d = datapoint as? JSON else { return }
                    if first {
                        let requestId = "\(daystamp)-\(self.minuteStamp())"
                        let params = [
                            "access_token": CurrentUserManager.sharedManager.accessToken!,
                            "value": "\(datapointValue)",
                            "comment": "Automatically updated via iOS Health app",
                            "requestid": requestId
                        ]
                        let val = d["value"].double as? Double
                        if datapointValue == val { success?() }
                        else {
                            let datapointID = d["id"].string
                            RequestManager.put(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!)/goals/\(self.slug)/datapoints/\(datapointID!).json", parameters: params, success: { (responseObject) in
                                success?()
                            }, errorHandler: { (error) in
                                errorCompletion?()
                            })
                        }
                    } else {
                        let datapointID = d["id"].string
                        RequestManager.delete(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!)/goals/\(self.slug)/datapoints/\(datapointID!)", parameters: nil, success: { (response) in
                            //
                        }) { (error) in
                            //
                        }
                    }
                    first = false
                })
            }
        }) { (error) in
            //
        }
        

    }
    
    func hasRecentlyUpdatedHealthData() -> Bool {
        var updateDictionary = UserDefaults.standard.dictionary(forKey: Constants.healthKitUpdateDictionaryKey)
        if updateDictionary == nil {
            updateDictionary = [:]
        }
        
        if updateDictionary![self.slug] != nil {
            let lastUpdate = updateDictionary![self.slug] as! Date
            if lastUpdate.timeIntervalSinceNow > -60.0 {
                return true
            }
        }
        updateDictionary![self.slug] = Date()
        
        UserDefaults.standard.set(updateDictionary, forKey: Constants.healthKitUpdateDictionaryKey)
        UserDefaults.standard.synchronize()
        
        return false
    }
    
    func hkQueryForLast(days : Int, success: (() -> ())?, errorCompletion: (() -> ())?) {
        guard let healthStore = HealthStoreManager.sharedManager.healthStore else { return }
        guard let sampleType = self.hkSampleType() else { return }
        if self.hasRecentlyUpdatedHealthData() {
            success?()
            return
        }
        
        ((-1*days + 1)...0).forEach({ (offset) in
            let calendar = Calendar.current
            
            let components = calendar.dateComponents(in: TimeZone.current, from: Date())
            let localMidnightThisMorning = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: calendar.date(from: components)!)
            let localMidnightTonight = calendar.date(byAdding: .day, value: 1, to: localMidnightThisMorning!)
            
            let endOfToday = calendar.date(byAdding: .second, value: self.deadline.intValue, to: localMidnightTonight!)
            let startOfToday = calendar.date(byAdding: .second, value: self.deadline.intValue, to: localMidnightThisMorning!)
            
            guard let startDate = calendar.date(byAdding: .day, value: offset, to: startOfToday!) else { return }
            guard let endDate = calendar.date(byAdding: .day, value: offset, to: endOfToday!) else { return }
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd"
            let datapointDate = self.deadline.intValue >= 0 ? startDate : endDate
            let daystamp = formatter.string(from: datapointDate)
            
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
            
            if self.hkQuantityTypeIdentifier() != nil {
                var options : HKStatisticsOptions
                guard let quantityType = HKObjectType.quantityType(forIdentifier: self.hkQuantityTypeIdentifier()!) else { return }
                if quantityType.aggregationStyle == .cumulative {
                    options = .cumulativeSum
                } else {
                    options = .discreteMin
                }
                let statsQuery = HKStatisticsQuery.init(quantityType: sampleType as! HKQuantityType, quantitySamplePredicate: predicate, options: options, completionHandler: { (query, statistics, error) in
                    if error != nil || statistics == nil { return }
                    
                    guard let quantityTypeIdentifier = self.hkQuantityTypeIdentifier() else {
                        return
                    }
                    guard let quantityType = HKObjectType.quantityType(forIdentifier: quantityTypeIdentifier) else {
                        fatalError("*** Unable to create a quantity type ***")
                    }
                    
                    healthStore.preferredUnits(for: [quantityType], completion: { (units, error) in
                        var datapointValue : Double?
                        guard let unit = units.first?.value else { return }
                        
                        if quantityType.aggregationStyle == .cumulative {
                            let quantity = statistics!.sumQuantity()
                            datapointValue = quantity?.doubleValue(for: unit)
                        } else if quantityType.aggregationStyle == .discrete {
                            let quantity = statistics!.minimumQuantity()
                            datapointValue = quantity?.doubleValue(for: unit)
                        }
                        
                        if datapointValue == nil || datapointValue == 0  { return }
                        
                        self.updateBeeminderWithValue(datapointValue: datapointValue!, daystamp: daystamp, success: {
                            success?()
                        }, errorCompletion: {
                            errorCompletion?()
                        })
                    })
                })
                
                healthStore.execute(statsQuery)
                return
            } else {
                let query = HKSampleQuery.init(sampleType: sampleType, predicate: predicate, limit: 0, sortDescriptors: nil, resultsHandler: { (query, samples, error) in
                    if error != nil || samples == nil { return }
                    
                    let datapointValue = self.hkDatapointValueForSamples(samples: samples!, units: nil)
                    
                    if datapointValue == 0 { return }
                    
                    self.updateBeeminderWithValue(datapointValue: datapointValue, daystamp: daystamp, success: success, errorCompletion: errorCompletion)
                })
                healthStore.execute(query)
            }
        })
        success?()
    }
    
    func setupHealthKit() {
        guard let healthStore = HealthStoreManager.sharedManager.healthStore else { return }
        guard let sampleType = self.hkSampleType() else { return }
        
        healthStore.requestAuthorization(toShare: nil, read: [sampleType], completion: { (success, error) in
            if error != nil {
                //handle error
                return
            }
            healthStore.enableBackgroundDelivery(for: sampleType, frequency: HKUpdateFrequency.immediate, withCompletion: { (success, error) in
                
                if error != nil {
                    //handle error
                    return
                }
                if self.hkQuantityTypeIdentifier() != nil {
                    self.setupHKStatisticsCollectionQuery()
                }
                else if let query = self.hkObserverQuery() {
                    healthStore.execute(query)
                } else {
                    // big trouble
                }
            })
        })
    }
    
    func postDatapoint(params : [String : String], success : ((Any?) -> Void)?, failure : ((Error?) -> Void)?) {
        RequestManager.post(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!)/goals/\(self.slug)/datapoints.json", parameters: params, success: success, errorHandler: failure)
    }
}
