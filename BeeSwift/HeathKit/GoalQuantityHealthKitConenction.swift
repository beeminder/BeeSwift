//  GoalQuantityHealthKitConenction.swift
//  BeeSwift
//
//  Responsible for keeping a goal in sync with a Quantity-based
//  HealthKit goal

import Foundation
import SwiftyJSON
import HealthKit
import OSLog

class GoalQuantityHealthKitConnection : GoalHealthKitConnection {
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

    override func setupQuery() {
        logger.notice("Starting: setupHKStatisticsCollectionQuery for \(self.goal.healthKitMetric ?? "nil", privacy: .public)")

        guard let quantityType = HKObjectType.quantityType(forIdentifier: self.hkQuantityTypeIdentifier) else { return }

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
            self.logger.notice("setupHKStatisticsCollectionQuery(\(self.goal.healthKitMetric ?? "nil", privacy: .public)).initialData: Started")

            self.logger.notice("setupHKStatisticsCollectionQuery.initialData(\(self.goal.healthKitMetric ?? "nil", privacy: .public)): Collection \(collection, privacy: .public)")
            self.logger.notice("setupHKStatisticsCollectionQuery.initialData(\(self.goal.healthKitMetric ?? "nil", privacy: .public)): Error \(error, privacy: .public)")

            guard error == nil else {
                self.logger.error("setupHKStatisticsCollectionQuery.initialData(\(self.goal.healthKitMetric ?? "nil", privacy: .public)): Error in initial results \(error)")
                return
            }

            guard let statsCollection = collection else {
                // Perform proper error handling here
                self.logger.error("setupHKStatisticsCollectionQuery.initialData(\(self.goal.healthKitMetric ?? "nil", privacy: .public)): collection was nil")
                return
            }
            Task(priority: .background) {
                do {
                    try await self.updateBeeminderWithStatsCollection(collection: statsCollection)
                } catch {
                    self.logger.error("setupHKStatisticsCollectionQuery.initialData(\(self.goal.healthKitMetric ?? "nil", privacy: .public)): Error updating beeminder error: \(error)")
                }
            }
            self.logger.notice("setupHKStatisticsCollectionQuery.initialData(\(self.goal.healthKitMetric ?? "nil", privacy: .public)): Done")
        }

        query.statisticsUpdateHandler = {
            query, statistics, collection, error in
            self.logger.notice("statisticsUpdateHandler(\(self.goal.healthKitMetric ?? "nil", privacy: .public)): Start")

            self.logger.notice("statisticsUpdateHandler(\(self.goal.healthKitMetric ?? "nil", privacy: .public)): Statistics \(statistics, privacy: .public)")
            self.logger.notice("statisticsUpdateHandler(\(self.goal.healthKitMetric ?? "nil", privacy: .public)): Collection \(collection, privacy: .public)")
            self.logger.notice("statisticsUpdateHandler(\(self.goal.healthKitMetric ?? "nil", privacy: .public)): Error \(error, privacy: .public)")

            if HKHealthStore.isHealthDataAvailable() {
                guard let statsCollection = collection else {
                    self.logger.error("statisticsUpdateHandler(\(self.goal.healthKitMetric ?? "nil", privacy: .public)): Collection is nil")
                    return
                }

                Task {
                    do {
                        try await self.updateBeeminderWithStatsCollection(collection: statsCollection)
                    } catch {
                        self.logger.error("Error updating beeminder based on statistics update \(query) error: \(error)")
                    }
                }
            } else {
                self.logger.warning("statisticsUpdateHandler(\(self.goal.healthKitMetric ?? "nil", privacy: .public)): Heath Data Not Available")
            }
        }
        healthStore.execute(query)

        logger.notice("Complete: setupHKStatisticsCollectionQuery for \(self.goal.healthKitMetric ?? "nil", privacy: .public)")
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

    internal override func runQuery(dayOffset : Int) async throws {
        logger.notice("Started: runStatsQuery for \(self.goal.healthKitMetric ?? "nil", privacy: .public) offset \(dayOffset)")

        guard let sampleType = self.hkSampleType() else { return }
        let predicate = self.predicateForDayOffset(dayOffset: dayOffset)
        let daystamp = self.dayStampFromDayOffset(dayOffset: dayOffset)

        var options : HKStatisticsOptions
        guard let quantityType = HKObjectType.quantityType(forIdentifier: self.hkQuantityTypeIdentifier) else { return }
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

        guard let quantityType = HKObjectType.quantityType(forIdentifier: self.hkQuantityTypeIdentifier) else {
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
}
