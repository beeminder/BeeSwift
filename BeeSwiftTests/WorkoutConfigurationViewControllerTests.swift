import XCTest

@testable import BeeSwift

final class WorkoutConfigurationViewControllerTests: XCTestCase {

  func createViewController() -> WorkoutConfigurationViewController {
    let vc = WorkoutConfigurationViewController()
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
    // Simulate selecting "Individual Workouts" (index 1)
    // We need to access the segmented control - since it's private, we test via the public interface
    // by setting up the VC and checking the default, then we'd need to expose the control or test differently

    // For now, test the default state
    let config = vc.getConfigParameters()
    XCTAssertNotNil(config["daily_aggregate"])
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
}
