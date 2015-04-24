//
//  Goal.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/23/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation
import CoreData

@objc(Goal)
class Goal: NSManagedObject {

    @NSManaged var slug: String
    @NSManaged var title: String
    @NSManaged var burner: String
    @NSManaged var runits: String
    @NSManaged var rate: NSNumber
    @NSManaged var losedate: NSNumber
    @NSManaged var panic: NSNumber
    @NSManaged var graph_url: String
    @NSManaged var thumb_url: String
    @NSManaged var delta_text: String
    @NSManaged var datapoints: NSSet

}
