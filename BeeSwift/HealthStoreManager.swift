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
    static let sharedManager = HealthStoreManager()
    let logger = Logger(subsystem: "com.beeminder.beeminder", category: "HealthStoreManager")

    private var healthStore : HKHealthStore?

    /// The Connection objects responsible for updating goals based on their healthkit metrics
    /// Dictionary key is the goal id, as this is stable across goal renames
    private var connections: [String: GoalHealthKitConnection] = [:]
    
    private func ensureHealthStoreCreated() {
        self.healthStore = HKHealthStore()
    }

    /// Gets or creates an appropriate connection object for the supplied goal
    private func connectionFor(goal: JSONGoal) -> GoalHealthKitConnection? {
        if goal.healthKitMetric == "" {
            // Goal does not have a metric. Make sure any connection is removed
            connections.removeValue(forKey: goal.id)
            return nil
        } else {
            if connections[goal.id] == nil {
                connections[goal.id] = GoalHealthKitConnection(healthStore: healthStore!, goal: goal)
            }
            return connections[goal.id]
        }
    }

    private func requestAuthorization(read: Set<HKObjectType>) async throws {
        // TODO: This should share code with GoalHealthKitConnection
        // NOTE: Can be neater when we target iOS15
        try await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<Void, Error>) in
            self.healthStore!.requestAuthorization(toShare: nil, read: read) { success, error in
                if error != nil {
                    continuation.resume(throwing: error!)
                } else if success == false {
                    continuation.resume(throwing: RuntimeError("Error requesting HealthKit authorization"))
                } else {
                    continuation.resume()
                }
            }
        })
    }

    func requestAuthorization(metric: HealthKitMetric) async throws {
        ensureHealthStoreCreated()

        var sampleType: HKSampleType?
        if metric.hkIdentifier != nil {
            sampleType = HKObjectType.quantityType(forIdentifier: metric.hkIdentifier!)!
        } else if metric.hkCategoryTypeIdentifier != nil {
            sampleType = HKObjectType.categoryType(forIdentifier: metric.hkCategoryTypeIdentifier!)
        } else {
            throw RuntimeError("No identifier or category for metric \(metric)")
        }

        try await self.requestAuthorization(read: [sampleType!])
    }

    func setupHealthKitGoal(goal: JSONGoal) async throws {
        try await self.setupHealthKitGoals(goals: [goal])
    }

    func setupHealthKitGoals(goals: [JSONGoal]) async throws {
        ensureHealthStoreCreated();
        let goalConnections = goals.compactMap { self.connectionFor(goal:$0) }

        var permissions = Set<HKObjectType>()
        for connection in goalConnections {
            if let permissionType = connection.hkPermissionType() {
               permissions.insert(permissionType)
            }
        }
        if permissions.count > 0 {
            try await self.requestAuthorization(read: permissions)
        }

        // TODO: Where do exceptions go?
        await withThrowingTaskGroup(of: Void.self) { group in
            for connection in goalConnections {
                group.addTask {
                    // TODO: This could do terrible things around repeated auth requests
                    try await connection.setupHealthKit()
                }
            }
        }
    }

    func registerObserverQueries(goals: [JSONGoal]) {
        ensureHealthStoreCreated()
        let goalConnections = goals.compactMap { self.connectionFor(goal:$0) }
        for connection in goalConnections {
            connection.registerObserverQuery()
        }
    }

    func syncHealthKitData(goal: JSONGoal, days: Int) async throws {
        ensureHealthStoreCreated();
        guard let connection = self.connectionFor(goal: goal) else {
            throw RuntimeError("Failed to find connection for goal")
        }
        try await connection.hkQueryForLast(days: days)
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
