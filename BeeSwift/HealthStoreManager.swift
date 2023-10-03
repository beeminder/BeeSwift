//
//  HealthStoreManager.swift
//  BeeSwift
//
//  Created by Andy Brett on 11/28/17.
//  Copyright © 2017 APB. All rights reserved.
//

import Foundation
import HealthKit
import OSLog

class HealthStoreManager :NSObject {
    private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "HealthStoreManager")

    // TODO: Public for now to use from config
    let healthStore = HKHealthStore()

    /// The Connection objects responsible for updating goals based on their healthkit metrics
    /// Dictionary key is the goal id, as this is stable across goal renames
    private var connections: [String: GoalHealthKitConnection] = [:]

    /// Protect concurrent modifications to the connections dictionary
    private let connectionsSemaphore = DispatchSemaphore(value: 1)

    /// Request acess to HealthKit data for the supplied metric
    ///
    /// This function will throw an exception on a major failure. However, it will return silently if the user chooses
    /// not to grant read access to the specified goal - Apple does not permit apps to know if they have been
    /// granted read permission
    public func requestAuthorization(metric: HealthKitMetric) async throws {
        logger.notice("requestAuthorization for \(metric.databaseString, privacy: .public)")

        try await self.requestAuthorization(read: [metric.sampleType()])
    }

    /// Start listening for background updates to the supplied goal if we are not already doing so
    public func ensureUpdatesRegularly(goal: Goal) async throws {
        try await self.ensureUpdatesRegularly(goals: [goal])
    }

    /// Ensure we have background update listeners for all of the supplied goals such that they
    /// will be updated any time the health data changes.
    ///
    /// It is safe to pass the same goal or set of goals to this function multiple times, this function
    /// will ensure duplicate observers are not installed.
    public func ensureUpdatesRegularly(goals: [Goal]) async throws {
        let goalConnections = goals.compactMap { self.connectionFor(goal:$0) }

        var permissions = Set<HKObjectType>()
        for connection in goalConnections {
            permissions.insert(connection.metric.permissionType())
        }
        if permissions.count > 0 {
            try await self.requestAuthorization(read: permissions)
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for connection in goalConnections {
                group.addTask {
                    try await connection.setupHealthKit()
                }
            }
            try await group.waitForAll()
        }
    }

    /// Install observers for any goals we currently have permission to read
    ///
    /// This function will never show a permissions dialog - instead it will not update for
    /// metrics where we do not have permission.
    public func silentlyInstallObservers(goals: [Goal]) {
        logger.notice("Silently installing observer queries")

        let goalConnections = goals.compactMap { self.connectionFor(goal:$0) }
        for connection in goalConnections {
            connection.registerObserverQuery()
        }
    }

    /// Immediately update the supplied goal based on HealthKit's data record
    ///
    /// Any existing beeminder records for the date range provided will be updated or deleted.
    /// - Parameters:
    ///   - goal: The healthkit-connected goal to be updated
    ///   - days: How many days of history to update. Supplying 1 will update the current day.
    public func updateWithRecentData(goal: Goal, days: Int) async throws {
        logger.notice("Updating \(goal.healthKitMetric ?? "nil", privacy: .public) goal with recent day for last \(days, privacy: .public) days")
        guard let connection = self.connectionFor(goal: goal) else {
            throw HealthKitError("Failed to find connection for goal")
        }
        try await connection.updateWithRecentData(days: days)
    }

    /// Immediately update all known goals based on HealthKit's data record
    public func updateAllGoalsWithRecentData(days: Int) async throws {
        logger.notice("Updating all goals with recent day for last \(days, privacy: .public) days")

        try await withThrowingTaskGroup(of: Void.self) { group in
            for (_, connection) in self.connections {
                group.addTask {
                    try await connection.updateWithRecentData(days: days)
                }
            }
            try await group.waitForAll()
        }
    }

    /// Gets or creates an appropriate connection object for the supplied goal
    private func connectionFor(goal: Goal) -> GoalHealthKitConnection? {
        connectionsSemaphore.wait()

        if (goal.healthKitMetric ?? "") == "" {
            // Goal does not have a metric. Make sure any prior connection is removed
            if let connection = connections[goal.id] {
                connection.unregisterObserverQuery()
                connections.removeValue(forKey: goal.id)
            }
        } else {
            // If a connection exists but is for the wrong metric then remove it
            if let connection = connections[goal.id] {
                if connection.metric.databaseString != goal.healthKitMetric {
                    connection.unregisterObserverQuery()
                    connections.removeValue(forKey: goal.id)
                }
            }

            // If there is no connection (or we just removed it) then create a new one
            if connections[goal.id] == nil {
                logger.notice("Creating connection for \(goal.slug, privacy: .private) (\(goal.id, privacy: .public)) to metric \(goal.healthKitMetric ?? "nil", privacy: .public)")

                if let metric = HealthKitConfig.shared.metrics.first(where: { (metric) -> Bool in
                    metric.databaseString == goal.healthKitMetric
                }) {
                    connections[goal.id] = GoalHealthKitConnection(goal: goal, metric: metric, healthStore: healthStore)
                }
            }
        }

        let connection = connections[goal.id]
        connectionsSemaphore.signal()

        return connection
    }

    private func requestAuthorization(read: Set<HKObjectType>) async throws {
        try await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<Void, Error>) in
            self.healthStore.requestAuthorization(toShare: nil, read: read) { success, error in
                if error != nil {
                    continuation.resume(throwing: error!)
                } else if success == false {
                    continuation.resume(throwing: HealthKitError("Error requesting HealthKit authorization"))
                } else {
                    continuation.resume()
                }
            }
        })
    }

}
