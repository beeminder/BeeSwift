import XCTest

@testable import BeeSwift

final class HealthKitMetricConfigViewControllerTests: XCTestCase {

  func createViewController() -> HealthKitMetricConfigViewController {
    let vc = HealthKitMetricConfigViewController(goalName: "test-goal", metricName: "Steps")
    vc.loadViewIfNeeded()
    return vc
  }

  func createViewControllerWithWorkoutProvider(existingConfig: [String: Any] = [:]) -> (
    HealthKitMetricConfigViewController, WorkoutConfigurationProvider
  ) {
    let vc = HealthKitMetricConfigViewController(goalName: "test-goal", metricName: "Workout Minutes")
    let provider = WorkoutConfigurationProvider(existingConfig: existingConfig)
    vc.configurationProvider = provider
    vc.loadViewIfNeeded()
    return (vc, provider)
  }

  // MARK: - HealthKitMetricConfigViewController tests

  func testInfoRowsAlwaysPresent() {
    let vc = createViewController()

    XCTAssertEqual(vc.tableView.numberOfSections, 1)
    XCTAssertEqual(vc.tableView.numberOfRows(inSection: 0), 3)
  }

  func testInfoRowsWithProvider() {
    let (vc, _) = createViewControllerWithWorkoutProvider()

    XCTAssertEqual(vc.tableView.numberOfSections, 2)
    XCTAssertEqual(vc.tableView.numberOfRows(inSection: 0), 3)  // Info rows
    XCTAssertEqual(vc.tableView.numberOfRows(inSection: 1), 2)  // Provider rows
  }

  func testGetConfigParametersWithoutProvider() {
    let vc = createViewController()

    let config = vc.getConfigParameters()

    XCTAssertTrue(config.isEmpty)
  }

  func testGetConfigParametersWithProvider() {
    let (vc, _) = createViewControllerWithWorkoutProvider()

    let config = vc.getConfigParameters()

    XCTAssertEqual(config["daily_aggregate"] as? Bool, true)
  }
}

// MARK: - WorkoutConfigurationProvider tests

final class WorkoutConfigurationProviderTests: XCTestCase {

  func createProvider(existingConfig: [String: Any] = [:]) -> WorkoutConfigurationProvider {
    return WorkoutConfigurationProvider(existingConfig: existingConfig)
  }

  // MARK: - getConfigParameters() tests

  func testConfigDailyAggregateTrue() {
    let provider = createProvider()
    // Default is daily aggregate (index 0)

    let config = provider.getConfigParameters()

    XCTAssertEqual(config["daily_aggregate"] as? Bool, true)
  }

  func testConfigDailyAggregateFalse() {
    let provider = createProvider()
    provider.syncModeSegmentedControl.selectedSegmentIndex = 1  // Individual Workouts
    provider.syncModeSegmentedControl.sendActions(for: .valueChanged)

    let config = provider.getConfigParameters()

    XCTAssertEqual(config["daily_aggregate"] as? Bool, false)
  }

  func testConfigNoTypesSelectedOmitsWorkoutTypesKey() {
    let provider = createProvider()
    // Default has no types selected

    let config = provider.getConfigParameters()

    XCTAssertNil(config["workout_types"])
  }

  func testConfigWithTypesSelectedIncludesArray() {
    let provider = createProvider()
    provider.selectedWorkoutTypes = ["running", "yoga"]

    let config = provider.getConfigParameters()

    let workoutTypes = config["workout_types"] as? [String]
    XCTAssertNotNil(workoutTypes)
    XCTAssertEqual(workoutTypes?.count, 2)
    XCTAssertTrue(workoutTypes?.contains("running") ?? false)
    XCTAssertTrue(workoutTypes?.contains("yoga") ?? false)
  }

  func testConfigWithSingleTypeSelected() {
    let provider = createProvider()
    provider.selectedWorkoutTypes = ["cycling"]

    let config = provider.getConfigParameters()

    let workoutTypes = config["workout_types"] as? [String]
    XCTAssertEqual(workoutTypes, ["cycling"])
  }

  func testSyncModeChangeTriggersCallback() {
    let provider = createProvider()
    var callbackCalled = false
    provider.onConfigurationChanged = { callbackCalled = true }

    provider.syncModeSegmentedControl.selectedSegmentIndex = 1
    provider.syncModeSegmentedControl.sendActions(for: .valueChanged)

    XCTAssertTrue(callbackCalled)
  }

  // MARK: - Init with existing config tests

  func testInitWithExistingWorkoutTypes() {
    let provider = createProvider(existingConfig: ["workout_types": ["running", "yoga"]])

    XCTAssertEqual(provider.selectedWorkoutTypes, ["running", "yoga"])
  }

  func testInitWithExistingDailyAggregateFalse() {
    let provider = createProvider(existingConfig: ["daily_aggregate": false])

    XCTAssertEqual(provider.syncModeSegmentedControl.selectedSegmentIndex, 1)
  }

  func testInitWithExistingDailyAggregateTrue() {
    let provider = createProvider(existingConfig: ["daily_aggregate": true])

    XCTAssertEqual(provider.syncModeSegmentedControl.selectedSegmentIndex, 0)
  }

  func testInitWithEmptyConfig() {
    let provider = createProvider(existingConfig: [:])

    XCTAssertEqual(provider.selectedWorkoutTypes, [])
    XCTAssertEqual(provider.syncModeSegmentedControl.selectedSegmentIndex, 0)  // defaults to daily aggregate
  }

  func testNumberOfRows() {
    let provider = createProvider()

    XCTAssertEqual(provider.numberOfRows, 2)
  }
}
