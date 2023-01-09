//
//  TimeAsleepHealthKitMetric.swift
//  BeeSwift
//
//  Created by Theo Spears on 1/8/23.
//

import Foundation
import HealthKit
import OSLog

class TimeAsleepHealthKitMetric : CategoryHealthKitMetric {
    let hourInMinutes = 60.0

    init(humanText: String, databaseString: String, category: HealthKitCategory) {
        super.init(humanText: humanText, databaseString: databaseString, category: category, hkCategoryTypeIdentifier: .sleepAnalysis)
    }

    override func hkDatapointValueForSamples(samples : [HKSample], units: HKUnit?) -> Double {
        let categorySamples = samples.compactMap{sample in sample as? HKCategorySample}
        let totalMinutes = totalSleepMinutes(samples: categorySamples)
        return Double(totalMinutes) / hourInMinutes
    }
}
