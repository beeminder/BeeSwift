//
//  HealthStoreManager.swift
//  BeeSwift
//
//  Created by Andy Brett on 11/28/17.
//  Copyright © 2017 APB. All rights reserved.
//

import Foundation
import HealthKit

class HealthStoreManager :NSObject {
    
    static let sharedManager = HealthStoreManager()
    var healthStore : HKHealthStore?
    
    func setupHealthkit() {
        self.healthStore = HKHealthStore()
        let allGoals = Goal.mr_findAll(with: NSPredicate(format: "serverDeleted = false")) as! [Goal]
        var permissions = Set<HKObjectType>.init()
        allGoals.forEach { (goal) in
            if goal.hkPermissionType() != nil { permissions.insert(goal.hkPermissionType()!) }
        }
        guard permissions.count > 0 else { return }
        guard let healthStore = HealthStoreManager.sharedManager.healthStore else { return }
        
        healthStore.requestAuthorization(toShare: nil, read: permissions, completion: { (success, error) in
            allGoals.forEach { (goal) in goal.setupHealthKit() }
        })
    }
}
