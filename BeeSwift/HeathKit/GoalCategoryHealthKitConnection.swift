//  GoalCategoryHealthKitConenction.swift
//  BeeSwift
//
//  Responsible for keeping a goal in sync with a Category-based
//  HealthKit goal


import Foundation
import HealthKit
import OSLog

class GoalCategoryHealthKitConnection : BaseGoalHealthKitConnection {
    private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "GoalCategoryHealthKitConnection")

    let hkCategoryTypeIdentifier: HKCategoryTypeIdentifier

    init(healthStore: HKHealthStore, goal: JSONGoal, hkCategoryTypeIdentifier: HKCategoryTypeIdentifier) {
        self.hkCategoryTypeIdentifier = hkCategoryTypeIdentifier
        super.init(healthStore: healthStore, goal: goal)
    }


    override func hkSampleType() -> HKSampleType? {
        return HKObjectType.categoryType(forIdentifier: self.hkCategoryTypeIdentifier)
    }

    override func hkPermissionType() -> HKObjectType? {
        return HKObjectType.categoryType(forIdentifier: self.hkCategoryTypeIdentifier)
    }

    override func setupQuery() {
        guard let sampleType = self.hkSampleType() else { return }
        let query = HKObserverQuery(sampleType: sampleType, predicate: nil, updateHandler: { (query, completionHandler, error) in
            self.logger.notice("ObserverQuery for \(self.goal.healthKitMetric ?? "nil", privacy: .public) received update query \(query, privacy: .public) error \(error, privacy: .public)")
            Task {
                do {
                    try await self.hkQueryForLast(days: 1)
                    completionHandler()
                } catch {
                    self.logger.error("Error fetching data in response to observer query \(query) error: \(error)")
                }
            }
        })
        healthStore.execute(query)
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


    internal override func runQuery(dayOffset : Int) async throws {
        logger.notice("Starting: runCategoryTypeQuery for \(self.goal.healthKitMetric ?? "nil", privacy: .public) offset \(dayOffset)")

        guard let sampleType = self.hkSampleType() else { return }
        let predicate = self.predicateForDayOffset(dayOffset: dayOffset)
        let daystamp = self.dayStampFromDayOffset(dayOffset: dayOffset)

        let samples = try await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<[HKSample], Error>) in
            let query = HKSampleQuery.init(sampleType: sampleType, predicate: predicate, limit: 0, sortDescriptors: nil, resultsHandler: { (query, samples, error) in
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
        if datapointValue == 0 {
            logger.notice("Skipping: runCategoryTypeQuery for \(self.goal.healthKitMetric ?? "nil", privacy: .public) as value is 0")
            return
        }

        try await self.updateBeeminderWithValue(datapointValue: datapointValue, daystamp: daystamp)

        logger.notice("Completed: runCategoryTypeQuery for \(self.goal.healthKitMetric ?? "nil", privacy: .public)")
    }

    internal override func dateBoundsForDayOffset(dayOffset : Int) -> [Date] {
        if self.goal.healthKitMetric == "timeAsleep" || self.goal.healthKitMetric == "timeInBed" {
            return self.sleepDateBoundsForDayOffset(dayOffset: dayOffset)
        }
        return super.dateBoundsForDayOffset(dayOffset: dayOffset)
    }

    func hkDatapointValueForSample(sample: HKSample, units: HKUnit?) -> Double {
        if let s = sample as? HKQuantitySample, let u = units {
            return s.quantity.doubleValue(for: u)
        } else if let s = sample as? HKCategorySample {
            if (self.goal.healthKitMetric == "timeAsleep" && s.value != HKCategoryValueSleepAnalysis.asleep.rawValue) ||
                (self.goal.healthKitMetric == "timeInBed" && s.value != HKCategoryValueSleepAnalysis.inBed.rawValue) {
                return 0
            } else if self.hkCategoryTypeIdentifier == .appleStandHour {
                return Double(s.value)
            } else if self.hkCategoryTypeIdentifier == .sleepAnalysis {
                return s.endDate.timeIntervalSince(s.startDate)/3600.0
            }
            if self.hkCategoryTypeIdentifier == .mindfulSession {
                return s.endDate.timeIntervalSince(s.startDate)/60.0
            }
        }
        return 0
    }

    func hkDatapointValueForSamples(samples : [HKSample], units: HKUnit?) -> Double {
        var datapointValue : Double = 0
        if self.goal.healthKitMetric == "weight" {
            return self.hkDatapointValueForWeightSamples(samples: samples, units: units)
        }

        samples.forEach { (sample) in
            datapointValue += self.hkDatapointValueForSample(sample: sample, units: units)
        }
        return datapointValue
    }

    internal func hkDatapointValueForWeightSamples(samples : [HKSample], units: HKUnit?) -> Double {
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
