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

class GoalHealthKitConnection {
    let goal : JSONGoal

    init(goal: JSONGoal) {
        self.goal = goal
    }
    
    private enum HKQueryResult {
        case incomplete
        case success
        case failure
    }
    
    func setupHealthKit() {
        guard let healthStore = HealthStoreManager.sharedManager.healthStore else { return }
        guard let sampleType = self.hkSampleType() else { return }
        
        healthStore.requestAuthorization(toShare: nil, read: [sampleType], completion: { (success, error) in
            if error != nil {
                //handle error
                return
            }
            healthStore.enableBackgroundDelivery(for: sampleType, frequency: HKUpdateFrequency.immediate, withCompletion: { (success, error) in
                if error != nil {
                    //handle error
                    return
                }
                if self.hkQuantityTypeIdentifier() != nil {
                    self.setupHKStatisticsCollectionQuery()
                }
                else if let query = self.hkObserverQuery() {
                    healthStore.execute(query)
                } else {
                    // big trouble
                }
            })
        })
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
    
    func hkObserverQuery() -> HKObserverQuery? {
        guard let sampleType = self.hkSampleType() else { return nil }
        return HKObserverQuery(sampleType: sampleType, predicate: nil, updateHandler: { (query, completionHandler, error) in
            self.hkQueryForLast(days: 1) {
                completionHandler()
            } errorCompletion: {
                //
            }
        })
    }
    
    func hkPermissionType() -> HKObjectType? {
        if self.hkQuantityTypeIdentifier() != nil {
            return HKObjectType.quantityType(forIdentifier: self.hkQuantityTypeIdentifier()!)
        } else if self.hkCategoryTypeIdentifier() != nil {
            return HKObjectType.categoryType(forIdentifier: self.hkCategoryTypeIdentifier()!)
        }
        return nil
    }
    
    func hkQueryForLast(days : Int, success: (() -> ())?, errorCompletion: (() -> ())?) {
        ((-1*days + 1)...0).forEach({ (dayOffset) in
            if self.hkQuantityTypeIdentifier() != nil {
                self.runStatsQuery(dayOffset: dayOffset) {
                    success?()
                } errorCompletion: {
                    errorCompletion?()
                }
            } else {
                self.runCategoryTypeQuery(dayOffset: dayOffset) {
                    success?()
                } errorCompletion: {
                    errorCompletion?()
                }
            }
        })
    }
    
    private func runCategoryTypeQuery(dayOffset : Int, success: (() -> ())?, errorCompletion: (() -> ())?) {
        guard let healthStore = HealthStoreManager.sharedManager.healthStore else { return }
        guard let sampleType = self.hkSampleType() else { return }
        let predicate = self.predicateForDayOffset(dayOffset: dayOffset)
        let daystamp = self.dayStampFromDayOffset(dayOffset: dayOffset)
        
        let query = HKSampleQuery.init(sampleType: sampleType, predicate: predicate, limit: 0, sortDescriptors: nil, resultsHandler: { (query, samples, error) in
            if error != nil || samples == nil { return }
            
            let datapointValue = self.hkDatapointValueForSamples(samples: samples!, units: nil)
            
            if datapointValue == 0 { return }
            
            self.updateBeeminderWithValue(datapointValue: datapointValue, daystamp: daystamp, success: success, errorCompletion: errorCompletion)
        })
        healthStore.execute(query)
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
    
    func activitySummaryUpdateHandler(query: HKActivitySummaryQuery, summaries: [HKActivitySummary]?, error: Error?) {
        guard let activitySummaries = summaries else {
            guard let queryError = error else {
                fatalError("*** Did not return a valid error object. ***")
            }
            print(queryError)
            return
        }
        self.updateBeeminderWithActivitySummaries(summaries: activitySummaries, success: nil, errorCompletion: nil)
    }
    
    func updateBeeminderWithActivitySummaries(summaries: [HKActivitySummary]?, success: (() -> ())?, errorCompletion: (() -> ())?) {
        summaries?.forEach({ (summary) in
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
            self.updateBeeminderWithValue(datapointValue: standHours.doubleValue(for: HKUnit.count()), daystamp: daystamp, success: {
                success?()
            }, errorCompletion: {
                errorCompletion?()
            })
        })
    }
    
    func setupHKStatisticsCollectionQuery() {
        guard let healthStore = HealthStoreManager.sharedManager.healthStore else { return }
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
            
            guard let statsCollection = collection else {
                // Perform proper error handling here
                return
            }
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + .seconds(5), execute: { [weak self] in
                self?.updateBeeminderWithStatsCollection(collection: statsCollection, success: nil, errorCompletion: nil)
            })
        }
        
        query.statisticsUpdateHandler = {
            [weak self] query, statistics, collection, error in
            
            if HKHealthStore.isHealthDataAvailable() {
                guard let statsCollection = collection else {
                    // Perform proper error handling here
                    return
                }
                
                self?.updateBeeminderWithStatsCollection(collection: statsCollection, success: nil, errorCompletion: nil)
            }
        }
        healthStore.execute(query)
    }
    
