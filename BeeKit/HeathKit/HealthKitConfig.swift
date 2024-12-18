//
//  HealthKitConfig.swift
//  BeeSwift
//
//  Created by Andy Brett on 3/25/17.
//  Copyright 2017 APB. All rights reserved.
//

import Foundation
import HealthKit

public enum HealthKitConfig {
    public static var metrics: [HealthKitMetric] {
        [
            // Activity
            QuantityHealthKitMetric(humanText: "Active energy", databaseString: "activeEnergy", category: .Activity, hkQuantityTypeIdentifier: .activeEnergyBurned, precision: [HKUnit.largeCalorie(): 0]),
            QuantityHealthKitMetric(humanText: "Cycling distance", databaseString: "cyclingDistance", category: .Activity, hkQuantityTypeIdentifier: .distanceCycling),
            QuantityHealthKitMetric(humanText: "Exercise time", databaseString: "exerciseTime", category: .Activity, hkQuantityTypeIdentifier: .appleExerciseTime),
            QuantityHealthKitMetric(humanText: "Nike Fuel", databaseString: "nikeFuel", category: .Activity, hkQuantityTypeIdentifier: .nikeFuel),
            QuantityHealthKitMetric(humanText: "Resting energy", databaseString: "basalEnergy", category: .Activity, hkQuantityTypeIdentifier: .basalEnergyBurned, precision: [HKUnit.largeCalorie(): 0]),
            StandHoursHealthKitMetric(humanText: "Stand hours", databaseString: "standHour", category: .Activity),
            QuantityHealthKitMetric(humanText: "Steps", databaseString: "steps", category: .Activity, hkQuantityTypeIdentifier: .stepCount, precision: [HKUnit.count(): 0]),
            QuantityHealthKitMetric(humanText: "Swimming distance", databaseString: "swimDistance", category: .Activity, hkQuantityTypeIdentifier: .distanceSwimming),
            QuantityHealthKitMetric(humanText: "Swimming strokes", databaseString: "swimStrokes", category: .Activity, hkQuantityTypeIdentifier: .swimmingStrokeCount),
            QuantityHealthKitMetric(humanText: "Walking/running distance", databaseString: "walkRunDistance", category: .Activity, hkQuantityTypeIdentifier: .distanceWalkingRunning),
            WorkoutMinutesHealthKitMetric(humanText: "Workout minutes", databaseString: "workoutMinutes", category: .Activity),

            // Body Measurements
            QuantityHealthKitMetric(humanText: "Weight", databaseString: "weight", category: .BodyMeasurements, hkQuantityTypeIdentifier: .bodyMass, precision: [HKUnit.pound(): 1, HKUnit.gramUnit(with: .kilo): 2]),

            // Heart

            // Mindfulness
            MindfulSessionHealthKitMetric(humanText: "Mindful minutes", databaseString: "mindfulMinutes", category: .Mindfulness),

            // Nutrition
            QuantityHealthKitMetric(humanText: "Dietary Caffeine", databaseString: "caffeine", category: .Nutrition, hkQuantityTypeIdentifier: .dietaryCaffeine),
            QuantityHealthKitMetric(humanText: "Dietary carbs", databaseString: "dietaryCarbs", category: .Nutrition, hkQuantityTypeIdentifier: .dietaryCarbohydrates),
            QuantityHealthKitMetric(humanText: "Dietary energy", databaseString: "dietaryEnergy", category: .Nutrition, hkQuantityTypeIdentifier: .dietaryEnergyConsumed),
            QuantityHealthKitMetric(humanText: "Dietary fat", databaseString: "dietaryFat", category: .Nutrition, hkQuantityTypeIdentifier: .dietaryFatTotal),
            QuantityHealthKitMetric(humanText: "Dietary protein", databaseString: "dietaryProtein", category: .Nutrition, hkQuantityTypeIdentifier: .dietaryProtein),
            QuantityHealthKitMetric(humanText: "Dietary saturated fat", databaseString: "dietarySaturatedFat", category: .Nutrition, hkQuantityTypeIdentifier: .dietaryFatSaturated),
            QuantityHealthKitMetric(humanText: "Dietary sodium", databaseString: "dietarySodium", category: .Nutrition, hkQuantityTypeIdentifier: .dietarySodium),
            QuantityHealthKitMetric(humanText: "Dietary sugar", databaseString: "dietarySugar", category: .Nutrition, hkQuantityTypeIdentifier: .dietarySugar),
            QuantityHealthKitMetric(humanText: "Vitamin A", databaseString: "dietaryVitaminA", category: .Nutrition, hkQuantityTypeIdentifier: .dietaryVitaminA),
            QuantityHealthKitMetric(humanText: "Vitamin B6", databaseString: "dietaryVitaminB6", category: .Nutrition, hkQuantityTypeIdentifier: .dietaryVitaminB6),
            QuantityHealthKitMetric(humanText: "Vitamin B12", databaseString: "dietaryVitaminB12", category: .Nutrition, hkQuantityTypeIdentifier: .dietaryVitaminB12),
            QuantityHealthKitMetric(humanText: "Vitamin C", databaseString: "dietaryVitaminC", category: .Nutrition, hkQuantityTypeIdentifier: .dietaryVitaminC),
            QuantityHealthKitMetric(humanText: "Vitamin D", databaseString: "dietaryVitaminD", category: .Nutrition, hkQuantityTypeIdentifier: .dietaryVitaminD),
            QuantityHealthKitMetric(humanText: "Vitamin E", databaseString: "dietaryVitaminE", category: .Nutrition, hkQuantityTypeIdentifier: .dietaryVitaminE),
            QuantityHealthKitMetric(humanText: "Vitamin K", databaseString: "dietaryVitaminK", category: .Nutrition, hkQuantityTypeIdentifier: .dietaryVitaminK),
            QuantityHealthKitMetric(humanText: "Water", databaseString: "water", category: .Nutrition, hkQuantityTypeIdentifier: .dietaryWater),
            
            // Self care
            ToothbrushingDailyMinutesHealthKitMetric.make(),
            ToothbrushingDailySessionsHealthKitMetric.make(),
            
            // Sleep
            TimeInBedHealthKitMetric(humanText: "Time in bed", databaseString: "timeInBed", category: .Sleep),
            TimeAsleepHealthKitMetric(humanText: "Time asleep", databaseString: "timeAsleep", category: .Sleep),

            // Other
            QuantityHealthKitMetric(humanText: "Time in Daylight", databaseString: "timeInDaylight", category: .Other, hkQuantityTypeIdentifier: .timeInDaylight),
        ]
    }
}
