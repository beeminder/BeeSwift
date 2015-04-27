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
        if let goal :Goal = Goal.MR_findFirstByAttribute("slug", withValue:json["slug"].string) as? Goal {
            Goal.updateGoal(goal, withJSON: json)
        }
        else if let goal :Goal = Goal.MR_createEntity() as? Goal {
            Goal.updateGoal(goal, withJSON: json)
        }
    }
    
    class func updateGoal(goal :Goal, withJSON json :JSON) {
        goal.slug = json["slug"].string!
        goal.title = json["title"].string!
        goal.burner = json["burner"].string!
        goal.panic = json["panic"].number!
        goal.losedate = json["losedate"].number!
        goal.runits = json["runits"].string!
        goal.rate = json["rate"].number!
        goal.graph_url = json["graph_url"].string!
        goal.thumb_url = json["thumb_url"].string!
        goal.delta_text = json["delta_text"].string!
        goal.won = json["won"].number!
        goal.lane = json["lane"].number!
        goal.yaw = json["yaw"].number!
        NSManagedObjectContext.MR_defaultContext().save(nil)
    }
    
    var rateString :String {
        let formatter = NSNumberFormatter()
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
    
    var briefLosedate :String {
        var losedateDate = NSDate(timeIntervalSince1970: self.losedate.doubleValue)
        if losedateDate.timeIntervalSinceNow < 0 {
            return self.won.boolValue ? "Success!" : "Lost!"
        }
        else if losedateDate.timeIntervalSinceNow < 24*60*60 {
            // add 1 second since a 3 am goal technically derails at 2:59:59
            losedateDate = losedateDate.dateByAddingTimeInterval(1)
            let dateFormatter = NSDateFormatter()
            dateFormatter.dateFormat = "h a!"
            return dateFormatter.stringFromDate(losedateDate)
        }
        else if losedateDate.timeIntervalSinceNow < 7*24*60*60 {
            let dateFormatter = NSDateFormatter()
            let calendar = NSCalendar.currentCalendar()
            let hour = calendar.component(NSCalendarUnit.HourCalendarUnit, fromDate: losedateDate)
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
    
    var countdownColor :UIColor {
        var losedateDate = NSDate(timeIntervalSince1970: self.losedate.doubleValue)
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
            return NSAttributedString(string: "⭐️  ⭐️  ⭐️")
        }
        var spaceIndices :Array<Int> = [0]
        
        for i in 0...count(self.delta_text) - 1 {
            if Array(self.delta_text)[i] == " " {
                spaceIndices.append(i)
            }
        }
        
        spaceIndices.append(count(self.delta_text))

        var attString :NSMutableAttributedString = NSMutableAttributedString(string: self.delta_text)
        
        for i in 0...count(spaceIndices) {
            if i + 1 >= count(spaceIndices) {
                continue
            }
            attString.addAttribute(NSForegroundColorAttributeName, value: self.deltaColors[i], range: NSRange(location: spaceIndices[i], length: spaceIndices[i + 1] - spaceIndices[i]))
        }
        
        attString.mutableString.replaceOccurrencesOfString("✔", withString: "", options: NSStringCompareOptions.LiteralSearch, range: NSRange(location: 0, length: count(attString.string)))

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
}