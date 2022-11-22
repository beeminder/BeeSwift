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
    private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "GoalHealthKitConnection")
    private let healthStore: HKHealthStore
    private let goal : Goal
    private var observerQuery : HKObserverQuery? = nil

    public let metric : HealthKitMetric

    init(goal: Goal, metric : HealthKitMetric, healthStore: HKHealthStore) {
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

            Task {
                do {
                    try await self.updateWithRecentData(days: 1)
                    completionHandler()
                } catch {
                    self.logger.error("Error fetching data in response to observer query \(query) error: \(error)")
                }
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
        let newDataPoints = try await metric.recentDataPoints(days: days, deadline: self.goal.deadline.intValue, healthStore: healthStore)
        let nonZeroDataPoints =  newDataPoints.filter { (_, value: Double, _) in value != 0 }
        try await goal.updateToMatchDataPoints(healthKitDataPoints: nonZeroDataPoints)
    }

}
