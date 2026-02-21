import HealthKit
import XCTest

@testable import BeeKit

final class WorkoutMinutesHealthKitMetricTests: XCTestCase {
  let metric = WorkoutMinutesHealthKitMetric(
    humanText: "Workout minutes",
    databaseString: "workout_minutes",
    category: .Activity
  )

  // MARK: - Helper to create workouts

  func workout(type: HKWorkoutActivityType) -> HKWorkout {
    let now = Date()
    return HKWorkout(activityType: type, start: now, end: now.addingTimeInterval(60))
  }

  // MARK: - find(byActivityType:) tests

  func testFindByActivityTypeRunning() {
    XCTAssertEqual(WorkoutActivityTypeInfo.find(byActivityType: .running)?.identifier, "running")
  }

  func testFindByActivityTypeYoga() {
    XCTAssertEqual(WorkoutActivityTypeInfo.find(byActivityType: .yoga)?.identifier, "yoga")
  }

  func testFindByActivityTypeTraditionalStrengthTraining() {
    XCTAssertEqual(
      WorkoutActivityTypeInfo.find(byActivityType: .traditionalStrengthTraining)?.identifier,
      "traditionalStrengthTraining"
    )
  }

  func testFindByActivityTypeUnmappedTypeReturnsNil() {
    // .other is not in our supported list
    XCTAssertNil(WorkoutActivityTypeInfo.find(byActivityType: .other))
  }

  // MARK: - find(byIdentifier:) tests

  func testFindByIdentifierRunning() {
    XCTAssertEqual(WorkoutActivityTypeInfo.find(byIdentifier: "running")?.activityType, .running)
  }

  func testFindByIdentifierYoga() {
    XCTAssertEqual(WorkoutActivityTypeInfo.find(byIdentifier: "yoga")?.activityType, .yoga)
  }

  func testFindByIdentifierInvalidStringReturnsNil() {
    XCTAssertNil(WorkoutActivityTypeInfo.find(byIdentifier: "notARealWorkout"))
  }

  func testFindByIdentifierEmptyStringReturnsNil() { XCTAssertNil(WorkoutActivityTypeInfo.find(byIdentifier: "")) }

  // MARK: - displayName tests

  func testDisplayNameForRunning() {
    XCTAssertEqual(WorkoutActivityTypeInfo.find(byIdentifier: "running")?.displayName, "Running")
  }

  func testDisplayNameForHIIT() {
    XCTAssertEqual(WorkoutActivityTypeInfo.find(byIdentifier: "highIntensityIntervalTraining")?.displayName, "HIIT")
  }

  func testDisplayNameForInvalidIdentifierReturnsNil() {
    XCTAssertNil(WorkoutActivityTypeInfo.find(byIdentifier: "notReal")?.displayName)
  }

  // MARK: - types(forCategory:) tests

  func testWorkoutTypesForCardioCategory() {
    let cardioTypes = WorkoutActivityTypeInfo.types(forCategory: .cardio)
    let identifiers = cardioTypes.map { $0.identifier }

    XCTAssertTrue(identifiers.contains("running"))
    XCTAssertTrue(identifiers.contains("cycling"))
    XCTAssertTrue(identifiers.contains("swimming"))
    XCTAssertTrue(identifiers.contains("hiking"))
    XCTAssertFalse(identifiers.contains("yoga"))  // yoga is mind & body
  }

  func testWorkoutTypesForStrengthCategory() {
    let strengthTypes = WorkoutActivityTypeInfo.types(forCategory: .strength)
    let identifiers = strengthTypes.map { $0.identifier }

    XCTAssertEqual(strengthTypes.count, 3)
    XCTAssertTrue(identifiers.contains("traditionalStrengthTraining"))
    XCTAssertTrue(identifiers.contains("coreTraining"))
    XCTAssertTrue(identifiers.contains("functionalStrengthTraining"))
  }

  func testWorkoutTypesForMindBodyCategory() {
    let mindBodyTypes = WorkoutActivityTypeInfo.types(forCategory: .mindBody)
    let identifiers = mindBodyTypes.map { $0.identifier }

    XCTAssertTrue(identifiers.contains("yoga"))
    XCTAssertTrue(identifiers.contains("pilates"))
    XCTAssertFalse(identifiers.contains("running"))
  }

  // MARK: - filterWorkouts tests

  func testFilterWithEmptyConfigReturnsAllWorkouts() {
    let workouts = [workout(type: .running), workout(type: .yoga), workout(type: .cycling)]
    let config: [String: Any] = [:]

    let filtered = metric.filterWorkouts(workouts, config: config)

    XCTAssertEqual(filtered.count, 3)
  }

  func testFilterWithNilWorkoutTypesReturnsAllWorkouts() {
    let workouts = [workout(type: .running), workout(type: .yoga)]
    let config: [String: Any] = ["daily_aggregate": true]  // no workout_types key

    let filtered = metric.filterWorkouts(workouts, config: config)

    XCTAssertEqual(filtered.count, 2)
  }

  func testFilterWithEmptyWorkoutTypesArrayReturnsAllWorkouts() {
    let workouts = [workout(type: .running), workout(type: .yoga)]
    let config: [String: Any] = ["workout_types": [String]()]

    let filtered = metric.filterWorkouts(workouts, config: config)

    XCTAssertEqual(filtered.count, 2)
  }

  func testFilterWithSingleType() {
    let workouts = [workout(type: .running), workout(type: .yoga), workout(type: .cycling)]
    let config: [String: Any] = ["workout_types": ["running"]]

    let filtered = metric.filterWorkouts(workouts, config: config)

    XCTAssertEqual(filtered.count, 1)
    XCTAssertEqual(filtered.first?.workoutActivityType, .running)
  }

  func testFilterWithMultipleTypes() {
    let workouts = [workout(type: .running), workout(type: .yoga), workout(type: .cycling)]
    let config: [String: Any] = ["workout_types": ["running", "yoga"]]

    let filtered = metric.filterWorkouts(workouts, config: config)

    XCTAssertEqual(filtered.count, 2)
    let types = filtered.map { $0.workoutActivityType }
    XCTAssertTrue(types.contains(.running))
    XCTAssertTrue(types.contains(.yoga))
    XCTAssertFalse(types.contains(.cycling))
  }

  func testFilterExcludesNonMatchingTypes() {
    let workouts = [workout(type: .running), workout(type: .yoga)]
    let config: [String: Any] = ["workout_types": ["cycling"]]

    let filtered = metric.filterWorkouts(workouts, config: config)

    XCTAssertEqual(filtered.count, 0)
  }

  func testFilterIgnoresInvalidIdentifiers() {
    let workouts = [workout(type: .running), workout(type: .yoga)]
    let config: [String: Any] = ["workout_types": ["running", "notARealType"]]

    let filtered = metric.filterWorkouts(workouts, config: config)

    // Should still filter to just running, ignoring the invalid identifier
    XCTAssertEqual(filtered.count, 1)
    XCTAssertEqual(filtered.first?.workoutActivityType, .running)
  }
}
