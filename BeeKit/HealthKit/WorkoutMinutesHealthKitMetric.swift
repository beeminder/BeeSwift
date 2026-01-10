import Foundation
import HealthKit
import OSLog

public enum WorkoutActivityCategory: String, CaseIterable {
  case cardio = "Cardio"
  case strength = "Strength"
  case mindBody = "Mind & Body"
  case racquetSports = "Racquet Sports"
  case teamSports = "Team Sports"
  case individualSports = "Individual Sports"
  case outdoor = "Outdoor & Adventure"
}

public struct WorkoutActivityTypeInfo {
  public let activityType: HKWorkoutActivityType
  public let identifier: String
  public let displayName: String
  public let category: WorkoutActivityCategory

  // MARK: - All Supported Types

  public static let all: [WorkoutActivityTypeInfo] = [
    // Cardio
    WorkoutActivityTypeInfo(activityType: .running, identifier: "running", displayName: "Running", category: .cardio),
    WorkoutActivityTypeInfo(activityType: .walking, identifier: "walking", displayName: "Walking", category: .cardio),
    WorkoutActivityTypeInfo(activityType: .cycling, identifier: "cycling", displayName: "Cycling", category: .cardio),
    WorkoutActivityTypeInfo(
      activityType: .swimming,
      identifier: "swimming",
      displayName: "Swimming",
      category: .cardio
    ),
    WorkoutActivityTypeInfo(
      activityType: .elliptical,
      identifier: "elliptical",
      displayName: "Elliptical",
      category: .cardio
    ), WorkoutActivityTypeInfo(activityType: .rowing, identifier: "rowing", displayName: "Rowing", category: .cardio),
    WorkoutActivityTypeInfo(
      activityType: .stairClimbing,
      identifier: "stairClimbing",
      displayName: "Stair Climbing",
      category: .cardio
    ),
    WorkoutActivityTypeInfo(
      activityType: .jumpRope,
      identifier: "jumpRope",
      displayName: "Jump Rope",
      category: .cardio
    ),
    WorkoutActivityTypeInfo(
      activityType: .mixedCardio,
      identifier: "mixedCardio",
      displayName: "Mixed Cardio",
      category: .cardio
    ),
    WorkoutActivityTypeInfo(
      activityType: .highIntensityIntervalTraining,
      identifier: "highIntensityIntervalTraining",
      displayName: "HIIT",
      category: .cardio
    ),
    WorkoutActivityTypeInfo(
      activityType: .crossTraining,
      identifier: "crossTraining",
      displayName: "Cross Training",
      category: .cardio
    ), WorkoutActivityTypeInfo(activityType: .hiking, identifier: "hiking", displayName: "Hiking", category: .cardio),

    // Strength
    WorkoutActivityTypeInfo(
      activityType: .traditionalStrengthTraining,
      identifier: "traditionalStrengthTraining",
      displayName: "Traditional Strength Training",
      category: .strength
    ),
    WorkoutActivityTypeInfo(
      activityType: .coreTraining,
      identifier: "coreTraining",
      displayName: "Core Training",
      category: .strength
    ),
    WorkoutActivityTypeInfo(
      activityType: .functionalStrengthTraining,
      identifier: "functionalStrengthTraining",
      displayName: "Functional Strength Training",
      category: .strength
    ),

    // Mind & Body
    WorkoutActivityTypeInfo(activityType: .yoga, identifier: "yoga", displayName: "Yoga", category: .mindBody),
    WorkoutActivityTypeInfo(activityType: .pilates, identifier: "pilates", displayName: "Pilates", category: .mindBody),
    WorkoutActivityTypeInfo(activityType: .barre, identifier: "barre", displayName: "Barre", category: .mindBody),
    WorkoutActivityTypeInfo(
      activityType: .flexibility,
      identifier: "flexibility",
      displayName: "Flexibility",
      category: .mindBody
    ),
    WorkoutActivityTypeInfo(
      activityType: .mindAndBody,
      identifier: "mindAndBody",
      displayName: "Mind And Body",
      category: .mindBody
    ), WorkoutActivityTypeInfo(activityType: .dance, identifier: "dance", displayName: "Dance", category: .mindBody),
    WorkoutActivityTypeInfo(
      activityType: .cooldown,
      identifier: "cooldown",
      displayName: "Cool Down",
      category: .mindBody
    ),
    WorkoutActivityTypeInfo(
      activityType: .preparationAndRecovery,
      identifier: "preparationAndRecovery",
      displayName: "Preparation And Recovery",
      category: .mindBody
    ),

    // Racquet Sports
    WorkoutActivityTypeInfo(
      activityType: .tennis,
      identifier: "tennis",
      displayName: "Tennis",
      category: .racquetSports
    ),
    WorkoutActivityTypeInfo(
      activityType: .badminton,
      identifier: "badminton",
      displayName: "Badminton",
      category: .racquetSports
    ),
    WorkoutActivityTypeInfo(
      activityType: .racquetball,
      identifier: "racquetball",
      displayName: "Racquetball",
      category: .racquetSports
    ),
    WorkoutActivityTypeInfo(
      activityType: .squash,
      identifier: "squash",
      displayName: "Squash",
      category: .racquetSports
    ),
    WorkoutActivityTypeInfo(
      activityType: .tableTennis,
      identifier: "tableTennis",
      displayName: "Table Tennis",
      category: .racquetSports
    ),

    // Team Sports
    WorkoutActivityTypeInfo(
      activityType: .basketball,
      identifier: "basketball",
      displayName: "Basketball",
      category: .teamSports
    ),
    WorkoutActivityTypeInfo(activityType: .soccer, identifier: "soccer", displayName: "Soccer", category: .teamSports),
    WorkoutActivityTypeInfo(
      activityType: .americanFootball,
      identifier: "americanFootball",
      displayName: "American Football",
      category: .teamSports
    ),
    WorkoutActivityTypeInfo(
      activityType: .baseball,
      identifier: "baseball",
      displayName: "Baseball",
      category: .teamSports
    ),
    WorkoutActivityTypeInfo(
      activityType: .volleyball,
      identifier: "volleyball",
      displayName: "Volleyball",
      category: .teamSports
    ),
    WorkoutActivityTypeInfo(activityType: .hockey, identifier: "hockey", displayName: "Hockey", category: .teamSports),
    WorkoutActivityTypeInfo(activityType: .rugby, identifier: "rugby", displayName: "Rugby", category: .teamSports),
    WorkoutActivityTypeInfo(
      activityType: .cricket,
      identifier: "cricket",
      displayName: "Cricket",
      category: .teamSports
    ),
    WorkoutActivityTypeInfo(
      activityType: .lacrosse,
      identifier: "lacrosse",
      displayName: "Lacrosse",
      category: .teamSports
    ),
    WorkoutActivityTypeInfo(
      activityType: .softball,
      identifier: "softball",
      displayName: "Softball",
      category: .teamSports
    ),

    // Individual Sports
    WorkoutActivityTypeInfo(activityType: .golf, identifier: "golf", displayName: "Golf", category: .individualSports),
    WorkoutActivityTypeInfo(
      activityType: .trackAndField,
      identifier: "trackAndField",
      displayName: "Track And Field",
      category: .individualSports
    ),
    WorkoutActivityTypeInfo(
      activityType: .martialArts,
      identifier: "martialArts",
      displayName: "Martial Arts",
      category: .individualSports
    ),
    WorkoutActivityTypeInfo(
      activityType: .boxing,
      identifier: "boxing",
      displayName: "Boxing",
      category: .individualSports
    ),
    WorkoutActivityTypeInfo(
      activityType: .wrestling,
      identifier: "wrestling",
      displayName: "Wrestling",
      category: .individualSports
    ),
    WorkoutActivityTypeInfo(
      activityType: .archery,
      identifier: "archery",
      displayName: "Archery",
      category: .individualSports
    ),
    WorkoutActivityTypeInfo(
      activityType: .bowling,
      identifier: "bowling",
      displayName: "Bowling",
      category: .individualSports
    ),

    // Outdoor & Adventure
    WorkoutActivityTypeInfo(
      activityType: .climbing,
      identifier: "climbing",
      displayName: "Climbing",
      category: .outdoor
    ),
    WorkoutActivityTypeInfo(
      activityType: .snowSports,
      identifier: "snowSports",
      displayName: "Snow Sports",
      category: .outdoor
    ),
    WorkoutActivityTypeInfo(
      activityType: .waterSports,
      identifier: "waterSports",
      displayName: "Water Sports",
      category: .outdoor
    ),
    WorkoutActivityTypeInfo(
      activityType: .waterFitness,
      identifier: "waterFitness",
      displayName: "Water Fitness",
      category: .outdoor
    ),
    WorkoutActivityTypeInfo(
      activityType: .paddleSports,
      identifier: "paddleSports",
      displayName: "Paddle Sports",
      category: .outdoor
    ),
    WorkoutActivityTypeInfo(activityType: .fishing, identifier: "fishing", displayName: "Fishing", category: .outdoor),
    WorkoutActivityTypeInfo(activityType: .hunting, identifier: "hunting", displayName: "Hunting", category: .outdoor),
  ]

