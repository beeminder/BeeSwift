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

    func updateBeeminderWithStatsCollection(collection : HKStatisticsCollection) async throws {
        logger.notice("updateBeeminderWithStatsCollection(\(self.goal.healthKitMetric ?? "nil", privacy: .public)): Started")
        let endDate = Date()
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -5, to: endDate) else {
            logger.error("updateBeeminderWithStatsCollection(\(self.goal.healthKitMetric ?? "nil", privacy: .public)): No startDate")
            return
        }

        let datapoints = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[JSON], Error>) in
            self.goal.fetchRecentDatapoints(success: { datapoints in
                continuation.resume(returning: datapoints)
            }, errorCompletion: {
                continuation.resume(throwing: RuntimeError("Could not fetch recent datapoints"))
            })
        }

        logger.notice("updateBeeminderWithStatsCollection(\(self.goal.healthKitMetric ?? "nil", privacy: .public)): Considering \(collection.statistics().count) points")
        for statistics in collection.statistics() {
            // Ignore statistics which are entirely outside our window
            if statistics.endDate < startDate || statistics.startDate > endDate {
                continue
            }

            logger.notice("updateBeeminderWithStatsCollection(\(self.goal.healthKitMetric ?? "nil", privacy: .public)): Processing data for \(statistics.startDate, privacy: .public)")

            let units = try await healthStore.preferredUnits(for: [statistics.quantityType])
            guard let unit = units.first?.value else {
                logger.error("updateBeeminderWithStatsCollection(\(self.goal.healthKitMetric ?? "nil", privacy: .public)): No preferred units")
                return

            }

            guard let quantityType = HKObjectType.quantityType(forIdentifier: self.hkQuantityTypeIdentifier) else {
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

            guard let datapointValue = value else {
                logger.error("updateBeeminderWithStatsCollection(\(self.goal.healthKitMetric ?? "nil", privacy: .public)): No datapoint value")
                return
            }

            logger.notice("updateBeeminderWithStatsCollection(\(self.goal.healthKitMetric ?? "nil", privacy: .public)): \(statistics.startDate, privacy: .public) value is \(datapointValue, privacy: .public)")

            let startDate = statistics.startDate
            let endDate = statistics.endDate

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd"
            let datapointDate = self.goal.deadline.intValue >= 0 ? startDate : endDate
            let daystamp = formatter.string(from: datapointDate)

            try await self.updateBeeminderWithValue(datapointValue: datapointValue, daystamp: daystamp, recentDatapoints: datapoints)
        }
        logger.notice("updateBeeminderWithStatsCollection(\(self.goal.healthKitMetric ?? "nil", privacy: .public)): Completed")
    }

    internal override func hkQueryForLast(days : Int) async throws {
        logger.notice("Started: runStatsQuery for \(self.goal.healthKitMetric ?? "nil", privacy: .public) days \(days)")

        guard let sampleType = self.hkSampleType() else { return }

        var options : HKStatisticsOptions
        guard let quantityType = HKObjectType.quantityType(forIdentifier: self.hkQuantityTypeIdentifier) else { return }
        if quantityType.aggregationStyle == .cumulative {
            options = .cumulativeSum
        } else {
            options = .discreteMin
        }
        let units = try await healthStore.preferredUnits(for: [quantityType])

        for dayOffset in ((-1*days + 1)...0) {
            let predicate = self.predicateForDayOffset(dayOffset: dayOffset)
            let daystamp = self.dayStampFromDayOffset(dayOffset: dayOffset)

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

            var datapointValue : Double?
            guard let unit = units.first?.value else { return }

            if quantityType.aggregationStyle == .cumulative {
                let quantity = statistics.sumQuantity()
                datapointValue = quantity?.doubleValue(for: unit)
            } else if quantityType.aggregationStyle == .discreteArithmetic {
                let quantity = statistics.minimumQuantity()
                datapointValue = quantity?.doubleValue(for: unit)
            }

            if datapointValue == nil || datapointValue == 0  { return }

            try await self.updateBeeminderWithValue(datapointValue: datapointValue!, daystamp: daystamp)
        }

        logger.notice("Complete: runStatsQuery for \(self.goal.healthKitMetric ?? "nil", privacy: .public)")
    }
}
