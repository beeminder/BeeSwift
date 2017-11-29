//
//  GoalExtension.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/19/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation
import SwiftyJSON
import MagicalRecord
import HealthKit

extension Goal {
    
    class func crupdateWithJSON(_ json :JSON) {
        
        if let id = json["id"].string, let goal :Goal = Goal.mr_findFirst(byAttribute: "id", withValue:id) {
            Goal.updateGoal(goal, withJSON: json)
        }
        else if let goal :Goal = Goal.mr_createEntity() {
            Goal.updateGoal(goal, withJSON: json)
        }
    }
    
    class func updateGoal(_ goal :Goal, withJSON json :JSON) {
        goal.slug = json["slug"].string!
        goal.id = json["id"].string!
        goal.title = json["title"].string!
        goal.burner = json["burner"].string!
        goal.panic = json["panic"].number!
        goal.deadline = json["deadline"].number!
        goal.leadtime = json["leadtime"].number!
        goal.alertstart = json["alertstart"].number!
        goal.losedate = json["losedate"].number!
        goal.runits = json["runits"].string!
        if json["rate"].number != nil { goal.rate = json["rate"].number! }
        if json["delta_text"].string != nil { goal.delta_text = json["delta_text"].string! }
        goal.won = json["won"].number!
        if json["lane"].number != nil { goal.lane = json["lane"].number! }
        goal.yaw = json["yaw"].number!
        if json["limsum"].string != nil { goal.limsum = json["limsum"].string! }
        goal.use_defaults = json["use_defaults"].bool! as NSNumber
        if let safebump = json["safebump"].number {
            goal.safebump = safebump
        }
        if let hkMetric = json["healthkitmetric"].string {
            if hkMetric.characters.count > 0 {
                goal.healthKitMetric = hkMetric
                goal.setupHealthKit()
            }
        }
        if let curval = json["curval"].number {
            goal.curval = curval
        }
        goal.pledge = json["pledge"].number!
        let autodata : String? = json["autodata"].string
        if autodata != nil { goal.autodata = autodata! } else { goal.autodata = "" }

        if let newDatapoints = json["datapoints"].array {
            for datapointJSON in newDatapoints {
                let datapoint = Datapoint.crupdateWithJSON(datapointJSON)
                datapoint.goal = goal
            }
        }
        // these are last because other classes use KVO on them...hack.
        if json["graph_url"].string != nil { goal.graph_url = json["graph_url"].string! }
        if json["thumb_url"].string != nil { goal.thumb_url = json["thumb_url"].string! }
    }
    
