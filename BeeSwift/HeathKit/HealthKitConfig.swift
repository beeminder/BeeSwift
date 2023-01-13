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
        // Activity
        QuantityHealthKitMetric.init(humanText: "Active energy", databaseString: "activeEnergy", category: .Activity, hkQuantityTypeIdentifier: .activeEnergyBurned),
        QuantityHealthKitMetric.init(humanText: "Cycling distance", databaseString: "cyclingDistance", category: .Activity, hkQuantityTypeIdentifier: .distanceCycling),
        QuantityHealthKitMetric.init(humanText: "Exercise time", databaseString: "exerciseTime", category: .Activity, hkQuantityTypeIdentifier: .appleExerciseTime),
        QuantityHealthKitMetric.init(humanText: "Nike Fuel", databaseString: "nikeFuel", category: .Activity, hkQuantityTypeIdentifier: .nikeFuel),
        QuantityHealthKitMetric.init(humanText: "Resting energy", databaseString: "basalEnergy", category: .Activity, hkQuantityTypeIdentifier: .basalEnergyBurned),
        // TODO: This one is almost certainly not right!
        StandHoursHealthKitMetric.init(humanText: "Stand hours", databaseString: "standHour", category: .Activity),
        QuantityHealthKitMetric.init(humanText: "Steps", databaseString: "steps", category: .Activity, hkQuantityTypeIdentifier: .stepCount),
        QuantityHealthKitMetric.init(humanText: "Swimming distance", databaseString: "swimDistance", category: .Activity, hkQuantityTypeIdentifier: .distanceSwimming),
        QuantityHealthKitMetric.init(humanText: "Swimming strokes", databaseString: "swimStrokes", category: .Activity, hkQuantityTypeIdentifier: .swimmingStrokeCount),
        QuantityHealthKitMetric.init(humanText: "Walking/running distance", databaseString: "walkRunDistance", category: .Activity, hkQuantityTypeIdentifier: .distanceWalkingRunning),

        // Body Measurements
        QuantityHealthKitMetric.init(humanText: "Weight", databaseString: "weight", category: .BodyMeasurements, hkQuantityTypeIdentifier: .bodyMass),

        // Heart

        // Mindfulness
        MindfulSessionHealthKitMetric.init(humanText: "Mindful minutes", databaseString: "mindfulMinutes", category: .Mindfulness),

        // Nutrition
        QuantityHealthKitMetric.init(humanText: "Dietary Caffeine", databaseString: "caffeine", category: .Nutrition, hkQuantityTypeIdentifier: .dietaryCaffeine),
        QuantityHealthKitMetric.init(humanText: "Dietary carbs", databaseString: "dietaryCarbs", category: .Nutrition, hkQuantityTypeIdentifier: .dietaryCarbohydrates),
        QuantityHealthKitMetric.init(humanText: "Dietary energy", databaseString: "dietaryEnergy", category: .Nutrition, hkQuantityTypeIdentifier: .dietaryEnergyConsumed),
        QuantityHealthKitMetric.init(humanText: "Dietary fat", databaseString: "dietaryFat", category: .Nutrition, hkQuantityTypeIdentifier: .dietaryFatTotal),
        QuantityHealthKitMetric.init(humanText: "Dietary protein", databaseString: "dietaryProtein", category: .Nutrition, hkQuantityTypeIdentifier: .dietaryProtein),
        QuantityHealthKitMetric.init(humanText: "Dietary saturated fat", databaseString: "dietarySaturatedFat", category: .Nutrition, hkQuantityTypeIdentifier: .dietaryFatSaturated),
        QuantityHealthKitMetric.init(humanText: "Dietary sodium", databaseString: "dietarySodium", category: .Nutrition, hkQuantityTypeIdentifier: .dietarySodium),
        QuantityHealthKitMetric.init(humanText: "Dietary sugar", databaseString: "dietarySugar", category: .Nutrition, hkQuantityTypeIdentifier: .dietarySugar),
        QuantityHealthKitMetric.init(humanText: "Vitamin A", databaseString: "dietaryVitaminA", category: .Nutrition, hkQuantityTypeIdentifier: .dietaryVitaminA),
        QuantityHealthKitMetric.init(humanText: "Vitamin B6", databaseString: "dietaryVitaminB6", category: .Nutrition, hkQuantityTypeIdentifier: .dietaryVitaminB6),
        QuantityHealthKitMetric.init(humanText: "Vitamin B12", databaseString: "dietaryVitaminB12", category: .Nutrition, hkQuantityTypeIdentifier: .dietaryVitaminB12),
        QuantityHealthKitMetric.init(humanText: "Vitamin C", databaseString: "dietaryVitaminC", category: .Nutrition, hkQuantityTypeIdentifier: .dietaryVitaminC),
        QuantityHealthKitMetric.init(humanText: "Vitamin D", databaseString: "dietaryVitaminD", category: .Nutrition, hkQuantityTypeIdentifier: .dietaryVitaminD),
        QuantityHealthKitMetric.init(humanText: "Vitamin E", databaseString: "dietaryVitaminE", category: .Nutrition, hkQuantityTypeIdentifier: .dietaryVitaminE),
        QuantityHealthKitMetric.init(humanText: "Vitamin K", databaseString: "dietaryVitaminK", category: .Nutrition, hkQuantityTypeIdentifier: .dietaryVitaminK),
        QuantityHealthKitMetric.init(humanText: "Water", databaseString: "water", category: .Nutrition, hkQuantityTypeIdentifier: .dietaryWater),

        // Sleep
        TimeInBedHealthKitMetric.init(humanText: "Time in bed", databaseString: "timeInBed", category: .Sleep),
        TimeAsleepHealthKitMetric.init(humanText: "Time asleep", databaseString: "timeAsleep", category: .Sleep)

        // Other
    ]
}
