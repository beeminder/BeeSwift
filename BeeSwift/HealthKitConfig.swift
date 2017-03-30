//
//  HealthKitConfig.swift
//  BeeSwift
//
//  Created by Andy Brett on 3/25/17.
//  Copyright © 2017 APB. All rights reserved.
//

import Foundation
import HealthKit

struct HealthKitMetric {
    let humanText : String
    let databaseString : String?
    let hkIdentifier : HKQuantityTypeIdentifier?
}

struct HealthKitConfig {
    static let metrics : [HealthKitMetric] = [
        HealthKitMetric.init(humanText: "Steps", databaseString: "steps", hkIdentifier: HKQuantityTypeIdentifier.stepCount),
        HealthKitMetric.init(humanText: "Active energy", databaseString: "activeEnergy", hkIdentifier: HKQuantityTypeIdentifier.activeEnergyBurned)
    ]
}
