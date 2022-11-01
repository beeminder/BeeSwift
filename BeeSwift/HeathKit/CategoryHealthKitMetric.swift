//  CategoryHealthKitMetric.swift
//  BeeSwift
//
//  A HealthKit metric represented by `HkCategorySample`s and must be manually
//  converted to metrics by the app

import Foundation
import HealthKit
import OSLog

class CategoryHealthKitMetric : HealthKitMetric {
    private static let logger = Logger(subsystem: "com.beeminder.beeminder", category: "CategoryHealthKitMetric")

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
        var results : [DataPoint] = []
        for dayOffset in ((-1*days + 1)...0) {
            results.append(try await self.getDataPoint(dayOffset: dayOffset, deadline: deadline, healthStore: healthStore))
        }
        return results
    }

    private func sleepDateBoundsForDayOffset(dayOffset : Int) -> [Date] {
        let calendar = Calendar.current

        let components = calendar.dateComponents(in: TimeZone.current, from: Date())

        let sixPmToday = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: calendar.date(from: components)!)
        let sixPmTomorrow = calendar.date(byAdding: .day, value: 1, to: sixPmToday!)

        guard let startDate = calendar.date(byAdding: .day, value: dayOffset, to: sixPmToday!) else { return [] }
        guard let endDate = calendar.date(byAdding: .day, value: dayOffset, to: sixPmTomorrow!) else { return [] }

        return [startDate, endDate]
    }

    private func getDataPoint(dayOffset : Int, deadline : Int, healthStore : HKHealthStore) async throws -> DataPoint {
        CategoryHealthKitMetric.logger.notice("Starting: runCategoryTypeQuery for \(self.databaseString, privacy: .public) offset \(dayOffset)")

        let predicate = self.predicateForDayOffset(dayOffset: dayOffset, deadline: deadline)
        let daystamp = self.dayStampFromDayOffset(dayOffset: dayOffset, deadline: deadline)

        let samples = try await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<[HKSample], Error>) in
            let query = HKSampleQuery.init(sampleType: sampleType(), predicate: predicate, limit: 0, sortDescriptors: nil, resultsHandler: { (query, samples, error) in
                if error != nil {
                    continuation.resume(throwing: error!)
                } else if samples == nil {
                    continuation.resume(throwing: RuntimeError("HKSampleQuery did not return samples"))
                } else {
                    continuation.resume(returning: samples!)
                }


            })
            healthStore.execute(query)
        })

        let datapointValue = self.hkDatapointValueForSamples(samples: samples, units: nil)

        CategoryHealthKitMetric.logger.notice("Completed: runCategoryTypeQuery for \(self.databaseString, privacy: .public)")

        return (daystamp: daystamp, value: datapointValue, comment: "Auto-entered via Apple Health")
    }

    private func predicateForDayOffset(dayOffset : Int, deadline : Int) -> NSPredicate? {
        let bounds = dateBoundsForDayOffset(dayOffset: dayOffset, deadline: deadline)
        return HKQuery.predicateForSamples(withStart: bounds[0], end: bounds[1], options: .strictEndDate)
    }

    private func dayStampFromDayOffset(dayOffset : Int, deadline : Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let bounds = self.dateBoundsForDayOffset(dayOffset: dayOffset, deadline: deadline)
        let datapointDate = (deadline >= 0 && databaseString != "timeAsleep" && databaseString != "timeInBed") ? bounds[0] : bounds[1]
        return formatter.string(from: datapointDate)
    }

    private func dateBoundsForDayOffset(dayOffset : Int, deadline : Int) -> [Date] {
        if databaseString == "timeAsleep" || databaseString == "timeInBed" {
            return self.sleepDateBoundsForDayOffset(dayOffset: dayOffset)
        }

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
            if (databaseString == "timeAsleep" && s.value != HKCategoryValueSleepAnalysis.asleep.rawValue) ||
                (databaseString == "timeInBed" && s.value != HKCategoryValueSleepAnalysis.inBed.rawValue) {
                return 0
            } else if self.hkCategoryTypeIdentifier == .appleStandHour {
                return Double(s.value)
            } else if self.hkCategoryTypeIdentifier == .sleepAnalysis {
                return s.endDate.timeIntervalSince(s.startDate)/3600.0
            }
        }
        return 0
    }

    private func hkDatapointValueForSamples(samples : [HKSample], units: HKUnit?) -> Double {
        var datapointValue : Double = 0
        if databaseString == "weight" {
            return self.hkDatapointValueForWeightSamples(samples: samples, units: units)
        }

        samples.forEach { (sample) in
            datapointValue += self.hkDatapointValueForSample(sample: sample, units: units)
        }
        return datapointValue
    }

    private func hkDatapointValueForWeightSamples(samples : [HKSample], units: HKUnit?) -> Double {
        var datapointValue : Double = 0
        let weights = samples.map { (sample) -> Double? in
            let s = sample as? HKQuantitySample
            if s != nil { return (s?.quantity.doubleValue(for: units!))! }
            else {
                return nil
            }
        }
        let weight = weights.min { (w1, w2) -> Bool in
            if w1 == nil { return true }
            if w2 == nil { return false }
            return w2! > w1!
        }
        if weight != nil {
            datapointValue = weight!!
        }
        return datapointValue
    }
}
