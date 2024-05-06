//  QuantityHealthKitMetric.swift
//  BeeSwift
//
//  A HealthKit metric which represented by `HKQuantitySample`s and can use the
//  HealthKit aggregation API

import Foundation
import HealthKit
import OSLog

class QuantityHealthKitMetric : HealthKitMetric {
    private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "QuantityHealthKitMetric")

    let humanText : String
    let databaseString : String
    let category : HealthKitCategory
    let hkQuantityTypeIdentifier : HKQuantityTypeIdentifier
    let precision: [HKUnit: Int]

    internal init(humanText: String, databaseString: String, category : HealthKitCategory, hkQuantityTypeIdentifier: HKQuantityTypeIdentifier, precision: [HKUnit: Int] = [:]) {
        self.humanText = humanText
        self.databaseString = databaseString
        self.category = category
        self.hkQuantityTypeIdentifier = hkQuantityTypeIdentifier
        self.precision = precision
    }

    func sampleType() -> HKSampleType {
        return HKObjectType.quantityType(forIdentifier: hkQuantityTypeIdentifier)!
    }

    func permissionType() -> HKObjectType {
        return HKObjectType.quantityType(forIdentifier: self.hkQuantityTypeIdentifier)!
    }

    func recentDataPoints(days : Int, deadline : Int, healthStore : HKHealthStore) async throws -> [BeeDataPoint] {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: self.hkQuantityTypeIdentifier) else {
            throw HealthKitError("Unable to look up a quantityType")
        }

        let today = Daystamp.now(deadline: deadline)
        let startDate = today - days
        let predicate = HKQuery.predicateForSamples(withStart: startDate.start(deadline: deadline), end: nil)

        let options : HKStatisticsOptions = quantityType.aggregationStyle == .cumulative ? .cumulativeSum : .discreteMin

        let statsCollection = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKStatisticsCollection, Error>) in
            let query = HKStatisticsCollectionQuery(quantityType: quantityType,
                                                    quantitySamplePredicate: predicate,
                                                    options: options,
                                                    anchorDate: today.start(deadline: deadline),
                                                    intervalComponents: DateComponents(day:1))
            query.initialResultsHandler = {
                query, collection, error in
                if error != nil {
                    continuation.resume(throwing: error!)
                } else if collection == nil {
                    continuation.resume(throwing: HealthKitError("HKStatisticsCollectionQuery returned a nil collection"))
                } else {
                    continuation.resume(returning: collection!)
                }
            }
            healthStore.execute(query)
        }

        return try await datapointsForCollection(collection: statsCollection, startDate: startDate, endDate: today, deadline: deadline, healthStore: healthStore)
    }

    func units(healthStore : HKHealthStore) async throws -> HKUnit {
        let quantityType = HKObjectType.quantityType(forIdentifier: hkQuantityTypeIdentifier)!
        let units = try await healthStore.preferredUnits(for: [quantityType])
        guard let unit = units.first?.value else {
            throw HealthKitError("No preferred units")
        }
        return unit
    }
    
    private func datapointsForCollection(collection : HKStatisticsCollection, startDate: Daystamp, endDate: Daystamp, deadline : Int, healthStore: HKHealthStore) async throws -> [BeeDataPoint] {

        var results : [BeeDataPoint] = []

        for statistics in collection.statistics() {
            // Use the midpoint of the interval to determine the daystamp. Theoretically using the startDate
            // should always be correct, but as it falls right on the boundary, using the midpoint seems more
            // robust.
            let intervalMidpoint = statistics.startDate.addingTimeInterval(statistics.endDate.timeIntervalSince(statistics.startDate) / 2)
            let daystamp = Daystamp(fromDate: intervalMidpoint, deadline: deadline)

            // Ignore statistics outside our window
            if daystamp < startDate || daystamp > endDate {
                continue
            }

            let units = try await healthStore.preferredUnits(for: [statistics.quantityType])
            guard let unit = units.first?.value else {
                throw HealthKitError("No preferred units")
            }

            guard let quantityType = HKObjectType.quantityType(forIdentifier: self.hkQuantityTypeIdentifier) else {
                throw HealthKitError("Unable to look up a quantityType")
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

            guard var datapointValue = value else {
                logger.error("updateBeeminderWithStatsCollection(\(self.databaseString, privacy: .public)): No datapoint value")
                continue
            }

            if let unitPrecision = precision[unit] {
                let roundingFactor = pow(10.0, Double(unitPrecision))
                datapointValue = round(datapointValue * roundingFactor) / roundingFactor
            }

            let id = "apple-health-" + daystamp.description
            results.append(NewDataPoint(requestid: id, daystamp: daystamp, value: NSNumber(value: datapointValue), comment: "Auto-entered via Apple Health"))
        }

        return results
    }

}
