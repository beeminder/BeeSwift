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

extension Goal {
    
    class func crupdateWithJSON(json :JSON) {
        if let goal :Goal? = Goal.MR_findFirstByAttribute("id", withValue:json["id"].string) {
            Goal.updateGoal(goal!, withJSON: json)
        }
        else if let goal :Goal = Goal.MR_createEntity() {
            Goal.updateGoal(goal, withJSON: json)
        }
    }
    
    class func updateGoal(goal :Goal, withJSON json :JSON) {
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
        goal.delta_text = json["delta_text"].string!
        goal.won = json["won"].number!
        goal.lane = json["lane"].number!
        goal.yaw = json["yaw"].number!
        goal.limsum = json["limsum"].string!
        // TODO: uncomment this
//        goal.use_defaults = json["use_defaults"].bool!
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
        goal.graph_url = json["graph_url"].string!
        goal.thumb_url = json["thumb_url"].string!
    }
    
    var rateString :String {
        let formatter = NSNumberFormatter()
        formatter.locale = NSLocale(localeIdentifier: "en_US")
        formatter.numberStyle = NSNumberFormatterStyle.DecimalStyle
        formatter.maximumFractionDigits = 2
        return "\(formatter.stringFromNumber(self.rate)!)/\(self.humanizedRunits)"
    }
    
    var cacheBustingThumbUrl :String {
        if self.thumb_url.rangeOfString("&") == nil {
            return "\(self.thumb_url)?t=\(NSDate().timeIntervalSince1970)"
        }
        return "\(self.thumb_url)&t=\(NSDate().timeIntervalSince1970)"
    }
    
    var cacheBustingGraphUrl :String {
        if self.graph_url.rangeOfString("&") == nil {
            return "\(self.graph_url)?t=\(NSDate().timeIntervalSince1970)"
        }
        return "\(self.graph_url)&t=\(NSDate().timeIntervalSince1970)"
    }
    
    var briefLosedate :String {
        var losedateDate = NSDate(timeIntervalSince1970: self.losedate.doubleValue)
        if losedateDate.timeIntervalSinceNow < 0 {
            return self.won.boolValue ? "Success!" : "Lost!"
        }
        else if losedateDate.timeIntervalSinceNow < 24*60*60 {
            // add 1 second since a 3 am goal technically derails at 2:59:59
            losedateDate = losedateDate.dateByAddingTimeInterval(1)
            let dateFormatter = NSDateFormatter()
            dateFormatter.locale = NSLocale(localeIdentifier: "en_US")
            dateFormatter.dateFormat = "h a!"
            return dateFormatter.stringFromDate(losedateDate)
        }
        else if losedateDate.timeIntervalSinceNow < 7*24*60*60 {
            let dateFormatter = NSDateFormatter()
            let calendar = NSCalendar.currentCalendar()
            calendar.locale = NSLocale(localeIdentifier: "en_US")
            dateFormatter.locale = NSLocale(localeIdentifier: "en_US")
            let hour = calendar.component(.Hour, fromDate: losedateDate)
            if hour < 6 {
                losedateDate = losedateDate.dateByAddingTimeInterval(Double(-(hour + 1)*3600))
            }
            dateFormatter.dateFormat = "EEE"
            return dateFormatter.stringFromDate(losedateDate)
        }
        else if losedateDate.timeIntervalSinceNow > 99*24*60*60 {
            return "∞"
        }
        return "\(Int(losedateDate.timeIntervalSinceNow/(24*60*60))) days"
    }
    
    var countdownText :NSString {

        let losedateDate = NSDate(timeIntervalSince1970: self.losedate.doubleValue)
        let seconds = losedateDate.timeIntervalSinceNow
        if seconds < 0 {
            return self.won.boolValue ? "Success!" : "Lost!"
        }
        let hours = Int((seconds % (3600*24))/3600)
        let minutes = Int((seconds % 3600)/60)
        let leftoverSeconds = Int(seconds % 60)
        let days = Int(seconds/(3600*24))
        
        if (days > 0) {
            return NSString(format: "%id, %i:%02i:%02i", days, hours, minutes,leftoverSeconds)
        }
        else { // days == 0
            return NSString(format: "%i:%02i:%02i", hours, minutes,leftoverSeconds)
        }
    }
    
    var countdownColor :UIColor {
        let losedateDate = NSDate(timeIntervalSince1970: self.losedate.doubleValue)
        if losedateDate.timeIntervalSinceNow < 0 {
            if self.won.boolValue {
                return UIColor.beeGreenColor()
            }
            else {
                return UIColor.redColor()
            }
        }
        else if self.relativeLane <= -2 {
            return UIColor.redColor()
        }
        else if self.relativeLane == -1 {
            return UIColor.orangeColor()
        }
        else if self.relativeLane == 1 {
            return UIColor.blueColor()
        }
        return UIColor.beeGreenColor()
    }
    
    var relativeLane : NSNumber {
        return NSNumber(int: self.lane.intValue * self.yaw.intValue)
    }
    
    var attributedDeltaText :NSAttributedString {
        if self.delta_text.componentsSeparatedByString("✔").count == 4 {
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
        
        attString.mutableString.replaceOccurrencesOfString("✔", withString: "", options: NSStringCompareOptions.LiteralSearch, range: NSRange(location: 0, length: attString.string.characters.count))

        return attString
    }
    
    var deltaColors :Array<UIColor> {
        if self.yaw == 1 {
            return [UIColor.orangeColor(), UIColor.blueColor(), UIColor.beeGreenColor()]
        }
        return [UIColor.beeGreenColor(), UIColor.blueColor(), UIColor.orangeColor()]
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
        return points.sort({ (d1, d2) -> Bool in
            if d1.timestamp == d2.timestamp {
                return d1.updated_at < d2.updated_at
            }
            return d1.timestamp < d2.timestamp
        })
    }
    
    func lastFiveDatapoints() -> [Datapoint] {
        var allDatapoints = self.orderedDatapoints()
        if allDatapoints.count < 6 {
            return allDatapoints
        }
        
        return Array(allDatapoints[(allDatapoints.count - 5)...(allDatapoints.count - 1)])
    }
    
}