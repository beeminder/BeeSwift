//
//  HealthKitConfig.swift
//  BeeSwift
//
//  Created by Andy Brett on 3/25/17.
//  Copyright © 2017 APB. All rights reserved.
//

import Foundation
import HealthKit

enum HealthKitCategory : String {
    case Activity = "Activity"
    case BodyMeasurements = "Body Measurements"
    case Heart = "Heart"
    case Mindfulness = "Mindfulness"
    case Nutrition = "Nutrition"
    case Sleep = "Sleep"
    case Other = "Other Data"
}

class HealthKitConfig : NSObject {
    static let shared = HealthKitConfig()
    
    let metrics : [HealthKitMetric] = [
        // Activity
        QuantityHealthKitMetric.init(humanText: "Active energy", databaseString: "activeEnergy", category: .Activity, hkQuantityTypeIdentifier: .activeEnergyBurned),
        QuantityHealthKitMetric.init(humanText: "Cycling distance", databaseString: "cyclingDistance", category: .Activity, hkQuantityTypeIdentifier: .distanceCycling),
        QuantityHealthKitMetric.init(humanText: "Exercise time", databaseString: "exerciseTime", category: .Activity, hkQuantityTypeIdentifier: .appleExerciseTime),
        QuantityHealthKitMetric.init(humanText: "Nike Fuel", databaseString: "nikeFuel", category: .Activity, hkQuantityTypeIdentifier: .nikeFuel),
        QuantityHealthKitMetric.init(humanText: "Resting energy", databaseString: "basalEnergy", category: .Activity, hkQuantityTypeIdentifier: .basalEnergyBurned),
        // CategoryHealthKitMetric.init(humanText: "Stand hours", databaseString: "standHour", category: .Activity, hkCategoryTypeIdentifier: HKCategoryTypeIdentifier.appleStandHour),
        QuantityHealthKitMetric.init(humanText: "Steps", databaseString: "steps", category: .Activity, hkQuantityTypeIdentifier: .stepCount),
        QuantityHealthKitMetric.init(humanText: "Swimming distance", databaseString: "swimDistance", category: .Activity, hkQuantityTypeIdentifier: .distanceSwimming),
        QuantityHealthKitMetric.init(humanText: "Swimming strokes", databaseString: "swimStrokes", category: .Activity, hkQuantityTypeIdentifier: .swimmingStrokeCount),
        QuantityHealthKitMetric.init(humanText: "Walking/running distance", databaseString: "walkRunDistance", category: .Activity, hkQuantityTypeIdentifier: .distanceWalkingRunning),

        // Body Measurements
        QuantityHealthKitMetric.init(humanText: "Weight", databaseString: "weight", category: .BodyMeasurements, hkQuantityTypeIdentifier: .bodyMass),

        // Heart

        // Mindfulness
        MindfulSessionHealthKitMetric.init(humanText: "Mindful minutes", databaseString: "mindfulMinutes", category: .Mindfulness, hkCategoryTypeIdentifier: .mindfulSession),

        // Nutrition
        QuantityHealthKitMetric.init(humanText: "Dietary carbs", databaseString: "dietaryCarbs", category: .Nutrition, hkQuantityTypeIdentifier: .dietaryCarbohydrates),
        QuantityHealthKitMetric.init(humanText: "Dietary energy", databaseString: "dietaryEnergy", category: .Nutrition, hkQuantityTypeIdentifier: .dietaryEnergyConsumed),
        QuantityHealthKitMetric.init(humanText: "Dietary fat", databaseString: "dietaryFat", category: .Nutrition, hkQuantityTypeIdentifier: .dietaryFatTotal),
        QuantityHealthKitMetric.init(humanText: "Dietary protein", databaseString: "dietaryProtein", category: .Nutrition, hkQuantityTypeIdentifier: .dietaryProtein),
        QuantityHealthKitMetric.init(humanText: "Dietary saturated fat", databaseString: "dietarySaturatedFat", category: .Nutrition, hkQuantityTypeIdentifier: .dietaryFatSaturated),
        QuantityHealthKitMetric.init(humanText: "Dietary sodium", databaseString: "dietarySodium", category: .Nutrition, hkQuantityTypeIdentifier: .dietarySodium),
        QuantityHealthKitMetric.init(humanText: "Dietary sugar", databaseString: "dietarySugar", category: .Nutrition, hkQuantityTypeIdentifier: .dietarySugar),
        QuantityHealthKitMetric.init(humanText: "Water", databaseString: "water", category: .Nutrition, hkQuantityTypeIdentifier: .dietaryWater),

        // Sleep
        SleepAnalysisHealthKitMetric.init(humanText: "Time asleep", databaseString: "timeAsleep", category: .Sleep, hkCategoryTypeIdentifier: .sleepAnalysis, hkCategoryValueSleepAnalysis: .asleep),
        SleepAnalysisHealthKitMetric.init(humanText: "Time in bed", databaseString: "timeInBed", category: .Sleep,  hkCategoryTypeIdentifier: .sleepAnalysis, hkCategoryValueSleepAnalysis: .inBed),

        // Other

    ]

}
