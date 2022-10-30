//
//  HealthKitConfig.swift
//  BeeSwift
//
//  Created by Andy Brett on 3/25/17.
//  Copyright © 2017 APB. All rights reserved.
//

import Foundation
import HealthKit

protocol HealthKitMetric {
    var humanText : String { get }
    var databaseString : String { get }

    func createConnection(healthStore: HKHealthStore, goal: JSONGoal) -> GoalHealthKitConnection
    func sampleType() throws -> HKSampleType
}

struct QuantityHealthKitMetric : HealthKitMetric {
    let humanText : String
    let databaseString : String
    fileprivate let hkIdentifier : HKQuantityTypeIdentifier

    func createConnection(healthStore: HKHealthStore, goal: JSONGoal) -> GoalHealthKitConnection {
        return GoalQuantityHealthKitConnection(healthStore: healthStore, goal: goal, hkQuantityTypeIdentifier: hkIdentifier)
    }

    func sampleType() throws -> HKSampleType {
        return HKObjectType.quantityType(forIdentifier: hkIdentifier)!
    }
}

struct CategoryHealthKitMetric : HealthKitMetric {
    let humanText : String
    let databaseString : String
    fileprivate let hkCategoryTypeIdentifier : HKCategoryTypeIdentifier

    func createConnection(healthStore: HKHealthStore, goal: JSONGoal) -> GoalHealthKitConnection {
        return GoalCategoryHealthKitConnection(healthStore: healthStore, goal: goal, hkCategoryTypeIdentifier: hkCategoryTypeIdentifier)
    }

    func sampleType() throws -> HKSampleType {
        return HKObjectType.categoryType(forIdentifier: hkCategoryTypeIdentifier)!
    }
}

class HealthKitConfig : NSObject {
    static let shared = HealthKitConfig()
    
    var metrics : [HealthKitMetric] {
        return [
            QuantityHealthKitMetric.init(humanText: "Steps", databaseString: "steps", hkIdentifier: HKQuantityTypeIdentifier.stepCount),
            QuantityHealthKitMetric.init(humanText: "Active energy", databaseString: "activeEnergy", hkIdentifier: HKQuantityTypeIdentifier.activeEnergyBurned),
            QuantityHealthKitMetric.init(humanText: "Exercise time", databaseString: "exerciseTime", hkIdentifier: HKQuantityTypeIdentifier.appleExerciseTime),
            QuantityHealthKitMetric.init(humanText: "Weight", databaseString: "weight", hkIdentifier: HKQuantityTypeIdentifier.bodyMass),
            QuantityHealthKitMetric.init(humanText: "Cycling distance", databaseString: "cyclingDistance", hkIdentifier: HKQuantityTypeIdentifier.distanceCycling),
            QuantityHealthKitMetric.init(humanText: "Walking/running distance", databaseString: "walkRunDistance", hkIdentifier: HKQuantityTypeIdentifier.distanceWalkingRunning),
            QuantityHealthKitMetric.init(humanText: "Nike Fuel", databaseString: "nikeFuel", hkIdentifier: HKQuantityTypeIdentifier.nikeFuel),
            QuantityHealthKitMetric.init(humanText: "Water", databaseString: "water", hkIdentifier: HKQuantityTypeIdentifier.dietaryWater),
            CategoryHealthKitMetric.init(humanText: "Time in bed", databaseString: "timeInBed", hkCategoryTypeIdentifier: HKCategoryTypeIdentifier.sleepAnalysis),
            CategoryHealthKitMetric.init(humanText: "Time asleep", databaseString: "timeAsleep", hkCategoryTypeIdentifier: HKCategoryTypeIdentifier.sleepAnalysis),
//            CategoryHealthKitMetric.init(humanText: "Stand hours", databaseString: "standHour", hkCategoryTypeIdentifier: HKCategoryTypeIdentifier.appleStandHour),
            QuantityHealthKitMetric.init(humanText: "Resting energy", databaseString: "basalEnergy", hkIdentifier: HKQuantityTypeIdentifier.basalEnergyBurned),
            QuantityHealthKitMetric.init(humanText: "Dietary energy", databaseString: "dietaryEnergy", hkIdentifier: HKQuantityTypeIdentifier.dietaryEnergyConsumed),
            QuantityHealthKitMetric.init(humanText: "Dietary protein", databaseString: "dietaryProtein", hkIdentifier: HKQuantityTypeIdentifier.dietaryProtein),
            QuantityHealthKitMetric.init(humanText: "Dietary sugar", databaseString: "dietarySugar", hkIdentifier: HKQuantityTypeIdentifier.dietarySugar),
            QuantityHealthKitMetric.init(humanText: "Dietary carbs", databaseString: "dietaryCarbs", hkIdentifier: HKQuantityTypeIdentifier.dietaryCarbohydrates),
            QuantityHealthKitMetric.init(humanText: "Dietary fat", databaseString: "dietaryFat", hkIdentifier: HKQuantityTypeIdentifier.dietaryFatTotal),
            QuantityHealthKitMetric.init(humanText: "Dietary saturated fat", databaseString: "dietarySaturatedFat", hkIdentifier: HKQuantityTypeIdentifier.dietaryFatSaturated),
            QuantityHealthKitMetric.init(humanText: "Dietary sodium", databaseString: "dietarySodium", hkIdentifier: HKQuantityTypeIdentifier.dietarySodium),
            QuantityHealthKitMetric.init(humanText: "Swimming strokes", databaseString: "swimStrokes", hkIdentifier: HKQuantityTypeIdentifier.swimmingStrokeCount),
            QuantityHealthKitMetric.init(humanText: "Swimming distance", databaseString: "swimDistance", hkIdentifier: HKQuantityTypeIdentifier.distanceSwimming),
            CategoryHealthKitMetric.init(humanText: "Mindful minutes", databaseString: "mindfulMinutes", hkCategoryTypeIdentifier: HKCategoryTypeIdentifier.mindfulSession)
        ]
    }
}
