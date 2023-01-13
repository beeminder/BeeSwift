//
//  SleepAnalysisHealthKitMetric.swift
//  BeeSwift
//
//  Created by Theo Spears on 10/31/22.
//  Copyright © 2022 APB. All rights reserved.
//

import Foundation
import HealthKit
import OSLog

class TimeInBedHealthKitMetric : CategoryHealthKitMetric {
    let hourInSeconds = 3600.0

    init(humanText: String, databaseString: String, category: HealthKitCategory) {
        super.init(humanText: humanText, databaseString: databaseString, category: category, hkCategoryTypeIdentifier: .sleepAnalysis)
    }

    override func includeForMetric(sample: HKCategorySample) -> Bool {
        return sample.value == HKCategoryValueSleepAnalysis.inBed.rawValue
    }

    override func valueInAppropriateUnits(rawValue: Double) -> Double {
        return rawValue / hourInSeconds
    }
}
