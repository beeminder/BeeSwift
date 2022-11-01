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

class BaseGoalHealthKitConnection : GoalHealthKitConnection {
    private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "GoalHealthKitConnection")
    let healthStore: HKHealthStore
    let goal : JSONGoal

    var haveRegisteredObserverQuery = false

    init(healthStore: HKHealthStore, goal: JSONGoal) {
        self.healthStore = healthStore
        self.goal = goal
    }

    internal func recentDataPoints(days : Int) async throws -> [DataPoint] {
        preconditionFailure("This method must be overridden")
    }

    internal func hkSampleType() -> HKSampleType {
        preconditionFailure("This method must be overridden")
    }

    func hkPermissionType() -> HKObjectType {
        preconditionFailure("This method must be overridden")
    }

    func hkQueryForLast(days : Int) async throws {
        let newDataPoints = try await recentDataPoints(days: days)
        let nonZeroDataPoints =  newDataPoints.filter { (_, value: Double, _) in value != 0 }
        try await goal.updateToMatchDataPoints(healthKitDataPoints: nonZeroDataPoints)

        logger.notice("Complete: runStatsQuery for \(self.goal.healthKitMetric ?? "nil", privacy: .public)")
    }

    func setupHealthKit() async throws {
        try await healthStore.enableBackgroundDelivery(for: hkSampleType(), frequency: HKUpdateFrequency.immediate)
        registerObserverQuery()
    }

    func registerObserverQuery() {
        logger.notice("registerObserverQuery(\(self.goal.healthKitMetric ?? "nil", privacy: .public)): requested")

        if haveRegisteredObserverQuery {
            logger.notice("registerObserverQuery(\(self.goal.healthKitMetric ?? "nil", privacy: .public)): skipping because done before")
            return
        }

        let query = HKObserverQuery(sampleType: hkSampleType(), predicate: nil, updateHandler: { (query, completionHandler, error) in
            self.logger.notice("ObserverQuery for \(self.goal.healthKitMetric ?? "nil", privacy: .public) received update query \(query, privacy: .public) error \(error, privacy: .public)")
            Task {
                do {
                    try await self.hkQueryForLast(days: 1)
                    completionHandler()
                } catch {
                    self.logger.error("Error fetching data in response to observer query \(query) error: \(error)")
                }
            }
        })
        healthStore.execute(query)

        haveRegisteredObserverQuery = true

        logger.notice("registerObserverQuery(\(self.goal.healthKitMetric ?? "nil", privacy: .public)): done")
    }

}


// TODO: More descriptive error?
struct RuntimeError: Error {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    public var localizedDescription: String {
        return message
    }
}
