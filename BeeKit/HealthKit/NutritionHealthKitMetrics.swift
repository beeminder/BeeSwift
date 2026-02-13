//
//  NutritionHealthKitMetrics.swift
//  BeeSwift
//

import Foundation
import HealthKit

public class NutritionHealthKitMetrics {
  public static let shared = NutritionHealthKitMetrics()
  private init() {}
  public lazy var metrics: [HealthKitMetric] = {
    [
      QuantityHealthKitMetric(
        humanText: "Dietary Caffeine",
        databaseString: "caffeine",
        category: .Nutrition,
        hkQuantityTypeIdentifier: .dietaryCaffeine
      ),
      QuantityHealthKitMetric(
        humanText: "Dietary carbs",
        databaseString: "dietaryCarbs",
        category: .Nutrition,
        hkQuantityTypeIdentifier: .dietaryCarbohydrates
      ),
      QuantityHealthKitMetric(
        humanText: "Dietary energy",
        databaseString: "dietaryEnergy",
        category: .Nutrition,
        hkQuantityTypeIdentifier: .dietaryEnergyConsumed
      ),
      QuantityHealthKitMetric(
        humanText: "Dietary fat",
        databaseString: "dietaryFat",
        category: .Nutrition,
        hkQuantityTypeIdentifier: .dietaryFatTotal
      ),
      QuantityHealthKitMetric(
        humanText: "Dietary fiber",
        databaseString: "dietaryFiber",
        category: .Nutrition,
        hkQuantityTypeIdentifier: .dietaryFiber
      ),
      QuantityHealthKitMetric(
        humanText: "Dietary protein",
        databaseString: "dietaryProtein",
        category: .Nutrition,
        hkQuantityTypeIdentifier: .dietaryProtein
      ),
      QuantityHealthKitMetric(
        humanText: "Dietary saturated fat",
        databaseString: "dietarySaturatedFat",
        category: .Nutrition,
        hkQuantityTypeIdentifier: .dietaryFatSaturated
      ),
      QuantityHealthKitMetric(
        humanText: "Dietary sodium",
        databaseString: "dietarySodium",
        category: .Nutrition,
        hkQuantityTypeIdentifier: .dietarySodium
      ),
      QuantityHealthKitMetric(
        humanText: "Dietary sugar",
        databaseString: "dietarySugar",
        category: .Nutrition,
        hkQuantityTypeIdentifier: .dietarySugar
      ),
      QuantityHealthKitMetric(
        humanText: "Vitamin A",
        databaseString: "dietaryVitaminA",
        category: .Nutrition,
        hkQuantityTypeIdentifier: .dietaryVitaminA
      ),
      QuantityHealthKitMetric(
        humanText: "Vitamin B6",
        databaseString: "dietaryVitaminB6",
        category: .Nutrition,
        hkQuantityTypeIdentifier: .dietaryVitaminB6
      ),
      QuantityHealthKitMetric(
        humanText: "Vitamin B12",
        databaseString: "dietaryVitaminB12",
        category: .Nutrition,
        hkQuantityTypeIdentifier: .dietaryVitaminB12
      ),
      QuantityHealthKitMetric(
        humanText: "Vitamin C",
        databaseString: "dietaryVitaminC",
        category: .Nutrition,
        hkQuantityTypeIdentifier: .dietaryVitaminC
      ),
      QuantityHealthKitMetric(
        humanText: "Vitamin D",
        databaseString: "dietaryVitaminD",
        category: .Nutrition,
        hkQuantityTypeIdentifier: .dietaryVitaminD
      ),
      QuantityHealthKitMetric(
        humanText: "Vitamin E",
        databaseString: "dietaryVitaminE",
        category: .Nutrition,
        hkQuantityTypeIdentifier: .dietaryVitaminE
      ),
      QuantityHealthKitMetric(
        humanText: "Vitamin K",
        databaseString: "dietaryVitaminK",
        category: .Nutrition,
        hkQuantityTypeIdentifier: .dietaryVitaminK
      ),
      QuantityHealthKitMetric(
        humanText: "Water",
        databaseString: "water",
        category: .Nutrition,
        hkQuantityTypeIdentifier: .dietaryWater,
        precision: [HKUnit.fluidOunceUS(): 1]
      ),
    ]
  }()
}
