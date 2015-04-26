//
//  Goal.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/25/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation
import CoreData

@objc(Goal)
class Goal: NSManagedObject {

    @NSManaged var burner: String
    @NSManaged var delta_text: String
    @NSManaged var graph_url: String
    @NSManaged var losedate: NSNumber
    @NSManaged var panic: NSNumber
    @NSManaged var rate: NSNumber
    @NSManaged var runits: String
    @NSManaged var slug: String
    @NSManaged var thumb_url: String
    @NSManaged var title: String
    @NSManaged var won: NSNumber
    @NSManaged var lane: NSNumber
    @NSManaged var datapoints: NSSet

}
