//  GoalQuantityHealthKitConenction.swift
//  BeeSwift
//
//  Responsible for keeping a goal in sync with a Quantity-based
//  HealthKit goal

import Foundation
import SwiftyJSON
import HealthKit
import OSLog



class GoalQuantityHealthKitConnection : BaseGoalHealthKitConnection {
    private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "GoalQuantityHealthKitConnection")

    let hkQuantityTypeIdentifier: HKQuantityTypeIdentifier

    init(healthStore: HKHealthStore, goal: JSONGoal, hkQuantityTypeIdentifier: HKQuantityTypeIdentifier) {
        self.hkQuantityTypeIdentifier = hkQuantityTypeIdentifier
        super.init(healthStore: healthStore, goal: goal)
    }

    override func hkSampleType() -> HKSampleType? {
        return HKObjectType.quantityType(forIdentifier: self.hkQuantityTypeIdentifier)
    }

    override func hkPermissionType() -> HKObjectType? {
        return HKObjectType.quantityType(forIdentifier: self.hkQuantityTypeIdentifier)
    }

    override func hkQueryForLast(days : Int) async throws {
        let newDataPoints = try await recentDataPoints(days: days)
        try await updateBeeminderToMatchDataPoints(healthKitDataPoints: newDataPoints)

        logger.notice("Complete: runStatsQuery for \(self.goal.healthKitMetric ?? "nil", privacy: .public)")
    }

    private func recentDataPoints(days : Int) async throws -> [DataPoint] {
        logger.notice("Started: runStatsQuery for \(self.goal.healthKitMetric ?? "nil", privacy: .public) days \(days)")

        guard let quantityType = HKObjectType.quantityType(forIdentifier: self.hkQuantityTypeIdentifier) else {
            throw RuntimeError("Unable to look up a quantityType")
        }
        let predicate = self.predicateForLast(days: days)
        let options : HKStatisticsOptions = quantityType.aggregationStyle == .cumulative ? .cumulativeSum : .discreteMin

        let statsCollection = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKStatisticsCollection, Error>) in
            let query = HKStatisticsCollectionQuery(quantityType: quantityType,
                                                    quantitySamplePredicate: predicate,
                                                    options: options,
                                                    anchorDate: anchorDate(),
                                                    intervalComponents: DateComponents(day:1))
            query.initialResultsHandler = {
                query, collection, error in
                if error != nil {
                    continuation.resume(throwing: error!)
                } else if collection == nil {
                    continuation.resume(throwing: RuntimeError("HKStatisticsCollectionQuery returned a nil collection"))
                } else {
                    continuation.resume(returning: collection!)
                }
            }
            healthStore.execute(query)
        }

        // TODO: This should maybe have a timezone filter?
        return try await datapointsForCollection(collection: statsCollection)
    }

    private func predicateForLast(days : Int) -> NSPredicate? {
        let startTime = goalAwareStartOfDay(daysAgo: days)
        return HKQuery.predicateForSamples(withStart: startTime, end: nil)
    }

    private func goalAwareStartOfDay(daysAgo : Int) -> Date {
        let calendar = Calendar.current

        let components = calendar.dateComponents(in: TimeZone.current, from: Date())
        let localMidnightThisMorning = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: calendar.date(from: components)!)

        let startOfToday = calendar.date(byAdding: .second, value: self.goal.deadline.intValue, to: localMidnightThisMorning!)

        return calendar.date(byAdding: .day, value: -daysAgo, to: startOfToday!)!
    }

    private func anchorDate() -> Date {
        let calendar = Calendar.current
        var anchorComponents = calendar.dateComponents([.day, .month, .year, .weekday], from: Date())

        // TODO: This will use the local timezone instead of the goal timezone which causes a number of bugs
        anchorComponents.hour = 0
        anchorComponents.minute = 0
        anchorComponents.second = 0

        guard let midnight = calendar.date(from: anchorComponents) else {
            fatalError("*** unable to create a valid date from the given components ***")
        }
        return calendar.date(byAdding: .second, value: self.goal.deadline.intValue, to: midnight)!
    }

    private func datapointsForCollection(collection : HKStatisticsCollection) async throws -> [DataPoint] {
        logger.notice("updateBeeminderWithStatsCollection(\(self.goal.healthKitMetric ?? "nil", privacy: .public)): Started")

        // TODO: These should be paseed in
        let endDate = Date()
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -5, to: endDate) else {
            throw RuntimeError("Cannot find calculate start date")
        }

        logger.notice("updateBeeminderWithStatsCollection(\(self.goal.healthKitMetric ?? "nil", privacy: .public)): Considering \(collection.statistics().count) points")

        var results : [DataPoint] = []

        for statistics in collection.statistics() {
            // Ignore statistics which are entirely outside our window
            if statistics.endDate < startDate || statistics.startDate > endDate {
                continue
            }

            logger.notice("updateBeeminderWithStatsCollection(\(self.goal.healthKitMetric ?? "nil", privacy: .public)): Processing data for \(statistics.startDate, privacy: .public)")

            let units = try await healthStore.preferredUnits(for: [statistics.quantityType])
            guard let unit = units.first?.value else {
                throw RuntimeError("No preferred units")
            }

            guard let quantityType = HKObjectType.quantityType(forIdentifier: self.hkQuantityTypeIdentifier) else {
                throw RuntimeError("Unable to look up a quantityType")
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
                logger.error("updateBeeminderWithStatsCollection(\(self.goal.healthKitMetric ?? "nil", privacy: .public)): No datapoint value")
                continue
            }

            logger.notice("updateBeeminderWithStatsCollection(\(self.goal.healthKitMetric ?? "nil", privacy: .public)): \(statistics.startDate, privacy: .public) value is \(datapointValue, privacy: .public)")

            let startDate = statistics.startDate
            let endDate = statistics.endDate

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd"
            let datapointDate = self.goal.deadline.intValue >= 0 ? startDate : endDate
            let daystamp = formatter.string(from: datapointDate)

            results.append((daystamp: daystamp, value: datapointValue, comment: "Auto-entered via Apple Health"))
        }
        logger.notice("updateBeeminderWithStatsCollection(\(self.goal.healthKitMetric ?? "nil", privacy: .public)): Completed")

        return results
    }

}
