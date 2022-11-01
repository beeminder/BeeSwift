//
//  HealthKitConfig.swift
//  BeeSwift
//
//  Created by Andy Brett on 3/25/17.
//  Copyright © 2017 APB. All rights reserved.
//

import Foundation
import HealthKit

class HealthKitConfig : NSObject {
    static let shared = HealthKitConfig()
    
    var metrics : [HealthKitMetric] {
        return [
            QuantityHealthKitMetric.init(humanText: "Steps", databaseString: "steps", hkQuantityTypeIdentifier: HKQuantityTypeIdentifier.stepCount),
            QuantityHealthKitMetric.init(humanText: "Active energy", databaseString: "activeEnergy", hkQuantityTypeIdentifier: HKQuantityTypeIdentifier.activeEnergyBurned),
            QuantityHealthKitMetric.init(humanText: "Exercise time", databaseString: "exerciseTime", hkQuantityTypeIdentifier: HKQuantityTypeIdentifier.appleExerciseTime),
            QuantityHealthKitMetric.init(humanText: "Weight", databaseString: "weight", hkQuantityTypeIdentifier: HKQuantityTypeIdentifier.bodyMass),
            QuantityHealthKitMetric.init(humanText: "Cycling distance", databaseString: "cyclingDistance", hkQuantityTypeIdentifier: HKQuantityTypeIdentifier.distanceCycling),
            QuantityHealthKitMetric.init(humanText: "Walking/running distance", databaseString: "walkRunDistance", hkQuantityTypeIdentifier: HKQuantityTypeIdentifier.distanceWalkingRunning),
            QuantityHealthKitMetric.init(humanText: "Nike Fuel", databaseString: "nikeFuel", hkQuantityTypeIdentifier: HKQuantityTypeIdentifier.nikeFuel),
            QuantityHealthKitMetric.init(humanText: "Water", databaseString: "water", hkQuantityTypeIdentifier: HKQuantityTypeIdentifier.dietaryWater),
            CategoryHealthKitMetric.init(humanText: "Time in bed", databaseString: "timeInBed", hkCategoryTypeIdentifier: HKCategoryTypeIdentifier.sleepAnalysis),
            CategoryHealthKitMetric.init(humanText: "Time asleep", databaseString: "timeAsleep", hkCategoryTypeIdentifier: HKCategoryTypeIdentifier.sleepAnalysis),
//            CategoryHealthKitMetric.init(humanText: "Stand hours", databaseString: "standHour", hkCategoryTypeIdentifier: HKCategoryTypeIdentifier.appleStandHour),
            QuantityHealthKitMetric.init(humanText: "Resting energy", databaseString: "basalEnergy", hkQuantityTypeIdentifier: HKQuantityTypeIdentifier.basalEnergyBurned),
            QuantityHealthKitMetric.init(humanText: "Dietary energy", databaseString: "dietaryEnergy", hkQuantityTypeIdentifier: HKQuantityTypeIdentifier.dietaryEnergyConsumed),
            QuantityHealthKitMetric.init(humanText: "Dietary protein", databaseString: "dietaryProtein", hkQuantityTypeIdentifier: HKQuantityTypeIdentifier.dietaryProtein),
            QuantityHealthKitMetric.init(humanText: "Dietary sugar", databaseString: "dietarySugar", hkQuantityTypeIdentifier: HKQuantityTypeIdentifier.dietarySugar),
            QuantityHealthKitMetric.init(humanText: "Dietary carbs", databaseString: "dietaryCarbs", hkQuantityTypeIdentifier: HKQuantityTypeIdentifier.dietaryCarbohydrates),
            QuantityHealthKitMetric.init(humanText: "Dietary fat", databaseString: "dietaryFat", hkQuantityTypeIdentifier: HKQuantityTypeIdentifier.dietaryFatTotal),
            QuantityHealthKitMetric.init(humanText: "Dietary saturated fat", databaseString: "dietarySaturatedFat", hkQuantityTypeIdentifier: HKQuantityTypeIdentifier.dietaryFatSaturated),
            QuantityHealthKitMetric.init(humanText: "Dietary sodium", databaseString: "dietarySodium", hkQuantityTypeIdentifier: HKQuantityTypeIdentifier.dietarySodium),
            QuantityHealthKitMetric.init(humanText: "Swimming strokes", databaseString: "swimStrokes", hkQuantityTypeIdentifier: HKQuantityTypeIdentifier.swimmingStrokeCount),
            QuantityHealthKitMetric.init(humanText: "Swimming distance", databaseString: "swimDistance", hkQuantityTypeIdentifier: HKQuantityTypeIdentifier.distanceSwimming),
            MindfulSessionHealthKitMetric.init(humanText: "Mindful minutes", databaseString: "mindfulMinutes", hkCategoryTypeIdentifier: HKCategoryTypeIdentifier.mindfulSession)
        ]
    }
}