  // MARK: - Lookup Methods

  public static func types(forCategory category: WorkoutActivityCategory) -> [WorkoutActivityTypeInfo] {
    return all.filter { $0.category == category }
  }

  public static func find(byActivityType activityType: HKWorkoutActivityType) -> WorkoutActivityTypeInfo? {
    return all.first { $0.activityType == activityType }
  }

  public static func find(byIdentifier identifier: String) -> WorkoutActivityTypeInfo? {
    return all.first { $0.identifier == identifier }
  }
}

public class WorkoutMinutesHealthKitMetric: CategoryHealthKitMetric {
  private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "WorkoutMinutesHealthKitMetric")
  let minuteInSeconds = 60.0

  public override var precision: [HKUnit: Int] { return [HKUnit.minute(): 1] }

  init(humanText: String, databaseString: String, category: HealthKitCategory) {
    super.init(humanText: humanText, databaseString: databaseString, category: category, hkSampleType: .workoutType())
  }

  public override var hasAdditionalOptions: Bool { true }

  // MARK: - Workout Filtering

  func filterWorkouts(_ workouts: [HKWorkout], config: [String: Any]) -> [HKWorkout] {
    guard let allowedTypes = allowedWorkoutTypes(from: config) else {
      return workouts  // No filter = all types
    }
    return workouts.filter { allowedTypes.contains($0.workoutActivityType) }
  }

  private func allowedWorkoutTypes(from config: [String: Any]) -> Set<HKWorkoutActivityType>? {
    guard let typeIdentifiers = config["workout_types"] as? [String], !typeIdentifiers.isEmpty else { return nil }
    return Set(typeIdentifiers.compactMap { WorkoutActivityTypeInfo.find(byIdentifier: $0)?.activityType })
  }

  func workoutMatchesFilter(_ sample: HKSample, config: [String: Any]) -> Bool {
    guard let workout = sample as? HKWorkout else { return false }
    guard let allowedTypes = allowedWorkoutTypes(from: config) else {
      return true  // No filter = all types
    }
    return allowedTypes.contains(workout.workoutActivityType)
  }

  override func hkDatapointValueForSamples(samples: [HKSample], startOfDate: Date) -> Double {
    // Might also want to filter by end of day?
    let samplesOnDay = samples.filter { sample in sample.startDate >= startOfDate }
    let workouts = samplesOnDay.compactMap({ sample in sample as? HKWorkout })
    let workoutMinutes = workouts.map { sample in sample.duration / minuteInSeconds }.reduce(0, +)
    return applyPrecision(value: Double(workoutMinutes), unit: HKUnit.minute())
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
      return try await super.recentDataPoints(
        days: days,
        deadline: deadline,
        healthStore: healthStore,
        autodataConfig: autodataConfig,
        samplePredicate: { self.workoutMatchesFilter($0, config: autodataConfig) }
      )
    }
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
        let workoutMinutes = applyPrecision(value: workout.duration / minuteInSeconds, unit: HKUnit.minute())
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
    let activityName =
      WorkoutActivityTypeInfo.find(byActivityType: workout.workoutActivityType)?.displayName ?? "Workout"
    return "\(activityName) at \(timeString)"
  }

  public override func units(healthStore: HKHealthStore) async throws -> HKUnit { return HKUnit.minute() }
}