    var rateString :String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = NumberFormatter.Style.decimal
        formatter.maximumFractionDigits = 2
        return "\(formatter.string(from: self.rate)!)/\(self.humanizedRunits)"
    }
    
    var cacheBustingThumbUrl :String {
        if self.thumb_url.range(of: "&") == nil {
            return "\(self.thumb_url)?t=\(Date().timeIntervalSince1970)"
        }
        return "\(self.thumb_url)&t=\(Date().timeIntervalSince1970)"
    }
    
    var cacheBustingGraphUrl :String {
        if self.graph_url.range(of: "&") == nil {
            return "\(self.graph_url)?t=\(Date().timeIntervalSince1970)"
        }
        return "\(self.graph_url)&t=\(Date().timeIntervalSince1970)"
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
        let losedateDate = Date(timeIntervalSince1970: self.losedate.doubleValue)
        if losedateDate.timeIntervalSinceNow < 0 {
            if self.won.boolValue {
                return UIColor.beeGreenColor()
            }
            else {
                return UIColor.red
            }
        }
        else if self.relativeLane.intValue <= -2 {
            return UIColor.red
        }
        else if self.relativeLane == -1 {
            return UIColor.orange
        }
        else if self.relativeLane == 1 {
            return UIColor.blue
        }
        return UIColor.beeGreenColor()
    }
    
    var relativeLane : NSNumber {
        return NSNumber(value: self.lane.int32Value * self.yaw.int32Value as Int32)
    }
    
    var attributedDeltaText :NSAttributedString {
        if self.delta_text.characters.count == 0 { return NSAttributedString.init(string: "") }
        let modelName = UIDevice.current.modelName
        if modelName.contains("iPhone 5") || modelName.contains("iPad Mini") || modelName.contains("iPad 4") {
            return NSAttributedString(string: self.delta_text)
        }
        if self.delta_text.components(separatedBy: "✔").count == 4 {
            if (self.safebump.doubleValue - self.curval.doubleValue > 0) {
                let attString :NSMutableAttributedString = NSMutableAttributedString(string: String(format: "+ %.2f", self.safebump.doubleValue - self.curval.doubleValue))
                attString.addAttribute(NSAttributedStringKey.foregroundColor, value: UIColor.beeGreenColor(), range: NSRange(location: 0, length: attString.string.characters.count))
                return attString
            }
            return NSMutableAttributedString(string: "")
        }
        var spaceIndices :Array<Int> = [0]
        
        for i in 0...self.delta_text.characters.count - 1 {
            if Array(self.delta_text.characters)[i] == " " {
                spaceIndices.append(i)
            }
        }
        
        spaceIndices.append(self.delta_text.characters.count)

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
        
        attString.mutableString.replaceOccurrences(of: "✔", with: "", options: NSString.CompareOptions.literal, range: NSRange(location: 0, length: attString.string.characters.count))

        return attString
    }
    
    var deltaColors :Array<UIColor> {
        if self.yaw == 1 {
            return [UIColor.orange, UIColor.blue, UIColor.beeGreenColor()]
        }
        return [UIColor.beeGreenColor(), UIColor.blue, UIColor.orange]
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
    
    func orderedDatapoints() -> [Datapoint] {
        let points : [Datapoint] = self.datapoints.allObjects as! [Datapoint]
        return points.sorted(by: { (d1, d2) -> Bool in
            if d1.timestamp == d2.timestamp {
                return d1.updated_at.intValue < d2.updated_at.intValue
            }
            return d1.timestamp.intValue < d2.timestamp.intValue
        })
    }
    
    func lastFiveDatapoints() -> [Datapoint] {
        var allDatapoints = self.orderedDatapoints()
        if allDatapoints.count < 6 {
            return allDatapoints
        }
        
        return Array(allDatapoints[(allDatapoints.count - 5)...(allDatapoints.count - 1)])
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
        if self.autodata.characters.count > 0 { return self.autodata.capitalized }
        return nil
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
    
    func hideDataEntry() -> Bool {
        return self.autodata.characters.count > 0 || self.won.boolValue
    }
    
    func hkRequestId() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "YYYYMMddHHmm"
        return formatter.string(from: Date())
    }
    
    func setupHealthKitForSessions() {
        guard let categoryTypeIdentifier = self.hkCategoryTypeIdentifier() else { return }
        
        guard let healthStore = HealthStoreManager.sharedManager.healthStore else { return }
        
        guard let categoryType = HKObjectType.categoryType(forIdentifier: categoryTypeIdentifier) else { return }
        
        HealthStoreManager.sharedManager.healthStore?.requestAuthorization(toShare: nil, read: [categoryType], completion: { (success, error) in
            healthStore.enableBackgroundDelivery(for: categoryType, frequency: HKUpdateFrequency.immediate, withCompletion: { (success, error) in
                
                let endDate = Date()
                let calendar = Calendar.current
                
                guard let observerStartDate = calendar.date(byAdding: .day, value: -7, to: endDate) else {
                    return
                }
                
                let observerPredicate = HKQuery.predicateForSamples(withStart: observerStartDate, end: endDate, options: .strictEndDate)
                
                let observerQuery = HKObserverQuery.init(sampleType: categoryType, predicate: observerPredicate, updateHandler: { (query, completionHandler, error) in
                    (-7...0).forEach({ (offset) in
                        guard let startDate = calendar.date(byAdding: .day, value: offset, to: endDate) else {
                            return
                        }
                        
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyyMMdd"
                        let datapointDate = self.deadline.intValue >= 0 ? startDate : endDate
                        let daystamp = formatter.string(from: datapointDate)
                        
                        formatter.dateFormat = "d"
                        
                        let datapoints = Datapoint.mr_findAll(with: NSPredicate(format: "daystamp == %@ and goal.id = %@", daystamp, self.id))
                        
                        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: calendar.date(byAdding: .day, value: 1, to: startDate), options: .strictEndDate)
                        
                        let query = HKSampleQuery.init(sampleType: categoryType, predicate: predicate, limit: 0, sortDescriptors: nil, resultsHandler: { (query, samples, error) in
                            if error != nil || samples == nil { return }
                            var totalDuration : Double = 0
                            for sample in samples! {
                                if let s = sample as? HKCategorySample {
                                    if categoryTypeIdentifier != .sleepAnalysis ||
                                        (self.healthKitMetric == "timeAsleep" && s.value == HKCategoryValueSleepAnalysis.asleep.rawValue) ||
                                        (self.healthKitMetric == "timeInBed" && s.value == HKCategoryValueSleepAnalysis.inBed.rawValue) {
                                        let duration = s.endDate.timeIntervalSince(s.startDate)
                                        totalDuration += duration
                                    }
                                }
                            }
                            
                            var datapointValue : Double
                            
                            if #available(iOS 10.0, *) {
                                datapointValue = self.hkCategoryTypeIdentifier() == .mindfulSession ? totalDuration/60 : totalDuration / 3600
                            } else {
                                datapointValue = totalDuration / 3600
                            }
                            
                            if totalDuration == 0 { return }
                            
                            if datapoints == nil || datapoints?.count == 0 {
                                let params = ["access_token": CurrentUserManager.sharedManager.accessToken!, "urtext": "\(formatter.string(from: datapointDate)) \(datapointValue) \"Automatically entered via iOS Health app\"", "requestid": self.hkRequestId()]
                                self.postDatapoint(params: params, success: { (dataTask, responseObject) in
                                    let datapoint = Datapoint.crupdateWithJSON(JSON(responseObject!))
                                    datapoint.goal = self
                                    NSManagedObjectContext.mr_default().mr_saveToPersistentStore(completion: nil)
                                }, failure: { (dataTask, error) in
                                    print(error)
                                })
                            } else if datapoints?.count == 1 {
                                let datapoint = datapoints?.first as! Datapoint
                                formatter.dateFormat = "hh:mm"
                                let params = [
                                    "access_token": CurrentUserManager.sharedManager.accessToken!,
                                    "timestamp": "\(datapointDate)",
                                    "value": "\(datapointValue)",
                                    "comment": "Automatically updated via iOS Health app"
                                ]
                                BSHTTPSessionManager.sharedManager.put("api/v1/users/me/goals/\(self.slug)/datapoints/\(datapoint.id).json", parameters: params, success: { (dataTask, responseObject) in
                                    //foo
                                }, failure: { (dataTask, error) in
                                    ///bar
                                })
                            }
                        })
                        healthStore.execute(query)
                        completionHandler()
                    })
                })
                
                healthStore.execute(observerQuery)
            })
        })
    }
    
    func setupHealthKit() {
        
        guard let quantityTypeIdentifier = self.hkQuantityTypeIdentifier() else {
            self.setupHealthKitForSessions()
            return
        }
        guard let quantityType = HKObjectType.quantityType(forIdentifier: quantityTypeIdentifier) else {
            fatalError("*** Unable to create a quantity type ***")
        }

        guard let healthStore = HealthStoreManager.sharedManager.healthStore else { return }

        let metricType = HKObjectType.quantityType(forIdentifier: quantityTypeIdentifier)!
        healthStore.requestAuthorization(toShare: nil, read: [metricType], completion: { (success, error) in
            healthStore.enableBackgroundDelivery(for: quantityType, frequency: HKUpdateFrequency.immediate, withCompletion: { (success, error) in
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
                        fatalError("*** An error occurred while calculating the statistics: \(error?.localizedDescription) ***")
                    }
                    
                    self.updateBeeminder(collection: statsCollection)
                }
                
                query.statisticsUpdateHandler = {
                    query, statistics, collection, error in
                    
                    guard let statsCollection = collection else {
                        // Perform proper error handling here
                        fatalError("*** An error occurred while calculating the statistics: \(error?.localizedDescription) ***")
                    }
                    
                    self.updateBeeminder(collection: statsCollection)
                }
                
                healthStore.execute(query)
            })
        })
    }
    
    func postDatapoint(params : [String : String], success : ((URLSessionDataTask, Any?) -> Void)?, failure : ((URLSessionDataTask?, Error) -> Void)?) {
        BSHTTPSessionManager.sharedManager.post("api/v1/users/me/goals/\(self.slug)/datapoints.json", parameters: params, success: success, failure: failure)
    }
    
    func updateBeeminder(collection : HKStatisticsCollection) {
        guard let healthStore = HealthStoreManager.sharedManager.healthStore else { return }
        
        let endDate = Date()
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) else {
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

                let formatter = DateFormatter()
                formatter.dateFormat = "yyyyMMdd"
                let datapointDate = self.deadline.intValue >= 0 ? statistics.startDate : statistics.endDate
                let daystamp = formatter.string(from: datapointDate)
                
                formatter.dateFormat = "d"

                let datapoints = Datapoint.mr_findAll(with: NSPredicate(format: "daystamp == %@ and goal.id = %@", daystamp, self.id))
                
                if datapoints == nil || datapoints?.count == 0 {
                    let params = ["access_token": CurrentUserManager.sharedManager.accessToken!, "urtext": "\(formatter.string(from: datapointDate)) \(datapointValue!) \"Automatically entered via iOS Health app\"", "requestid": self.hkRequestId()]
                    BSHTTPSessionManager.sharedManager.post("api/v1/users/me/goals/\(self.slug)/datapoints.json", parameters: params, success: { (dataTask, responseObject) -> Void in
                        let datapoint = Datapoint.crupdateWithJSON(JSON(responseObject!))
                        datapoint.goal = self
                        NSManagedObjectContext.mr_default().mr_saveToPersistentStore(completion: nil)
                    }) { (dataTask, error) -> Void in
                        print(error)
                    }
                } else if datapoints?.count == 1 {
                    let datapoint = datapoints?.first as! Datapoint
                    formatter.dateFormat = "hh:mm"
                    let params = [
                        "access_token": CurrentUserManager.sharedManager.accessToken!,
                        "timestamp": "\(datapointDate)",
                        "value": "\(datapointValue!)",
                        "comment": "Automatically updated via iOS Health app"
                    ]
                    BSHTTPSessionManager.sharedManager.put("api/v1/users/me/goals/\(self.slug)/datapoints/\(datapoint.id).json", parameters: params, success: { (dataTask, responseObject) in
                        //foo
                    }, failure: { (dataTask, error) in
                        ///bar
                    })
                } else {
                    // delete extra datapoints locally
                    var first = true
                    datapoints?.forEach({ (datapoint) in
                        let d = datapoint as! Datapoint
                        if (!first) {
                            d.mr_deleteEntity()
                            NSManagedObjectContext.mr_default().mr_saveToPersistentStore(completion: nil)
                        } else {
                            first = false
                        }
                    })
                }
            })
        }
    }
}
