//  HealthKitMetric.swift
//  BeeSwift
//
//  Represents a metric which is possible to read from HealthKit

import Foundation
import HealthKit

protocol HealthKitMetric {
    var humanText : String { get }
    var databaseString : String { get }

    func createConnection(healthStore: HKHealthStore, goal: JSONGoal) -> GoalHealthKitConnection
    func sampleType() throws -> HKSampleType
}
