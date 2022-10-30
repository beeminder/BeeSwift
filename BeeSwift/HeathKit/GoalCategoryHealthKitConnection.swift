//  GoalCategoryHealthKitConenction.swift
//  BeeSwift
//
//  Responsible for keeping a goal in sync with a Category-based
//  HealthKit goal


import Foundation
import HealthKit

class GoalCategoryHealthKitConnection : GoalHealthKitConnection {
    init(healthStore: HKHealthStore, goal: JSONGoal, hkCategoryTypeIdentifier: HKCategoryTypeIdentifier) {
        super.init(healthStore: healthStore, goal: goal, hkQuantityTypeIdentifier: nil, hkCategoryTypeIdentifier: hkCategoryTypeIdentifier)
    }
}
