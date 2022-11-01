//  QuantityHealthKitMetric.swift
//  BeeSwift
//
//  A HealthKit metric which represented by `HKQuantitySample`s and can use the
//  HealthKit aggregation API

import Foundation
import HealthKit

struct QuantityHealthKitMetric : HealthKitMetric {
    let humanText : String
    let databaseString : String
    let hkIdentifier : HKQuantityTypeIdentifier

    func createConnection(healthStore: HKHealthStore, goal: JSONGoal) -> GoalHealthKitConnection {
        return GoalQuantityHealthKitConnection(healthStore: healthStore, goal: goal, hkQuantityTypeIdentifier: hkIdentifier)
    }

    func sampleType() throws -> HKSampleType {
        return HKObjectType.quantityType(forIdentifier: hkIdentifier)!
    }
}
