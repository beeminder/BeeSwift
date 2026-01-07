import Foundation
import HealthKit
import OSLog

public enum WorkoutCategory: String, CaseIterable {
  case cardio = "Cardio"
  case strength = "Strength"
  case mindBody = "Mind & Body"
  case racquetSports = "Racquet Sports"
  case teamSports = "Team Sports"
  case individualSports = "Individual Sports"
  case outdoor = "Outdoor & Adventure"
}

public struct WorkoutTypeInfo {
  public let activityType: HKWorkoutActivityType
  public let identifier: String
  public let displayName: String
  public let category: WorkoutCategory
}

public class WorkoutMinutesHealthKitMetric: CategoryHealthKitMetric {
  private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "WorkoutMinutesHealthKitMetric")
  let minuteInSeconds = 60.0

  init(humanText: String, databaseString: String, category: HealthKitCategory) {
    super.init(humanText: humanText, databaseString: databaseString, category: category, hkSampleType: .workoutType())
  }

  // MARK: - Workout Type Definitions

  public static let supportedWorkoutTypes: [WorkoutTypeInfo] = [
    // Cardio
    WorkoutTypeInfo(activityType: .running, identifier: "running", displayName: "Running", category: .cardio),
    WorkoutTypeInfo(activityType: .walking, identifier: "walking", displayName: "Walking", category: .cardio),
    WorkoutTypeInfo(activityType: .cycling, identifier: "cycling", displayName: "Cycling", category: .cardio),
    WorkoutTypeInfo(activityType: .swimming, identifier: "swimming", displayName: "Swimming", category: .cardio),
    WorkoutTypeInfo(activityType: .elliptical, identifier: "elliptical", displayName: "Elliptical", category: .cardio),
    WorkoutTypeInfo(activityType: .rowing, identifier: "rowing", displayName: "Rowing", category: .cardio),
    WorkoutTypeInfo(
      activityType: .stairClimbing,
      identifier: "stairClimbing",
      displayName: "Stair Climbing",
      category: .cardio
    ), WorkoutTypeInfo(activityType: .jumpRope, identifier: "jumpRope", displayName: "Jump Rope", category: .cardio),
    WorkoutTypeInfo(
      activityType: .mixedCardio,
      identifier: "mixedCardio",
      displayName: "Mixed Cardio",
      category: .cardio
    ),
    WorkoutTypeInfo(
      activityType: .highIntensityIntervalTraining,
      identifier: "highIntensityIntervalTraining",
      displayName: "HIIT",
      category: .cardio
    ),
    WorkoutTypeInfo(
      activityType: .crossTraining,
      identifier: "crossTraining",
      displayName: "Cross Training",
      category: .cardio
    ), WorkoutTypeInfo(activityType: .hiking, identifier: "hiking", displayName: "Hiking", category: .cardio),

    // Strength
    WorkoutTypeInfo(
      activityType: .traditionalStrengthTraining,
      identifier: "traditionalStrengthTraining",
      displayName: "Traditional Strength Training",
      category: .strength
    ),
    WorkoutTypeInfo(
      activityType: .coreTraining,
      identifier: "coreTraining",
      displayName: "Core Training",
      category: .strength
    ),
    WorkoutTypeInfo(
      activityType: .functionalStrengthTraining,
      identifier: "functionalStrengthTraining",
      displayName: "Functional Strength Training",
      category: .strength
    ),

    // Mind & Body
    WorkoutTypeInfo(activityType: .yoga, identifier: "yoga", displayName: "Yoga", category: .mindBody),
    WorkoutTypeInfo(activityType: .pilates, identifier: "pilates", displayName: "Pilates", category: .mindBody),
    WorkoutTypeInfo(activityType: .barre, identifier: "barre", displayName: "Barre", category: .mindBody),
    WorkoutTypeInfo(
      activityType: .flexibility,
      identifier: "flexibility",
      displayName: "Flexibility",
      category: .mindBody
    ),
    WorkoutTypeInfo(
      activityType: .mindAndBody,
      identifier: "mindAndBody",
      displayName: "Mind And Body",
      category: .mindBody
    ), WorkoutTypeInfo(activityType: .dance, identifier: "dance", displayName: "Dance", category: .mindBody),
    WorkoutTypeInfo(activityType: .cooldown, identifier: "cooldown", displayName: "Cool Down", category: .mindBody),
    WorkoutTypeInfo(
      activityType: .preparationAndRecovery,
      identifier: "preparationAndRecovery",
      displayName: "Preparation And Recovery",
      category: .mindBody
    ),

    // Racquet Sports
    WorkoutTypeInfo(activityType: .tennis, identifier: "tennis", displayName: "Tennis", category: .racquetSports),
    WorkoutTypeInfo(
      activityType: .badminton,
      identifier: "badminton",
      displayName: "Badminton",
      category: .racquetSports
    ),
    WorkoutTypeInfo(
      activityType: .racquetball,
      identifier: "racquetball",
      displayName: "Racquetball",
      category: .racquetSports
    ), WorkoutTypeInfo(activityType: .squash, identifier: "squash", displayName: "Squash", category: .racquetSports),
    WorkoutTypeInfo(
      activityType: .tableTennis,
      identifier: "tableTennis",
      displayName: "Table Tennis",
      category: .racquetSports
    ),

    // Team Sports
    WorkoutTypeInfo(
      activityType: .basketball,
      identifier: "basketball",
      displayName: "Basketball",
      category: .teamSports
    ), WorkoutTypeInfo(activityType: .soccer, identifier: "soccer", displayName: "Soccer", category: .teamSports),
    WorkoutTypeInfo(
      activityType: .americanFootball,
      identifier: "americanFootball",
      displayName: "American Football",
      category: .teamSports
    ), WorkoutTypeInfo(activityType: .baseball, identifier: "baseball", displayName: "Baseball", category: .teamSports),
    WorkoutTypeInfo(
      activityType: .volleyball,
      identifier: "volleyball",
      displayName: "Volleyball",
      category: .teamSports
    ), WorkoutTypeInfo(activityType: .hockey, identifier: "hockey", displayName: "Hockey", category: .teamSports),
    WorkoutTypeInfo(activityType: .rugby, identifier: "rugby", displayName: "Rugby", category: .teamSports),
    WorkoutTypeInfo(activityType: .cricket, identifier: "cricket", displayName: "Cricket", category: .teamSports),
    WorkoutTypeInfo(activityType: .lacrosse, identifier: "lacrosse", displayName: "Lacrosse", category: .teamSports),
    WorkoutTypeInfo(activityType: .softball, identifier: "softball", displayName: "Softball", category: .teamSports),

    // Individual Sports
    WorkoutTypeInfo(activityType: .golf, identifier: "golf", displayName: "Golf", category: .individualSports),
    WorkoutTypeInfo(
      activityType: .trackAndField,
      identifier: "trackAndField",
      displayName: "Track And Field",
      category: .individualSports
    ),
    WorkoutTypeInfo(
      activityType: .martialArts,
      identifier: "martialArts",
      displayName: "Martial Arts",
      category: .individualSports
    ), WorkoutTypeInfo(activityType: .boxing, identifier: "boxing", displayName: "Boxing", category: .individualSports),
    WorkoutTypeInfo(
      activityType: .wrestling,
      identifier: "wrestling",
      displayName: "Wrestling",
      category: .individualSports
    ),
    WorkoutTypeInfo(activityType: .archery, identifier: "archery", displayName: "Archery", category: .individualSports),
    WorkoutTypeInfo(activityType: .bowling, identifier: "bowling", displayName: "Bowling", category: .individualSports),

    // Outdoor & Adventure
    WorkoutTypeInfo(activityType: .climbing, identifier: "climbing", displayName: "Climbing", category: .outdoor),
    WorkoutTypeInfo(
      activityType: .snowSports,
      identifier: "snowSports",
      displayName: "Snow Sports",
      category: .outdoor
    ),
    WorkoutTypeInfo(
      activityType: .waterSports,
      identifier: "waterSports",
      displayName: "Water Sports",
      category: .outdoor
    ),
    WorkoutTypeInfo(
      activityType: .waterFitness,
      identifier: "waterFitness",
      displayName: "Water Fitness",
      category: .outdoor
    ),
    WorkoutTypeInfo(
      activityType: .paddleSports,
      identifier: "paddleSports",
      displayName: "Paddle Sports",
      category: .outdoor
    ), WorkoutTypeInfo(activityType: .fishing, identifier: "fishing", displayName: "Fishing", category: .outdoor),
    WorkoutTypeInfo(activityType: .hunting, identifier: "hunting", displayName: "Hunting", category: .outdoor),
  ]

  public static func workoutTypes(forCategory category: WorkoutCategory) -> [WorkoutTypeInfo] {
    return supportedWorkoutTypes.filter { $0.category == category }
  }

  public static func identifier(for activityType: HKWorkoutActivityType) -> String? {
    return supportedWorkoutTypes.first { $0.activityType == activityType }?.identifier
  }

  public static func activityType(for identifier: String) -> HKWorkoutActivityType? {
    return supportedWorkoutTypes.first { $0.identifier == identifier }?.activityType
  }

  public static func displayName(for identifier: String) -> String? {
    return supportedWorkoutTypes.first { $0.identifier == identifier }?.displayName
  }

  // MARK: - Workout Filtering

  func filterWorkouts(_ workouts: [HKWorkout], config: [String: Any]) -> [HKWorkout] {
    guard let typeIdentifiers = config["workout_types"] as? [String], !typeIdentifiers.isEmpty else {
      return workouts  // No filter = all types
    }
    let allowedTypes = Set(typeIdentifiers.compactMap { Self.activityType(for: $0) })
    return workouts.filter { allowedTypes.contains($0.workoutActivityType) }
  }

  override func hkDatapointValueForSamples(samples: [HKSample], startOfDate: Date) -> Double {
    // Might also want to filter by end of day?
    let samplesOnDay = samples.filter { sample in sample.startDate >= startOfDate }
    let workouts = samplesOnDay.compactMap({ sample in sample as? HKWorkout })
    let workoutMinutes = workouts.map { sample in sample.duration / minuteInSeconds }.reduce(0, +)
    return Double(workoutMinutes)
  }
  public override func recentDataPoints(
    days: Int,
    deadline: Int,
    healthStore: HKHealthStore,
    autodataConfig: [String: Any]
  ) async throws -> [BeeDataPoint] {
    let dailyAggregate = autodataConfig["daily_aggregate"] as? Bool ?? true
    if !dailyAggregate {
      return try await individualWorkoutDataPoints(
        days: days,
        deadline: deadline,
        healthStore: healthStore,
        autodataConfig: autodataConfig
      )
    } else {
      return try await dailyAggregateDataPoints(
        days: days,
        deadline: deadline,
        healthStore: healthStore,
        autodataConfig: autodataConfig
      )
    }
  }

  private func dailyAggregateDataPoints(
    days: Int,
    deadline: Int,
    healthStore: HKHealthStore,
    autodataConfig: [String: Any]
  ) async throws -> [BeeDataPoint] {
    let today = Daystamp.now(deadline: deadline)
    let startDate = today - days
    var results: [BeeDataPoint] = []

    for date in (startDate...today) {
      let samples = try await getWorkoutSamples(date: date, deadline: deadline, healthStore: healthStore)
      let workouts = samples.compactMap { $0 as? HKWorkout }
      let filteredWorkouts = filterWorkouts(workouts, config: autodataConfig)
      let workoutMinutes = filteredWorkouts.map { $0.duration / minuteInSeconds }.reduce(0, +)

      let id = "apple-heath-" + date.description
      results.append(
        NewDataPoint(
          requestid: id,
          daystamp: date,
          value: NSNumber(value: workoutMinutes),
          comment: "Auto-entered via Apple Health"
        )
      )
    }
    return results
  }

  private func individualWorkoutDataPoints(
    days: Int,
    deadline: Int,
    healthStore: HKHealthStore,
    autodataConfig: [String: Any]
  ) async throws -> [BeeDataPoint] {
    let today = Daystamp.now(deadline: deadline)
    let startDate = today - days
    var results: [BeeDataPoint] = []
    for date in (startDate...today) {
      let samples = try await getWorkoutSamples(date: date, deadline: deadline, healthStore: healthStore)
      let workouts = samples.compactMap { $0 as? HKWorkout }
      let filteredWorkouts = filterWorkouts(workouts, config: autodataConfig)
      for workout in filteredWorkouts {
        let workoutMinutes = workout.duration / minuteInSeconds
        let workoutDescription = formatWorkoutDescription(workout: workout)
        let id = "apple-health-workout-\(workout.uuid.uuidString)"
        results.append(
          NewDataPoint(
            requestid: id,
            daystamp: date,
            value: NSNumber(value: workoutMinutes),
            comment: workoutDescription
          )
        )
      }
    }
    return results
  }
  private func getWorkoutSamples(date: Daystamp, deadline: Int, healthStore: HKHealthStore) async throws -> [HKSample] {
    return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
      let query = HKSampleQuery(
        sampleType: sampleType(),
        predicate: HKQuery.predicateForSamples(
          withStart: date.start(deadline: deadline),
          end: date.end(deadline: deadline)
        ),
        limit: 0,
        sortDescriptors: nil,
        resultsHandler: { (query, samples, error) in
          if let error = error {
            continuation.resume(throwing: error)
          } else if let samples = samples {
            continuation.resume(returning: samples)
          } else {
            continuation.resume(throwing: HealthKitError("HKSampleQuery did not return samples"))
          }
        }
      )
      healthStore.execute(query)
    }
  }
  private func formatWorkoutDescription(workout: HKWorkout) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    let timeString = formatter.string(from: workout.startDate)
    let activityName = workoutActivityTypeName(for: workout.workoutActivityType)
    return "\(activityName) at \(timeString)"
  }
  private func workoutActivityTypeName(for activityType: HKWorkoutActivityType) -> String {
    return Self.supportedWorkoutTypes.first { $0.activityType == activityType }?.displayName ?? "Workout"
  }

  public override func units(healthStore: HKHealthStore) async throws -> HKUnit { return HKUnit.minute() }
}
