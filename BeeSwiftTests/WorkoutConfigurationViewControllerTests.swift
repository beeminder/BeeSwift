import XCTest

@testable import BeeSwift

final class WorkoutConfigurationViewControllerTests: XCTestCase {

  func createViewController(existingConfig: [String: Any] = [:]) -> WorkoutConfigurationViewController {
    let vc = WorkoutConfigurationViewController(existingConfig: existingConfig)
    vc.loadViewIfNeeded()
    return vc
  }

  // MARK: - getConfigParameters() tests

  func testConfigDailyAggregateTrue() {
    let vc = createViewController()
    // Default is daily aggregate (index 0)

    let config = vc.getConfigParameters()

    XCTAssertEqual(config["daily_aggregate"] as? Bool, true)
  }

  func testConfigDailyAggregateFalse() {
    let vc = createViewController()
    vc.syncModeSegmentedControl.selectedSegmentIndex = 1  // Individual Workouts
    vc.syncModeSegmentedControl.sendActions(for: .valueChanged)

    let config = vc.getConfigParameters()

    XCTAssertEqual(config["daily_aggregate"] as? Bool, false)
  }

  func testConfigNoTypesSelectedOmitsWorkoutTypesKey() {
    let vc = createViewController()
    // Default has no types selected

    let config = vc.getConfigParameters()

    XCTAssertNil(config["workout_types"])
  }

  func testConfigWithTypesSelectedIncludesArray() {
    let vc = createViewController()
    vc.selectedWorkoutTypes = ["running", "yoga"]

    let config = vc.getConfigParameters()

    let workoutTypes = config["workout_types"] as? [String]
    XCTAssertNotNil(workoutTypes)
    XCTAssertEqual(workoutTypes?.count, 2)
    XCTAssertTrue(workoutTypes?.contains("running") ?? false)
    XCTAssertTrue(workoutTypes?.contains("yoga") ?? false)
  }

  func testConfigWithSingleTypeSelected() {
    let vc = createViewController()
    vc.selectedWorkoutTypes = ["cycling"]

    let config = vc.getConfigParameters()

    let workoutTypes = config["workout_types"] as? [String]
    XCTAssertEqual(workoutTypes, ["cycling"])
  }

  func testSetSelectedWorkoutTypesUpdatesProperty() {
    let vc = createViewController()

    vc.setSelectedWorkoutTypes(["running", "swimming"])

    XCTAssertEqual(vc.selectedWorkoutTypes, ["running", "swimming"])
  }

  func testSetSelectedWorkoutTypesTriggersCallback() {
    let vc = createViewController()
    var callbackCalled = false
    vc.onConfigurationChanged = { callbackCalled = true }

    vc.setSelectedWorkoutTypes(["running"])

    XCTAssertTrue(callbackCalled)
  }

  // MARK: - Init with existing config tests

  func testInitWithExistingWorkoutTypes() {
    let vc = createViewController(existingConfig: ["workout_types": ["running", "yoga"]])

    XCTAssertEqual(vc.selectedWorkoutTypes, ["running", "yoga"])
  }

  func testInitWithExistingDailyAggregateFalse() {
    let vc = createViewController(existingConfig: ["daily_aggregate": false])

    XCTAssertEqual(vc.syncModeSegmentedControl.selectedSegmentIndex, 1)
  }

  func testInitWithExistingDailyAggregateTrue() {
    let vc = createViewController(existingConfig: ["daily_aggregate": true])

    XCTAssertEqual(vc.syncModeSegmentedControl.selectedSegmentIndex, 0)
  }

  func testInitWithEmptyConfig() {
    let vc = createViewController(existingConfig: [:])

    XCTAssertEqual(vc.selectedWorkoutTypes, [])
    XCTAssertEqual(vc.syncModeSegmentedControl.selectedSegmentIndex, 0)  // defaults to daily aggregate
  }
}
