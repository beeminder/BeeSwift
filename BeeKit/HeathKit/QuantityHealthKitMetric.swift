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

    internal init(humanText: String, databaseString: String, category : HealthKitCategory, hkQuantityTypeIdentifier: HKQuantityTypeIdentifier) {
        self.humanText = humanText
        self.databaseString = databaseString
        self.category = category
        self.hkQuantityTypeIdentifier = hkQuantityTypeIdentifier
    }

    func sampleType() -> HKSampleType {
        return HKObjectType.quantityType(forIdentifier: hkQuantityTypeIdentifier)!
    }

    func permissionType() -> HKObjectType {
        return HKObjectType.quantityType(forIdentifier: self.hkQuantityTypeIdentifier)!
    }

    func recentDataPoints(days : Int, deadline : Int, healthStore : HKHealthStore) async throws -> [DataPoint] {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: self.hkQuantityTypeIdentifier) else {
            throw HealthKitError("Unable to look up a quantityType")
        }
        let predicate = self.predicateForLast(days: days, deadline: deadline)
        let options : HKStatisticsOptions = quantityType.aggregationStyle == .cumulative ? .cumulativeSum : .discreteMin

        let statsCollection = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKStatisticsCollection, Error>) in
            let query = HKStatisticsCollectionQuery(quantityType: quantityType,
                                                    quantitySamplePredicate: predicate,
                                                    options: options,
                                                    anchorDate: anchorDate(deadline: deadline),
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

        // TODO: It would be possible for Apple to give us more data than requested in the statsCollection, we should consider passing through the number of days to filter here
        return try await datapointsForCollection(collection: statsCollection, days: days, deadline: deadline, healthStore: healthStore)
    }

    func units(healthStore : HKHealthStore) async throws -> HKUnit {
        let quantityType = HKObjectType.quantityType(forIdentifier: hkQuantityTypeIdentifier)!
        let units = try await healthStore.preferredUnits(for: [quantityType])
        guard let unit = units.first?.value else {
            throw HealthKitError("No preferred units")
        }
        return unit
    }

    private func predicateForLast(days : Int, deadline : Int) -> NSPredicate? {
        let startTime = goalAwareStartOfDay(days: days, deadline: deadline)
        return HKQuery.predicateForSamples(withStart: startTime, end: nil)
    }

    private func goalAwareStartOfDay(days : Int, deadline : Int) -> Date {
        let calendar = Calendar.current

        let components = calendar.dateComponents(in: TimeZone.current, from: Date())
        let localMidnightThisMorning = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: calendar.date(from: components)!)

        let startOfToday = calendar.date(byAdding: .second, value: deadline, to: localMidnightThisMorning!)

        let dayOffset = -days + 1 // One day should fetch only today
        return calendar.date(byAdding: .day, value: dayOffset, to: startOfToday!)!
    }

    private func anchorDate(deadline : Int) -> Date {
        // TODO: This will use the device local timezone instead of the user's beeminder timezone
        let calendar = Calendar.current
        var anchorComponents = calendar.dateComponents([.day, .month, .year, .weekday], from: Date())

        anchorComponents.hour = 0
        anchorComponents.minute = 0
        anchorComponents.second = 0

        guard let midnight = calendar.date(from: anchorComponents) else {
            fatalError("*** unable to create a valid date from the given components ***")
        }
        return calendar.date(byAdding: .second, value: deadline, to: midnight)!
    }

    private func datapointsForCollection(collection : HKStatisticsCollection, days: Int, deadline : Int, healthStore: HKHealthStore) async throws -> [DataPoint] {
        let endDate = Date()
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) else {
            throw HealthKitError("Cannot find calculate start date")
        }

        var results : [DataPoint] = []

        for statistics in collection.statistics() {
            let datapointDate = deadline >= 0 ? statistics.startDate : statistics.endDate

            // Ignore statistics outside our window
            if datapointDate < startDate || datapointDate > endDate {
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

            guard let datapointValue = value else {
                logger.error("updateBeeminderWithStatsCollection(\(self.databaseString, privacy: .public)): No datapoint value")
                continue
            }

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd"
            let daystamp = formatter.string(from: datapointDate)

            let id = "apple-health-" + daystamp
            results.append(NewDataPoint(requestid: id, daystamp: daystamp, value: NSNumber(value: datapointValue), comment: "Auto-entered via Apple Health"))
        }

        return results
    }

}
