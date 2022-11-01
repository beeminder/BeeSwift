//
//  SleepAnalysisHealthKitMetric.swift
//  BeeSwift
//
//  Created by Theo Spears on 10/31/22.
//  Copyright © 2022 APB. All rights reserved.
//

import Foundation
import HealthKit

class SleepAnalysisHealthKitMetric : CategoryHealthKitMetric {
    let hourInSeconds = 3600.0
    let hkCategoryValueSleepAnalysis : HKCategoryValueSleepAnalysis

    init(humanText: String, databaseString: String, hkCategoryTypeIdentifier: HKCategoryTypeIdentifier, hkCategoryValueSleepAnalysis : HKCategoryValueSleepAnalysis) {
        self.hkCategoryValueSleepAnalysis = hkCategoryValueSleepAnalysis
        super.init(humanText: humanText, databaseString: databaseString, hkCategoryTypeIdentifier: hkCategoryTypeIdentifier)
    }

    override func hkDatapointValueForSample(sample: HKSample, units: HKUnit?) -> Double {
        guard let categorySample = sample as? HKCategorySample else {
            // TODO: Warn
            return 0
        }

        // HealthKit will give us all SleepAnalysis samples (e.g. sleep and time in bed) so we
        // must post-filter to appropriate ones
        if categorySample.value == HKCategoryValueSleepAnalysis.asleep.rawValue {
            return categorySample.endDate.timeIntervalSince(categorySample.startDate) / hourInSeconds
        }

        return 0
    }

    override func dayStampFromDayOffset(dayOffset : Int, deadline : Int) -> String {
        let bounds = self.dateBoundsForDayOffset(dayOffset: dayOffset, deadline: deadline)
        let datapointDate = bounds[1]

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: datapointDate)
    }

    override func dateBoundsForDayOffset(dayOffset : Int, deadline : Int) -> [Date] {
        let calendar = Calendar.current

        let components = calendar.dateComponents(in: TimeZone.current, from: Date())

        let sixPmToday = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: calendar.date(from: components)!)
        let sixPmTomorrow = calendar.date(byAdding: .day, value: 1, to: sixPmToday!)

        guard let startDate = calendar.date(byAdding: .day, value: dayOffset, to: sixPmToday!) else { return [] }
        guard let endDate = calendar.date(byAdding: .day, value: dayOffset, to: sixPmTomorrow!) else { return [] }

        return [startDate, endDate]
    }

    
}
