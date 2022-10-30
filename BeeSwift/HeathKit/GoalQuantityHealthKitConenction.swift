//  GoalQuantityHealthKitConenction.swift
//  BeeSwift
//
//  Responsible for keeping a goal in sync with a Quantity-based
//  HealthKit goal

import Foundation
import HealthKit

class GoalQuantityHealthKitConnection : GoalHealthKitConnection {
    init(healthStore: HKHealthStore, goal: JSONGoal, hkQuantityTypeIdentifier: HKQuantityTypeIdentifier) {
        super.init(healthStore: healthStore, goal: goal, hkQuantityTypeIdentifier: hkQuantityTypeIdentifier, hkCategoryTypeIdentifier: nil)
    }
}
