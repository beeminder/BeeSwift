//
//  HealthStoreManager.swift
//  BeeSwift
//
//  Created by Andy Brett on 11/28/17.
//  Copyright © 2017 APB. All rights reserved.
//

import Foundation
import HealthKit

class HealthStoreManager :NSObject {
    static let sharedManager = HealthStoreManager()

    var healthStore : HKHealthStore?

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
            return connections[goal.id] ?? GoalHealthKitConnection(goal: goal)
        }
    }

    func requestAuthorization(goals: [JSONGoal], completion: @escaping (Bool, Error?) -> Void) {
        ensureHealthStoreCreated();
        let goalConnections = goals.map { self.connectionFor(goal:$0) }.compactMap { $0 }

        var permissions = Set<HKObjectType>.init()
        goalConnections.forEach { (connection) in
            if let permissionType = connection.hkPermissionType() {
               permissions.insert(permissionType)
            }
        }
        guard permissions.count > 0 else { return }

        guard let healthStore = HealthStoreManager.sharedManager.healthStore else { return }
        healthStore.requestAuthorization(toShare: nil, read: permissions, completion: completion)
    }

    func setupHealthKitGoals(goals: [JSONGoal]) {
        ensureHealthStoreCreated();
        let goalConnections = goals.map { self.connectionFor(goal:$0) }.compactMap { $0 }
        goalConnections.forEach { (connection) in
            connection.setupHealthKit()
        }
    }

    func setupHealthKitGoal(goal: JSONGoal) {
        ensureHealthStoreCreated();
        if let connection = self.connectionFor(goal: goal) {
            connection.setupHealthKit()
        }
    }

    func syncHealthKitData(goal: JSONGoal, days: Int, success: (() -> ())?, errorCompletion: (() -> ())?) {
        ensureHealthStoreCreated();
        if let connection = self.connectionFor(goal: goal) {
            connection.hkQueryForLast(days: days, success: success, errorCompletion: errorCompletion)
        } else {
            errorCompletion?()
        }
    }
}
