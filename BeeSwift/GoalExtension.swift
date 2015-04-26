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
            return "Lost!"
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
        else if self.lane <= -2 {
            return UIColor.redColor()
        }
        else if self.lane == -1 {
            return UIColor.orangeColor()
        }
        else if self.lane == 1 {
            return UIColor.blueColor()
        }
        return UIColor.beeGreenColor()
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