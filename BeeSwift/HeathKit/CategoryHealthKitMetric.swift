//  CategoryHealthKitMetric.swift
//  BeeSwift
//
//  A HealthKit metric represented by `HkCategorySample`s and must be manually
//  converted to metrics by the app

import Foundation
import HealthKit
import OSLog

class CategoryHealthKitMetric : HealthKitMetric {
    private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "CategoryHealthKitMetric")

    let humanText : String
    let databaseString : String
    let hkCategoryTypeIdentifier : HKCategoryTypeIdentifier

    internal init(humanText: String, databaseString: String, hkCategoryTypeIdentifier: HKCategoryTypeIdentifier) {
        self.humanText = humanText
        self.databaseString = databaseString
        self.hkCategoryTypeIdentifier = hkCategoryTypeIdentifier
    }

    func sampleType() -> HKSampleType {
        return HKObjectType.categoryType(forIdentifier: self.hkCategoryTypeIdentifier)!
    }

    func permissionType() -> HKObjectType {
        return HKObjectType.categoryType(forIdentifier: self.hkCategoryTypeIdentifier)!
    }

    func recentDataPoints(days : Int, deadline : Int, healthStore : HKHealthStore) async throws -> [DataPoint] {
        logger.notice("Fetching \(days) recent data points for \(self.databaseString, privacy: .public)")

        var results : [DataPoint] = []
        for dayOffset in ((-1*days + 1)...0) {
            results.append(try await self.getDataPoint(dayOffset: dayOffset, deadline: deadline, healthStore: healthStore))
        }
        return results
    }

    private func getDataPoint(dayOffset : Int, deadline : Int, healthStore : HKHealthStore) async throws -> DataPoint {
        let predicate = self.predicateForDayOffset(dayOffset: dayOffset, deadline: deadline)
        let daystamp = self.dayStampFromDayOffset(dayOffset: dayOffset, deadline: deadline)

        let samples = try await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<[HKSample], Error>) in
            let query = HKSampleQuery.init(sampleType: sampleType(), predicate: predicate, limit: 0, sortDescriptors: nil, resultsHandler: { (query, samples, error) in
                if error != nil {
                    continuation.resume(throwing: error!)
                } else if samples == nil {
                    continuation.resume(throwing: HealthKitError("HKSampleQuery did not return samples"))
                } else {
                    continuation.resume(returning: samples!)
                }
            })
            healthStore.execute(query)
        })

        let datapointValue = self.hkDatapointValueForSamples(samples: samples, units: nil)
        return (daystamp: daystamp, value: datapointValue, comment: "Auto-entered via Apple Health")
    }

    private func predicateForDayOffset(dayOffset : Int, deadline : Int) -> NSPredicate? {
        let bounds = dateBoundsForDayOffset(dayOffset: dayOffset, deadline: deadline)
        return HKQuery.predicateForSamples(withStart: bounds[0], end: bounds[1], options: .strictEndDate)
    }

    internal func dayStampFromDayOffset(dayOffset : Int, deadline : Int) -> String {
        let bounds = self.dateBoundsForDayOffset(dayOffset: dayOffset, deadline: deadline)
        let datapointDate = deadline >= 0 ? bounds[0] : bounds[1]

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: datapointDate)
    }

    func dateBoundsForDayOffset(dayOffset : Int, deadline : Int) -> [Date] {
        let calendar = Calendar.current

        let components = calendar.dateComponents(in: TimeZone.current, from: Date())
        let localMidnightThisMorning = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: calendar.date(from: components)!)
        let localMidnightTonight = calendar.date(byAdding: .day, value: 1, to: localMidnightThisMorning!)

        let endOfToday = calendar.date(byAdding: .second, value: deadline, to: localMidnightTonight!)
        let startOfToday = calendar.date(byAdding: .second, value: deadline, to: localMidnightThisMorning!)

        guard let startDate = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday!) else { return [] }
        guard let endDate = calendar.date(byAdding: .day, value: dayOffset, to: endOfToday!) else { return [] }

        return [startDate, endDate]
    }

    func hkDatapointValueForSample(sample: HKSample, units: HKUnit?) -> Double {
        if let s = sample as? HKQuantitySample, let u = units {
            return s.quantity.doubleValue(for: u)
        } else if let s = sample as? HKCategorySample {
            if self.hkCategoryTypeIdentifier == .appleStandHour {
                return Double(s.value)
            }
        }
        return 0
    }

    private func hkDatapointValueForSamples(samples : [HKSample], units: HKUnit?) -> Double {
        var datapointValue : Double = 0
        samples.forEach { (sample) in
            datapointValue += self.hkDatapointValueForSample(sample: sample, units: units)
        }
        return datapointValue
    }
}
