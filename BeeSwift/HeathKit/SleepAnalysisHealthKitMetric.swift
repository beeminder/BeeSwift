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

class SleepAnalysisHealthKitMetric : CategoryHealthKitMetric {
    private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "SleepAnalysisHealthKitMetric")

    let hourInSeconds = 3600.0
    let hkCategoryValuesSleepAnalysis : Set<HKCategoryValueSleepAnalysis>

    init(humanText: String, databaseString: String, category: HealthKitCategory, hkCategoryValuesSleepAnalysis : Set<HKCategoryValueSleepAnalysis>) {
        self.hkCategoryValuesSleepAnalysis = hkCategoryValuesSleepAnalysis
        super.init(humanText: humanText, databaseString: databaseString, category: category, hkCategoryTypeIdentifier: .sleepAnalysis)
    }

    override func hkDatapointValueForSample(sample: HKSample, units: HKUnit?) -> Double {
        guard let categorySample = sample as? HKCategorySample else {
            logger.warning("Encountered a sleep sample which was not a HKCategorySample: \(sample)")
            return 0
        }

        // HealthKit will give us all SleepAnalysis samples (e.g. sleep and time in bed) so we
        // must post-filter to appropriate ones
        if hkCategoryValuesSleepAnalysis.map({$0.rawValue}).contains(categorySample.value) {
            return categorySample.endDate.timeIntervalSince(categorySample.startDate) / hourInSeconds
        }

        return 0
    }
}
