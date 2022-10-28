//
//  JSONGoal+Healthkit.swift
//  BeeSwift
//
//  Created by Andrew Brett on 11/14/21.
//  Copyright © 2021 APB. All rights reserved.
//

import Foundation
import SwiftyJSON
import HealthKit
import OSLog

class GoalHealthKitConnection {
    let logger = Logger(subsystem: "com.beeminder.beeminder", category: "GoalHealthKitConnection")
    let healthStore: HKHealthStore
    let goal : JSONGoal

    init(healthStore: HKHealthStore, goal: JSONGoal) {
        self.healthStore = healthStore
        self.goal = goal
    }
    
    private enum HKQueryResult {
        case incomplete
        case success
        case failure
    }
    
    func setupHealthKit() async throws {
        guard let sampleType = self.hkSampleType() else { return }
        try await healthStore.enableBackgroundDelivery(for: sampleType, frequency: HKUpdateFrequency.immediate)
        registerObserverQuery()
    }

    func registerObserverQuery() {
        if self.hkQuantityTypeIdentifier() != nil {
            self.setupHKStatisticsCollectionQuery()
        }
        else if self.hkSampleType() != nil {
            self.setupHKObserverQuery()
        } else {
            // big trouble
            logger.error("Failed to register query for \(self.goal.healthKitMetric ?? "nil", privacy: .public) with neither hkQuantityTypeIdentifier nor hkSampleType")
        }
    }

    func hkQuantityTypeIdentifier() -> HKQuantityTypeIdentifier? {
        return HealthKitConfig.shared.metrics.first { (metric) -> Bool in
            metric.databaseString == self.goal.healthKitMetric
            }?.hkIdentifier
    }

    func hkCategoryTypeIdentifier() -> HKCategoryTypeIdentifier? {
        return HealthKitConfig.shared.metrics.first { (metric) -> Bool in
            metric.databaseString == self.goal.healthKitMetric
            }?.hkCategoryTypeIdentifier
    }
    
    func hkSampleType() -> HKSampleType? {
        if self.hkQuantityTypeIdentifier() != nil {
            return HKObjectType.quantityType(forIdentifier: self.hkQuantityTypeIdentifier()!)
        }
        if self.hkCategoryTypeIdentifier() != nil {
            return HKObjectType.categoryType(forIdentifier: self.hkCategoryTypeIdentifier()!)
        }
        return nil
    }
    
    func setupHKObserverQuery() {
        guard let sampleType = self.hkSampleType() else { return }
        let query = HKObserverQuery(sampleType: sampleType, predicate: nil, updateHandler: { (query, completionHandler, error) in
            self.logger.notice("ObserverQuery for \(self.goal.healthKitMetric ?? "nil", privacy: .public) received update")
            Task {
                do {
                    try await self.hkQueryForLast(days: 1)
                } catch {
                    self.logger.error("Error fetching data in response to observer query \(query) error: \(error)")
                }
            }
        })
        healthStore.execute(query)
    }
    
    func hkPermissionType() -> HKObjectType? {
        if self.hkQuantityTypeIdentifier() != nil {
            return HKObjectType.quantityType(forIdentifier: self.hkQuantityTypeIdentifier()!)
        } else if self.hkCategoryTypeIdentifier() != nil {
            return HKObjectType.categoryType(forIdentifier: self.hkCategoryTypeIdentifier()!)
        }
        return nil
    }
    
    func hkQueryForLast(days : Int) async throws {
        for dayOffset in ((-1*days + 1)...0) {
            if self.hkQuantityTypeIdentifier() != nil {
                try await self.runStatsQuery(dayOffset: dayOffset)
            } else {
                try await self.runCategoryTypeQuery(dayOffset: dayOffset)
            }
        }
    }
    
