//
//  Goal.swift
//  BeeSwift
//
//  Created by Andy Brett on 6/13/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation
import CoreData

@objc(Goal)
class Goal: NSManagedObject {

    @NSManaged var autodata: String
    @NSManaged var burner: String
    @NSManaged var delta_text: String
    @NSManaged var graph_url: String
    @NSManaged var healthKitMetric: String?
    @NSManaged var id: String
    @NSManaged var lane: NSNumber
    @NSManaged var isUpdatingHealth: Bool
    @NSManaged var losedate: NSNumber
    @NSManaged var panic: NSNumber
    @NSManaged var pledge: NSNumber
    @NSManaged var rate: NSNumber
    @NSManaged var runits: String
    @NSManaged var serverDeleted: NSNumber
    @NSManaged var slug: String
    @NSManaged var thumb_url: String
    @NSManaged var title: String
    @NSManaged var won: NSNumber
    @NSManaged var yaw: NSNumber
    @NSManaged var safebump: NSNumber
    @NSManaged var curval: NSNumber
    @NSManaged var limsum: String
    @NSManaged var datapoints: NSSet
    @NSManaged var deadline: NSNumber
    @NSManaged var leadtime: NSNumber
    @NSManaged var alertstart: NSNumber
    @NSManaged var use_defaults: NSNumber
}
