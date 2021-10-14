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
            self.hkQueryForLast(days: 1) {
                completionHandler()
            } errorCompletion: {
                //
            }
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
    
    private func hkDatapointValueForWeightSamples(samples : [HKSample], units: HKUnit?) -> Double {
        var datapointValue : Double = 0
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
            datapointValue = weight!!
        }
        return datapointValue
    }
    
    func hkDatapointValueForSamples(samples : [HKSample], units: HKUnit?) -> Double {
        var datapointValue : Double = 0
        if self.healthKitMetric == "weight" {
            return self.hkDatapointValueForWeightSamples(samples: samples, units: units)
        }
        
        samples.forEach { (sample) in
            datapointValue += self.hkDatapointValueForSample(sample: sample, units: units)
        }
        return datapointValue
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
        if ((self.hkQuantityTypeIdentifier() == nil)) { return }
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
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + .seconds(5), execute: { [weak self] in
                self?.updateBeeminderWithStatsCollection(collection: statsCollection, success: nil, errorCompletion: nil)
            })
        }
        
        query.statisticsUpdateHandler = {
            [weak self] query, statistics, collection, error in
            
            if HKHealthStore.isHealthDataAvailable() {
                guard let statsCollection = collection else {
                    // Perform proper error handling here
                    return
                }
                
                self?.updateBeeminderWithStatsCollection(collection: statsCollection, success: nil, errorCompletion: nil)
            }
        }
        healthStore.execute(query)
    }
    
    func updateBeeminderWithStatsCollection(collection : HKStatisticsCollection, success: (() -> ())?, errorCompletion: (() -> ())?) {
        guard let healthStore = HealthStoreManager.sharedManager.healthStore else { return }
        
        let endDate = Date()
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -5, to: endDate) else {
            return
        }
        
        collection.enumerateStatistics(from: startDate, to: endDate) { [weak self] statistics, stop in
            guard let self = self else { return }
            
            healthStore.preferredUnits(for: [statistics.quantityType], completion: { [weak self] (units, error) in
                guard let self = self else { return }
                guard let unit = units.first?.value else { return }
                guard let quantityTypeIdentifier = self.hkQuantityTypeIdentifier() else { return }
                
                guard let quantityType = HKObjectType.quantityType(forIdentifier: quantityTypeIdentifier) else {
                    fatalError("*** Unable to create a quantity type ***")
                }

                let value: Double? = {
                    switch quantityType.aggregationStyle {
                    case .cumulative:
                        return statistics.sumQuantity()?.doubleValue(for: unit)
                    case .discrete:
                        return statistics.minimumQuantity()?.doubleValue(for: unit)
                    default:
                        return nil
                    }
                }()
                
                guard let datapointValue = value else { return }
                
                let startDate = statistics.startDate
                let endDate = statistics.endDate
                
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyyMMdd"
                let datapointDate = self.deadline.intValue >= 0 ? startDate : endDate
                let daystamp = formatter.string(from: datapointDate)
                
                self.updateBeeminderWithValue(datapointValue: datapointValue, daystamp: daystamp, success: success, errorCompletion: errorCompletion)
            })
        }
    }
    
    private func fetchRecentDatapoints(success: @escaping ((_ datapoints : [JSON]) -> ()), errorCompletion: (() -> ())?) {
        let params = ["sort" : "daystamp", "count" : 7] as [String : Any]
        RequestManager.get(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!)/goals/\(self.slug)/datapoints.json", parameters: params, success: { (response) in
            let responseJSON = JSON(response!)
            success(responseJSON.array!)
        }) { (error, errorMessage) in
            errorCompletion?()
        }
    }
    
    private func datapointsMatchingDaystamp(datapoints : [JSON], daystamp : String) -> [JSON] {
        datapoints.filter { (datapoint) -> Bool in
            if let datapointStamp = datapoint["daystamp"].string {
                return datapointStamp == daystamp
            } else {
                return false
            }
        }
    }
    
    private func updateDatapoint(datapoint : JSON, datapointValue : Double, success: (() -> ())?, errorCompletion: (() -> ())?) {
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
    
    private func deleteDatapoint(datapoint : JSON) {
        let datapointID = datapoint["id"].string
        RequestManager.delete(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!)/goals/\(self.slug)/datapoints/\(datapointID!)", parameters: nil, success: { (response) in
            //
        }) { (error, errorMessage) in
            //
        }
    }
    
    private func updateBeeminderWithValue(datapointValue : Double, daystamp : String, success: (() -> ())?, errorCompletion: (() -> ())?) {
        if datapointValue == 0  {
            success?()
            return
        }
        fetchRecentDatapoints { datapoints in
            var matchingDatapoints = self.datapointsMatchingDaystamp(datapoints: datapoints, daystamp: daystamp)
            if matchingDatapoints.count == 0 {
                let requestId = "\(daystamp)-\(self.minuteStamp())"
                let params = ["access_token": CurrentUserManager.sharedManager.accessToken!, "urtext": "\(daystamp.suffix(2)) \(datapointValue) \"Auto-entered via Apple Health\"", "requestid": requestId]
                self.postDatapoint(params: params, success: { (responseObject) in
                    success?()
                }, failure: { (error, errorMessage) in
                    errorCompletion?()
                })
            } else if matchingDatapoints.count >= 1 {
                let firstDatapoint = matchingDatapoints.remove(at: 0)
                matchingDatapoints.forEach { datapoint in
                    self.deleteDatapoint(datapoint: datapoint)
                }
                self.updateDatapoint(datapoint: firstDatapoint, datapointValue: datapointValue) {
                    success?()
                } errorCompletion: {
                    errorCompletion?()
                }
            }
        } errorCompletion: {
            errorCompletion?()
        }
    }
    
    private func predicateForDayOffset(dayOffset : Int) -> NSPredicate? {
        let bounds = dateBoundsForDayOffset(dayOffset: dayOffset)
        return HKQuery.predicateForSamples(withStart: bounds[0], end: bounds[1], options: .strictEndDate)
    }
    
    private func dateBoundsForDayOffset(dayOffset : Int) -> [Date] {
        let calendar = Calendar.current
        
        let components = calendar.dateComponents(in: TimeZone.current, from: Date())
        let localMidnightThisMorning = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: calendar.date(from: components)!)
        let localMidnightTonight = calendar.date(byAdding: .day, value: 1, to: localMidnightThisMorning!)
        
        let endOfToday = calendar.date(byAdding: .second, value: self.deadline.intValue, to: localMidnightTonight!)
        let startOfToday = calendar.date(byAdding: .second, value: self.deadline.intValue, to: localMidnightThisMorning!)
        
        guard let startDate = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday!) else { return [] }
        guard let endDate = calendar.date(byAdding: .day, value: dayOffset, to: endOfToday!) else { return [] }
        
        return [startDate, endDate]
    }
    
    private func runStatsQuery(dayOffset : Int, success: (() -> ())?, errorCompletion: (() -> ())?) {
        guard let healthStore = HealthStoreManager.sharedManager.healthStore else { return }
        guard let sampleType = self.hkSampleType() else { return }
        let predicate = self.predicateForDayOffset(dayOffset: dayOffset)
        let daystamp = self.dayStampFromDayOffset(dayOffset: dayOffset)
        
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
                
                let aggStyle : HKQuantityAggregationStyle
                if #available(iOS 13.0, *) { aggStyle = .discreteArithmetic } else { aggStyle = .discrete }
                
                if quantityType.aggregationStyle == .cumulative {
                    let quantity = statistics!.sumQuantity()
                    datapointValue = quantity?.doubleValue(for: unit)
                } else if quantityType.aggregationStyle == aggStyle {
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
    }
    
    private func runCategoryTypeQuery(dayOffset : Int, success: (() -> ())?, errorCompletion: (() -> ())?) {
        guard let healthStore = HealthStoreManager.sharedManager.healthStore else { return }
        guard let sampleType = self.hkSampleType() else { return }
        let predicate = predicateForDayOffset(dayOffset: dayOffset)
        let daystamp = self.dayStampFromDayOffset(dayOffset: dayOffset)
        
        let query = HKSampleQuery.init(sampleType: sampleType, predicate: predicate, limit: 0, sortDescriptors: nil, resultsHandler: { (query, samples, error) in
            if error != nil || samples == nil { return }
            
            let datapointValue = self.hkDatapointValueForSamples(samples: samples!, units: nil)
            
            if datapointValue == 0 { return }
            
            self.updateBeeminderWithValue(datapointValue: datapointValue, daystamp: daystamp, success: success, errorCompletion: errorCompletion)
        })
        healthStore.execute(query)
    }
    
    private func dayStampFromDayOffset(dayOffset : Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let bounds = dateBoundsForDayOffset(dayOffset: dayOffset)
        let datapointDate = self.deadline.intValue >= 0 ? bounds[0] : bounds[1]
        return formatter.string(from: datapointDate)
    }
    
    private func runCallbacksIfQueriesAreComplete(queryResults : [Int : HKQueryResult], success: (() -> ())?, errorCompletion: (() -> ())?) {
        if Set(queryResults.values).contains(.incomplete) { return }
        if Set(queryResults.values).contains(.failure) {
            errorCompletion?()
            return
        }
        success?()
    }
    
    private enum HKQueryResult {
        case incomplete
        case success
        case failure
    }
    
    func hkQueryForLast(days : Int, success: (() -> ())?, errorCompletion: (() -> ())?) {        
        var queryWithOffsetResult : [Int : HKQueryResult] = [:]
        
        ((-1*days + 1)...0).forEach({ (dayOffset) in
            queryWithOffsetResult[dayOffset] = .incomplete
            if self.hkQuantityTypeIdentifier() != nil {
                self.runStatsQuery(dayOffset: dayOffset) {
                    queryWithOffsetResult[dayOffset] = .success
                    self.runCallbacksIfQueriesAreComplete(queryResults: queryWithOffsetResult, success: success, errorCompletion: errorCompletion)
                } errorCompletion: {
                    queryWithOffsetResult[dayOffset] = .failure
                    self.runCallbacksIfQueriesAreComplete(queryResults: queryWithOffsetResult, success: success, errorCompletion: errorCompletion)
                }
            } else {
                self.runCategoryTypeQuery(dayOffset: dayOffset) {
                    queryWithOffsetResult[dayOffset] = .success
                    self.runCallbacksIfQueriesAreComplete(queryResults: queryWithOffsetResult, success: success, errorCompletion: errorCompletion)
                } errorCompletion: {
                    queryWithOffsetResult[dayOffset] = .failure
                    self.runCallbacksIfQueriesAreComplete(queryResults: queryWithOffsetResult, success: success, errorCompletion: errorCompletion)
                }
            }
        })
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
    
    func postDatapoint(params : [String : String], success : ((Any?) -> Void)?, failure : ((Error?, String?) -> Void)?) {
        RequestManager.post(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!)/goals/\(self.slug)/datapoints.json", parameters: params, success: success, errorHandler: failure)
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
