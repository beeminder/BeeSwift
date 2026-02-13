//
//  BodyMeasurementsHealthKitMetrics.swift
//  BeeSwift
//
//

import Foundation
import HealthKit

public class BodyMeasurementsHealthKitMetrics {
  public static let shared = BodyMeasurementsHealthKitMetrics()
  private init() {}
  public lazy var metrics: [HealthKitMetric] = {
    [WeightHealthKitMetric(humanText: "Weight", databaseString: "weight", category: .BodyMeasurements)]
  }()
}
