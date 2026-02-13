//
//  MindfulnessHealthKitMetrics.swift
//  BeeSwift
//

import Foundation
import HealthKit

public class MindfulnessHealthKitMetrics {
  public static let shared = MindfulnessHealthKitMetrics()
  private init() {}
  public lazy var metrics: [HealthKitMetric] = {
    [
      MindfulSessionHealthKitMetric(
        humanText: "Mindful minutes",
        databaseString: "mindfulMinutes",
        category: .Mindfulness
      )
    ]
  }()
}
