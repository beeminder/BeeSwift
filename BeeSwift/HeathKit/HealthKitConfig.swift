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
    
    let metrics : [HealthKitMetric] = [
        QuantityHealthKitMetric.init(humanText: "Steps", databaseString: "steps", hkQuantityTypeIdentifier: .stepCount),
        QuantityHealthKitMetric.init(humanText: "Active energy", databaseString: "activeEnergy", hkQuantityTypeIdentifier: .activeEnergyBurned),
        QuantityHealthKitMetric.init(humanText: "Exercise time", databaseString: "exerciseTime", hkQuantityTypeIdentifier: .appleExerciseTime),
        QuantityHealthKitMetric.init(humanText: "Weight", databaseString: "weight", hkQuantityTypeIdentifier: .bodyMass),
        QuantityHealthKitMetric.init(humanText: "Cycling distance", databaseString: "cyclingDistance", hkQuantityTypeIdentifier: .distanceCycling),
        QuantityHealthKitMetric.init(humanText: "Walking/running distance", databaseString: "walkRunDistance", hkQuantityTypeIdentifier: .distanceWalkingRunning),
        QuantityHealthKitMetric.init(humanText: "Nike Fuel", databaseString: "nikeFuel", hkQuantityTypeIdentifier: .nikeFuel),
        QuantityHealthKitMetric.init(humanText: "Water", databaseString: "water", hkQuantityTypeIdentifier: .dietaryWater),
        SleepAnalysisHealthKitMetric.init(humanText: "Time in bed", databaseString: "timeInBed", hkCategoryTypeIdentifier: .sleepAnalysis, hkCategoryValueSleepAnalysis: .inBed),
        SleepAnalysisHealthKitMetric.init(humanText: "Time asleep", databaseString: "timeAsleep", hkCategoryTypeIdentifier: .sleepAnalysis, hkCategoryValueSleepAnalysis: .asleep),
        // CategoryHealthKitMetric.init(humanText: "Stand hours", databaseString: "standHour", hkCategoryTypeIdentifier: HKCategoryTypeIdentifier.appleStandHour),
        QuantityHealthKitMetric.init(humanText: "Resting energy", databaseString: "basalEnergy", hkQuantityTypeIdentifier: .basalEnergyBurned),
        QuantityHealthKitMetric.init(humanText: "Dietary energy", databaseString: "dietaryEnergy", hkQuantityTypeIdentifier: .dietaryEnergyConsumed),
        QuantityHealthKitMetric.init(humanText: "Dietary protein", databaseString: "dietaryProtein", hkQuantityTypeIdentifier: .dietaryProtein),
        QuantityHealthKitMetric.init(humanText: "Dietary sugar", databaseString: "dietarySugar", hkQuantityTypeIdentifier: .dietarySugar),
        QuantityHealthKitMetric.init(humanText: "Dietary carbs", databaseString: "dietaryCarbs", hkQuantityTypeIdentifier: .dietaryCarbohydrates),
        QuantityHealthKitMetric.init(humanText: "Dietary fat", databaseString: "dietaryFat", hkQuantityTypeIdentifier: .dietaryFatTotal),
        QuantityHealthKitMetric.init(humanText: "Dietary saturated fat", databaseString: "dietarySaturatedFat", hkQuantityTypeIdentifier: .dietaryFatSaturated),
        QuantityHealthKitMetric.init(humanText: "Dietary sodium", databaseString: "dietarySodium", hkQuantityTypeIdentifier: .dietarySodium),
        QuantityHealthKitMetric.init(humanText: "Swimming strokes", databaseString: "swimStrokes", hkQuantityTypeIdentifier: .swimmingStrokeCount),
        QuantityHealthKitMetric.init(humanText: "Swimming distance", databaseString: "swimDistance", hkQuantityTypeIdentifier: .distanceSwimming),
        MindfulSessionHealthKitMetric.init(humanText: "Mindful minutes", databaseString: "mindfulMinutes", hkCategoryTypeIdentifier: .mindfulSession)
    ]

}
