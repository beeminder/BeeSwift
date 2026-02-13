//
//  ActivityHealthKitMetrics.swift
//  BeeSwift
//

import Foundation
import HealthKit

public class ActivityHealthKitMetrics {
  public static let shared = ActivityHealthKitMetrics()
  private init() {}
  public lazy var metrics: [HealthKitMetric] = {
    [
      QuantityHealthKitMetric(
        humanText: "Active energy",
        databaseString: "activeEnergy",
        category: .Activity,
        hkQuantityTypeIdentifier: .activeEnergyBurned,
        precision: [HKUnit.largeCalorie(): 0]
      ),
      QuantityHealthKitMetric(
        humanText: "Cycling distance",
        databaseString: "cyclingDistance",
        category: .Activity,
        hkQuantityTypeIdentifier: .distanceCycling
      ),
      QuantityHealthKitMetric(
        humanText: "Exercise time",
        databaseString: "exerciseTime",
        category: .Activity,
        hkQuantityTypeIdentifier: .appleExerciseTime,
        precision: [HKUnit.minute(): 1]
      ),
      QuantityHealthKitMetric(
        humanText: "Nike Fuel",
        databaseString: "nikeFuel",
        category: .Activity,
        hkQuantityTypeIdentifier: .nikeFuel
      ),
      QuantityHealthKitMetric(
        humanText: "Resting energy",
        databaseString: "basalEnergy",
        category: .Activity,
        hkQuantityTypeIdentifier: .basalEnergyBurned,
        precision: [HKUnit.largeCalorie(): 0]
      ),
      StandHoursHealthKitMetric(
        humanText: "Stand hours",
        databaseString: "standHour",
        category: .Activity),
      QuantityHealthKitMetric(
        humanText: "Steps",
        databaseString: "steps",
        category: .Activity,
        hkQuantityTypeIdentifier: .stepCount,
        precision: [HKUnit.count(): 0]
      ),
      QuantityHealthKitMetric(
        humanText: "Swimming distance",
        databaseString: "swimDistance",
        category: .Activity,
        hkQuantityTypeIdentifier: .distanceSwimming
      ),
      QuantityHealthKitMetric(
        humanText: "Swimming strokes",
        databaseString: "swimStrokes",
        category: .Activity,
        hkQuantityTypeIdentifier: .swimmingStrokeCount
      ),
      QuantityHealthKitMetric(
        humanText: "Walking/running distance",
        databaseString: "walkRunDistance",
        category: .Activity,
        hkQuantityTypeIdentifier: .distanceWalkingRunning
      ),
      WorkoutMinutesHealthKitMetric(
        humanText: "Workout minutes",
        databaseString: "workoutMinutes",
        category: .Activity
      ),
    ]
  }()
}
