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
    static let minimumIntervalBetweenObserverUpdates : TimeInterval = 5 // Seconds

    private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "GoalHealthKitConnection")
    private let healthStore: HKHealthStore
    private let goal : BeeGoal
    private var observerQuery : HKObserverQuery? = nil
    private var lastObserverUpdate : Date? = nil

    public let metric : HealthKitMetric

    init(goal: BeeGoal, metric : HealthKitMetric, healthStore: HKHealthStore) {
        self.goal = goal
        self.metric = metric
        self.healthStore = healthStore
    }

    /// Perform an initial sync and register for changes to the relevant metric so the goal can be kept up to date
    public func setupHealthKit() async throws {
        try await healthStore.enableBackgroundDelivery(for: metric.sampleType(), frequency: HKUpdateFrequency.immediate)
        registerObserverQuery()
    }

    /// Register for changes to the relevant metric. Assumes permission and background delivery already enabled
    public func registerObserverQuery() {
        guard observerQuery == nil else {
            return
        }
        logger.notice("Registering observer query for \(self.goal.healthKitMetric ?? "nil", privacy: .public)")

        let query = HKObserverQuery(sampleType: metric.sampleType(), predicate: nil, updateHandler: { (query, completionHandler, error) in
            self.logger.notice("ObserverQuery response for \(self.goal.healthKitMetric ?? "nil", privacy: .public)")

            guard error == nil else {
                self.logger.error("ObserverQuery for \(self.goal.healthKitMetric ?? "nil", privacy: .public) was error: \(error, privacy: .public)")
                return
            }

            if let lastUpdate = self.lastObserverUpdate {
                if Date().timeIntervalSince(lastUpdate) < GoalHealthKitConnection.minimumIntervalBetweenObserverUpdates {
                    self.logger.notice("Ignoring update to \(self.goal.healthKitMetric ?? "nil", privacy: .public) due to recent previous update")
                    completionHandler()
                    return
                }
            }
            self.lastObserverUpdate = Date()

            Task {
                do {
                    try await self.updateWithRecentData(days: GoalHealthKitConnection.daysToUpdateOnChangeNotification)
                } catch {
                    self.logger.error("Error fetching data in response to observer query \(query) error: \(error)")
                }

                // Report completion even on failure. It would be nice to have the iOS retry mechanism call us again
                // on failure, but in pratice iOS waits a long time, leading to higher background usage.
                completionHandler()
            }
        })
        healthStore.execute(query)

        // Once we have successfully executed the query then keep track of it to stop later
        self.observerQuery = query
    }

    /// Remove any registered queries to prevent further updates
    public func unregisterObserverQuery() {
        guard let query = self.observerQuery else {
            logger.warning("unregisterObserverQuery(\(self.goal.healthKitMetric ?? "nil", privacy: .public)): Attempted to unregister query when not registered")
            return
        }
        logger.notice("Unregistering observer query for \(self.goal.healthKitMetric ?? "nil", privacy: .public)")

        healthStore.stop(query)
    }

    /// Explicitly sync goal data for the number of days specified
    public func updateWithRecentData(days : Int) async throws {
        let newDataPoints = try await metric.recentDataPoints(days: days, deadline: self.goal.deadline, healthStore: healthStore)
        let nonZeroDataPoints = newDataPoints.filter { dataPoint in dataPoint.value != 0 }
        logger.notice("Updating \(self.metric.databaseString, privacy: .public) goal with \(nonZeroDataPoints.count, privacy: .public) datapoints. Skipped \(newDataPoints.count - nonZeroDataPoints.count, privacy: .public) empty points.")
        try await ServiceLocator.dataPointManager.updateToMatchDataPoints(goal: goal, healthKitDataPoints: nonZeroDataPoints)
    }

}
