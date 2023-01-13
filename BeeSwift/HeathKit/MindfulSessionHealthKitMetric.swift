//
//  MindfulSessionHealthKitMetric.swift
//  BeeSwift
//
//  Created by Theo Spears on 10/31/22.
//  Copyright © 2022 APB. All rights reserved.
//

import Foundation
import HealthKit

class MindfulSessionHealthKitMetric : CategoryHealthKitMetric {
    override func valueInAppropriateUnits(rawValue: Double) -> Double {
        return rawValue / 60.0
    }
}
