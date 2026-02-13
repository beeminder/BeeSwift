//
//  OtherHealthKitMetrics.swift
//  BeeSwift
//

import Foundation
import HealthKit

public class OtherHealthKitMetrics {
  public static let shared = OtherHealthKitMetrics()
  private init() {}
  public lazy var metrics: [HealthKitMetric] = {
    [
      QuantityHealthKitMetric(
        humanText: "Time in Daylight",
        databaseString: "timeInDaylight",
        category: .Other,
        hkQuantityTypeIdentifier: .timeInDaylight
      )
    ]
  }()
}
