//
//  SleepHealthKitMetrics.swift
//  BeeSwift
//

import Foundation
import HealthKit

public class SleepHealthKitMetrics {
  public static let shared = SleepHealthKitMetrics()
  private init() {}
  public lazy var metrics: [HealthKitMetric] = {
    [
      TimeInBedHealthKitMetric(humanText: "Time in bed", databaseString: "timeInBed", category: .Sleep),
      TimeAsleepHealthKitMetric(humanText: "Time asleep", databaseString: "timeAsleep", category: .Sleep),
    ]
  }()
}
