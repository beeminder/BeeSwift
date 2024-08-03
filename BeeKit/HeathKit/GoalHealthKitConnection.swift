//
//  GoalHealthKitConnection.swift
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
    /// The number of days to update when we are informed of a change. We are only called when the device is unlocked, so we must look
    /// at the previous day in case data was added after the last time the device was locked. There may also be other integrations which report
    /// data with some lag, so we look a bit further back for safety
    /// This does mean users who have very little buffer, and are not regularly unlocking their phone, may erroneously derail. There is nothing we
    /// can do about this.
    static let daysToUpdateOnChangeNotification = 7

    private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "GoalHealthKitConnection")

    private let goal : Goal
    public let metric : HealthKitMetric
    private let healthStore: HKHealthStore

    private var monitor : HealthKitMetricMonitor!

    init(goal: Goal, metric : HealthKitMetric, healthStore: HKHealthStore) {
        // TODO: We can't store this goal object because of context
        self.goal = goal
        self.metric = metric
        self.healthStore = healthStore
        self.monitor = HealthKitMetricMonitor(healthStore: healthStore, metric: metric, onUpdate: { [weak self] metric in
            await self?.updateWithRecentData(days: 7)
        })
    }

    /// Perform an initial sync and register for changes to the relevant metric so the goal can be kept up to date
    public func setupHealthKit() async throws {
        try await self.monitor.setupHealthKit()
    }

    /// Register for changes to the relevant metric. Assumes permission and background delivery already enabled
    public func registerObserverQuery() {
        self.monitor.registerObserverQuery()
    }

    /// Remove any registered queries to prevent further updates
    public func unregisterObserverQuery() {
        self.monitor.unregisterObserverQuery()
    }

    /// Explicitly sync goal data for the number of days specified
    public func updateWithRecentData(days : Int) async {
        do {
            let newDataPoints = try await metric.recentDataPoints(days: days, deadline: self.goal.deadline, healthStore: healthStore)
            let nonZeroDataPoints = newDataPoints.filter { dataPoint in dataPoint.value != 0 }
            logger.notice("Updating \(self.metric.databaseString, privacy: .public) goal with \(nonZeroDataPoints.count, privacy: .public) datapoints. Skipped \(newDataPoints.count - nonZeroDataPoints.count, privacy: .public) empty points.")
            try await ServiceLocator.dataPointManager.updateToMatchDataPoints(goal: goal, healthKitDataPoints: nonZeroDataPoints)
        } catch {
            logger.error("Error fetching data and updating goal for \(self.metric.databaseString, privacy: .public): \(error, privacy: .public)")
        }
    }
}
