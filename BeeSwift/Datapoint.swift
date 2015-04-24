//
//  Datapoint.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/23/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation
import CoreData

@objc(Datapoint)
class Datapoint: NSManagedObject {

    @NSManaged var timestamp: NSNumber
    @NSManaged var value: NSNumber
    @NSManaged var comment: String
    @NSManaged var id: String
    @NSManaged var updated_at: NSNumber
    @NSManaged var requestid: String
    @NSManaged var goal: Goal

}