    private func runCategoryTypeQuery(dayOffset : Int) async throws {
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
    
    func hkDatapointValueForSample(sample: HKSample, units: HKUnit?) -> Double {
        if let s = sample as? HKQuantitySample, let u = units {
            return s.quantity.doubleValue(for: u)
        } else if let s = sample as? HKCategorySample {
            if (self.goal.healthKitMetric == "timeAsleep" && s.value != HKCategoryValueSleepAnalysis.asleep.rawValue) ||
                (self.goal.healthKitMetric == "timeInBed" && s.value != HKCategoryValueSleepAnalysis.inBed.rawValue) {
                return 0
            } else if self.hkCategoryTypeIdentifier() == .appleStandHour {
                return Double(s.value)
            } else if self.hkCategoryTypeIdentifier() == .sleepAnalysis {
                return s.endDate.timeIntervalSince(s.startDate)/3600.0
            }
            if self.hkCategoryTypeIdentifier() == .mindfulSession {
                return s.endDate.timeIntervalSince(s.startDate)/60.0
            }
        }
        return 0
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
    
    func updateBeeminderWithActivitySummaries(summaries: [HKActivitySummary]?) async throws {
        if summaries == nil { return }
        for summary in summaries! {
            let calendar = Calendar.current
            let dateComponents = summary.dateComponents(for: Calendar.current)
            guard let summaryDate = calendar.date(from: dateComponents) else { return }
            // ignore anything older than 7 days
            if summaryDate.compare(Date(timeIntervalSinceNow: -604800)) == ComparisonResult.orderedAscending {
                return
            }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd"
            let daystamp = formatter.string(from: summaryDate)
            let standHours = summary.appleStandHours
            try await self.updateBeeminderWithValue(datapointValue: standHours.doubleValue(for: HKUnit.count()), daystamp: daystamp)
        }
    }
    
    func setupHKStatisticsCollectionQuery() {
        logger.notice("Starting: setupHKStatisticsCollectionQuery for \(self.goal.healthKitMetric ?? "nil", privacy: .public)")

        if ((self.hkQuantityTypeIdentifier() == nil)) { return }
        guard let quantityType = HKObjectType.quantityType(forIdentifier: self.hkQuantityTypeIdentifier()!) else { return }
        
        let calendar = Calendar.current
        var interval = DateComponents()
        interval.day = 1
        
        var anchorComponents = calendar.dateComponents([.day, .month, .year, .weekday], from: Date())
        anchorComponents.hour = 0
        anchorComponents.minute = 0
        anchorComponents.second = 0
        
        guard let midnight = calendar.date(from: anchorComponents) else {
            fatalError("*** unable to create a valid date from the given components ***")
        }
        let anchorDate = calendar.date(byAdding: .second, value: self.goal.deadline.intValue, to: midnight)!
        
        var options : HKStatisticsOptions
        if quantityType.aggregationStyle == .cumulative {
            options = .cumulativeSum
        } else {
            options = .discreteMin
        }
        
        let query = HKStatisticsCollectionQuery(quantityType: quantityType,
                                                quantitySamplePredicate: nil,
                                                options: options,
                                                anchorDate: anchorDate,
                                                intervalComponents: interval)
        query.initialResultsHandler = {
            query, collection, error in
            self.logger.notice("Initial Data: setupHKStatisticsCollectionQuery for \(self.goal.healthKitMetric ?? "nil", privacy: .public)")
            
            guard let statsCollection = collection else {
                // Perform proper error handling here
                return
            }
            Task(priority: .background) {
                do {
                    try await self.updateBeeminderWithStatsCollection(collection: statsCollection)
                } catch {
                    self.logger.error("Error updating beeminder based on initial results \(query) error: \(error)")
                }
            }
        }
        
        query.statisticsUpdateHandler = {
            query, statistics, collection, error in
            self.logger.notice("Statistics Update: setupHKStatisticsCollectionQuery for \(self.goal.healthKitMetric ?? "nil", privacy: .public)")
            
            if HKHealthStore.isHealthDataAvailable() {
                guard let statsCollection = collection else { return }

                Task {
                    do {
                        try await self.updateBeeminderWithStatsCollection(collection: statsCollection)
                    } catch {
                        self.logger.error("Error updating beeminder based on statistics update \(query) error: \(error)")
                    }
                }
            }
        }
        healthStore.execute(query)

        logger.notice("Complete: setupHKStatisticsCollectionQuery for \(self.goal.healthKitMetric ?? "nil", privacy: .public)")
    }
    
    func updateBeeminderWithStatsCollection(collection : HKStatisticsCollection) async throws {
        let endDate = Date()
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -5, to: endDate) else {
            return
        }

        let datapoints = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[JSON], Error>) in
            self.goal.fetchRecentDatapoints(success: { datapoints in
                continuation.resume(returning: datapoints)
            }, errorCompletion: {
                continuation.resume(throwing: RuntimeError("Could not fetch recent datapoints"))
            })
        }