    func updateBeeminderWithStatsCollection(collection : HKStatisticsCollection, success: (() -> ())?, errorCompletion: (() -> ())?) {
        guard let healthStore = HealthStoreManager.sharedManager.healthStore else { return }
        
        let endDate = Date()
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -5, to: endDate) else {
            return
        }

        self.goal.fetchRecentDatapoints { datapoints in
            collection.enumerateStatistics(from: startDate, to: endDate) { [weak self] statistics, stop in
                guard let self = self else { return }

                healthStore.preferredUnits(for: [statistics.quantityType], completion: { [weak self] (units, error) in
                    guard let self = self else { return }
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

                    self.updateBeeminderWithValue(datapointValue: datapointValue, daystamp: daystamp, recentDatapoints: datapoints, success: success, errorCompletion: errorCompletion)
                })
            }
        } errorCompletion: {
            errorCompletion?()
        }
    }
    
    private func runStatsQuery(dayOffset : Int, success: (() -> ())?, errorCompletion: (() -> ())?) {
        guard let healthStore = HealthStoreManager.sharedManager.healthStore else { return }
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
        let statsQuery = HKStatisticsQuery.init(quantityType: sampleType as! HKQuantityType, quantitySamplePredicate: predicate, options: options, completionHandler: { (query, statistics, error) in
            if error != nil || statistics == nil { return }
            
            guard let quantityTypeIdentifier = self.hkQuantityTypeIdentifier() else {
                return
            }
            guard let quantityType = HKObjectType.quantityType(forIdentifier: quantityTypeIdentifier) else {
                fatalError("*** Unable to create a quantity type ***")
            }
            
            healthStore.preferredUnits(for: [quantityType], completion: { (units, error) in
                var datapointValue : Double?
                guard let unit = units.first?.value else { return }
                
                if quantityType.aggregationStyle == .cumulative {
                    let quantity = statistics!.sumQuantity()
                    datapointValue = quantity?.doubleValue(for: unit)
                } else if quantityType.aggregationStyle == .discreteArithmetic {
                    let quantity = statistics!.minimumQuantity()
                    datapointValue = quantity?.doubleValue(for: unit)
                }
                
                if datapointValue == nil || datapointValue == 0  { return }
                
                self.updateBeeminderWithValue(datapointValue: datapointValue!, daystamp: daystamp, success: {
                    success?()
                }, errorCompletion: {
                    errorCompletion?()
                })
            })
        })
        
        healthStore.execute(statsQuery)
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

    private func updateBeeminderWithValue(datapointValue : Double, daystamp : String, success: (() -> ())?, errorCompletion: (() -> ())?) {
        if datapointValue == 0  {
            success?()
            return
        }

        self.goal.fetchRecentDatapoints { datapoints in
            self.updateBeeminderWithValue(datapointValue: datapointValue, daystamp: daystamp, recentDatapoints: datapoints, success: success, errorCompletion: errorCompletion)
        } errorCompletion: {
            errorCompletion?()
        }
    }

    private func updateBeeminderWithValue(datapointValue : Double, daystamp : String, recentDatapoints: [JSON], success: (() -> ())?, errorCompletion: (() -> ())?) {
        if datapointValue == 0  {
            success?()
            return
        }

        var matchingDatapoints = self.goal.datapointsMatchingDaystamp(datapoints: recentDatapoints, daystamp: daystamp)
        if matchingDatapoints.count == 0 {
            let requestId = "\(daystamp)-\(self.goal.minuteStamp())"
            let params = ["access_token": CurrentUserManager.sharedManager.accessToken!, "urtext": "\(daystamp.suffix(2)) \(datapointValue) \"Auto-entered via Apple Health\"", "requestid": requestId]
            self.goal.postDatapoint(params: params, success: { (responseObject) in
                success?()
            }, failure: { (error, errorMessage) in
                errorCompletion?()
            })
        } else if matchingDatapoints.count >= 1 {
            let firstDatapoint = matchingDatapoints.remove(at: 0)
            matchingDatapoints.forEach { datapoint in
                self.goal.deleteDatapoint(datapoint: datapoint)
            }
            self.goal.updateDatapoint(datapoint: firstDatapoint, datapointValue: datapointValue) {
                success?()
            } errorCompletion: {
                errorCompletion?()
            }
        }
    }
}
