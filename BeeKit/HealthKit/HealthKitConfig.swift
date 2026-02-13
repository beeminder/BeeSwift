//
//  HealthKitConfig.swift
//  BeeSwift
//
//  Created by Andy Brett on 3/25/17.
//  Copyright 2017 APB. All rights reserved.
//

import Foundation
import HealthKit

public class HealthKitConfig {
  public static let shared = HealthKitConfig()
  private init() {}
  public lazy var metrics: [HealthKitMetric] = {
    [
      // Activity metrics
      ActivityHealthKitMetrics.shared.metrics,
      // Body measurements
      BodyMeasurementsHealthKitMetrics.shared.metrics,
      // Mindfulness
      MindfulnessHealthKitMetrics.shared.metrics,
      // Nutrition
      NutritionHealthKitMetrics.shared.metrics,
      // Sleep
      SleepHealthKitMetrics.shared.metrics,
      // Other
      OtherHealthKitMetrics.shared.metrics,
    ].flatMap { $0 }
  }()
}