        for statistics in collection.statistics() {
            // Ignore statistics which are entirely outside our window
            if statistics.endDate < startDate || statistics.startDate > endDate {
                continue
            }

            let units = try await healthStore.preferredUnits(for: [statistics.quantityType])
            guard let unit = units.first?.value else { return }
            guard let quantityTypeIdentifier = self.hkQuantityTypeIdentifier() else { return }

            guard let quantityType = HKObjectType.quantityType(forIdentifier: quantityTypeIdentifier) else {
                fatalError("*** Unable to create a quantity type ***")
            }

            let value: Double? = {
                switch quantityType.aggregationStyle {
                case .cumulative:
                    return statistics.sumQuantity()?.doubleValue(for: unit)
                case .discrete:
                    return statistics.minimumQuantity()?.doubleValue(for: unit)
                default:
                    return nil
                }
            }()

            guard let datapointValue = value else { return }

            let startDate = statistics.startDate
            let endDate = statistics.endDate

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd"
            let datapointDate = self.goal.deadline.intValue >= 0 ? startDate : endDate
            let daystamp = formatter.string(from: datapointDate)

            try await self.updateBeeminderWithValue(datapointValue: datapointValue, daystamp: daystamp, recentDatapoints: datapoints)
        }
    }
    
    private func runStatsQuery(dayOffset : Int) async throws {
        logger.notice("Started: runStatsQuery for \(self.goal.healthKitMetric ?? "nil", privacy: .public) offset \(dayOffset)")

        guard let sampleType = self.hkSampleType() else { return }
        let predicate = self.predicateForDayOffset(dayOffset: dayOffset)
        let daystamp = self.dayStampFromDayOffset(dayOffset: dayOffset)
        
        var options : HKStatisticsOptions
        guard let quantityType = HKObjectType.quantityType(forIdentifier: self.hkQuantityTypeIdentifier()!) else { return }
        if quantityType.aggregationStyle == .cumulative {
            options = .cumulativeSum
        } else {
            options = .discreteMin
        }

        let statistics = try await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<HKStatistics, Error>) in
            let statsQuery = HKStatisticsQuery.init(quantityType: sampleType as! HKQuantityType, quantitySamplePredicate: predicate, options: options) { (query, statistics, error) in
                if error != nil {
                    continuation.resume(throwing: error!)
                } else if statistics == nil {
                    continuation.resume(throwing: RuntimeError("Statistics unexpectedly nil"))
                } else {
                    continuation.resume(returning: statistics!)
                }

            }
            healthStore.execute(statsQuery)
        })

        guard let quantityTypeIdentifier = self.hkQuantityTypeIdentifier() else {
            return
        }
        guard let quantityType = HKObjectType.quantityType(forIdentifier: quantityTypeIdentifier) else {
            throw RuntimeError("*** Unable to create a quantity type ***")
        }

        let units = try await healthStore.preferredUnits(for: [quantityType])

        var datapointValue : Double?
        guard let unit = units.first?.value else { return }

        let aggStyle : HKQuantityAggregationStyle
        if #available(iOS 13.0, *) { aggStyle = .discreteArithmetic } else { aggStyle = .discrete }

        if quantityType.aggregationStyle == .cumulative {
            let quantity = statistics.sumQuantity()
            datapointValue = quantity?.doubleValue(for: unit)
        } else if quantityType.aggregationStyle == aggStyle {
            let quantity = statistics.minimumQuantity()
            datapointValue = quantity?.doubleValue(for: unit)
        }

        if datapointValue == nil || datapointValue == 0  { return }

        try await self.updateBeeminderWithValue(datapointValue: datapointValue!, daystamp: daystamp)

        logger.notice("Complete: runStatsQuery for \(self.goal.healthKitMetric ?? "nil", privacy: .public)")
    }
    
    private func predicateForDayOffset(dayOffset : Int) -> NSPredicate? {
        let bounds = dateBoundsForDayOffset(dayOffset: dayOffset)
        return HKQuery.predicateForSamples(withStart: bounds[0], end: bounds[1], options: .strictEndDate)
    }
    
    private func dateBoundsForDayOffset(dayOffset : Int) -> [Date] {
        if self.goal.healthKitMetric == "timeAsleep" || self.goal.healthKitMetric == "timeInBed" {
            return self.sleepDateBoundsForDayOffset(dayOffset: dayOffset)
        }
        let calendar = Calendar.current
        
        let components = calendar.dateComponents(in: TimeZone.current, from: Date())
        let localMidnightThisMorning = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: calendar.date(from: components)!)
        let localMidnightTonight = calendar.date(byAdding: .day, value: 1, to: localMidnightThisMorning!)
        
        let endOfToday = calendar.date(byAdding: .second, value: self.goal.deadline.intValue, to: localMidnightTonight!)
        let startOfToday = calendar.date(byAdding: .second, value: self.goal.deadline.intValue, to: localMidnightThisMorning!)
        
        guard let startDate = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday!) else { return [] }
        guard let endDate = calendar.date(byAdding: .day, value: dayOffset, to: endOfToday!) else { return [] }
        
        return [startDate, endDate]
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
    
    private func dayStampFromDayOffset(dayOffset : Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let bounds = self.dateBoundsForDayOffset(dayOffset: dayOffset)
        let datapointDate = (self.goal.deadline.intValue >= 0 && self.goal.healthKitMetric != "timeAsleep" && self.goal.healthKitMetric != "timeInBed") ? bounds[0] : bounds[1]
        return formatter.string(from: datapointDate)
    }

    private func updateBeeminderWithValue(datapointValue : Double, daystamp : String) async throws {
        if datapointValue == 0  {
            return
        }

        let datapoints = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[JSON], Error>) in
            self.goal.fetchRecentDatapoints(success: { datapoints in
                continuation.resume(returning: datapoints)
            }, errorCompletion: {
                continuation.resume(throwing: RuntimeError("Could not fetch recent datapoints"))
            })
        }
        try await self.updateBeeminderWithValue(datapointValue: datapointValue, daystamp: daystamp, recentDatapoints: datapoints)
    }

    private func updateBeeminderWithValue(datapointValue : Double, daystamp : String, recentDatapoints: [JSON]) async throws {
        if datapointValue == 0  {
            return
        }

        var matchingDatapoints = self.goal.datapointsMatchingDaystamp(datapoints: recentDatapoints, daystamp: daystamp)
        if matchingDatapoints.count == 0 {
            let requestId = "\(daystamp)-\(self.goal.minuteStamp())"
            let params = ["access_token": CurrentUserManager.sharedManager.accessToken!, "urtext": "\(daystamp.suffix(2)) \(datapointValue) \"Auto-entered via Apple Health\"", "requestid": requestId]

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                self.goal.postDatapoint(params: params, success: { (responseObject) in
                    continuation.resume()
                }, failure: { (error, errorMessage) in
                    continuation.resume(throwing: error!)
                })
            }


        } else if matchingDatapoints.count >= 1 {
            let firstDatapoint = matchingDatapoints.remove(at: 0)
            matchingDatapoints.forEach { datapoint in
                self.goal.deleteDatapoint(datapoint: datapoint)
            }

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                self.goal.updateDatapoint(datapoint: firstDatapoint, datapointValue: datapointValue, success: {
                    continuation.resume()
                }, errorCompletion: {
                    continuation.resume(throwing: RuntimeError("Error updating data point"))
                })
            }
        }
    }
}
