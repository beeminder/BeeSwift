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
        NSManagedObjectContext.MR_defaultContext().save(nil)
    }
    
    var rateString :String {
        return "\(self.rate)/\(self.humanizedRunits)"
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