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
        if self.delta_text.characters.count == 0 { return NSAttributedString.init(string: self.delta_text) }
        if self.delta_text.components(separatedBy: "✔").count == 4 {
            if (self.safebump.doubleValue - self.curval.doubleValue > 0) {
                let attString :NSMutableAttributedString = NSMutableAttributedString(string: String(format: "+ %.2f", self.safebump.doubleValue - self.curval.doubleValue))
                attString.addAttribute(NSForegroundColorAttributeName, value: UIColor.beeGreenColor(), range: NSRange(location: 0, length: attString.string.characters.count))
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
        
        for i in 0...spaceIndices.count {
            if i + 1 >= spaceIndices.count {
                continue
            }
            attString.addAttribute(NSForegroundColorAttributeName, value: self.deltaColors[i], range: NSRange(location: spaceIndices[i], length: spaceIndices[i + 1] - spaceIndices[i]))
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
    
    func hkQuantityTypeIdentifier() -> HKQuantityTypeIdentifier? {
        return HealthKitConfig.metrics.first { (metric) -> Bool in
            metric.databaseString == self.healthKitMetric
        }?.metric
    }
    
    func setupHealthKit() {
        guard let metric = self.healthKitMetric else { return }
        guard let quantityTypeIdentifier = self.hkQuantityTypeIdentifier() else { return }
        let delegate = UIApplication.shared.delegate as! AppDelegate
        
        guard let healthStore = delegate.healthStore else { return }
        
        let calendar = Calendar.current
        var interval = DateComponents()
        interval.day = 7
        
        var anchorComponents = calendar.dateComponents([.day, .month, .year, .weekday], from: Date())
        anchorComponents.hour = 0
        anchorComponents.minute = 0
        anchorComponents.second = 0
        
        guard let midnight = calendar.date(from: anchorComponents) else {
            fatalError("*** unable to create a valid date from the given components ***")
        }
        let anchorDate = calendar.date(byAdding: .second, value: self.deadline.intValue, to: midnight)!
        
        guard let quantityType = HKObjectType.quantityType(forIdentifier: quantityTypeIdentifier) else {
            fatalError("*** Unable to create a quantity type ***")
        }
        
        let query = HKStatisticsCollectionQuery(quantityType: quantityType,
                                                quantitySamplePredicate: nil,
                                                options: .cumulativeSum,
                                                anchorDate: anchorDate,
                                                intervalComponents: interval)
        
        query.statisticsUpdateHandler = {
            query, statistics, collection, error in
            
        }
        
        query.initialResultsHandler = {
            query, results, error in
            
            guard let statsCollection = results else {
                // Perform proper error handling here
                fatalError("*** An error occurred while calculating the statistics: \(error?.localizedDescription) ***")
            }
            
            let endDate = Date()
            
            guard let startDate = calendar.date(byAdding: .month, value: -3, to: endDate) else {
                fatalError("foo")
            }
            
            // Plot the weekly step counts over the past 3 months
            statsCollection.enumerateStatistics(from: startDate, to: endDate) { [unowned self] statistics, stop in
                
                if let quantity = statistics.sumQuantity() {
                    let date = statistics.startDate
                    let value = quantity.doubleValue(for: HKUnit.count())
                    
                    // Call a custom method to plot each data point.
                }
            }
        }
        
        healthStore.execute(query)
    }
    
}
