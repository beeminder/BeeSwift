//  CategoryHealthKitMetric.swift
//  BeeSwift
//
//  A HealthKit metric represented by `HkCategorySample`s and must be manually
//  converted to metrics by the app

import Foundation
import HealthKit

struct CategoryHealthKitMetric : HealthKitMetric {
    let humanText : String
    let databaseString : String
    let hkCategoryTypeIdentifier : HKCategoryTypeIdentifier

    func createConnection(healthStore: HKHealthStore, goal: JSONGoal) -> GoalHealthKitConnection {
        return GoalCategoryHealthKitConnection(healthStore: healthStore, goal: goal, hkCategoryTypeIdentifier: hkCategoryTypeIdentifier)
    }

    func sampleType() throws -> HKSampleType {
        return HKObjectType.categoryType(forIdentifier: hkCategoryTypeIdentifier)!
    }
}
