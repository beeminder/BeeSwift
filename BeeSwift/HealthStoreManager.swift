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
    }
}
