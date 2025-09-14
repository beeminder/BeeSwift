import CoreData
import XCTest

@testable import BeeKit

class MigrationTests: XCTestCase {
  private struct TestData {
    static let userLastModified = Date(timeIntervalSince1970: 1_600_000_000)
    static let goalLastModified = Date(timeIntervalSince1970: 1_610_000_000)
    static let dataPointLastModified = Date(timeIntervalSince1970: 1_620_000_000)
  }
  override func tearDown() {
    super.tearDown()

    // Clean up any test files
    let fileManager = FileManager.default
    let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())

    if let files = try? fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) {
      for file in files where file.lastPathComponent.hasPrefix("TestMigration_") {
        try? fileManager.removeItem(at: file)
      }
    }
  }
  // Creates a CoreData store with the old model version (v1)
  private func createStoreWithOldModel() -> URL {
    let storeURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(
      "TestMigration_\(UUID().uuidString).sqlite"
    )
    // Register needed value transformers
    DueByTableValueTransformer.register()
    // Load the old model version
    let bundle = Bundle(for: BeeminderPersistentContainer.self)
    guard
      let oldVersionURL = bundle.url(
        forResource: "BeeminderModel",
        withExtension: "mom",
        subdirectory: "BeeminderModel.momd"
      ), let oldModel = NSManagedObjectModel(contentsOf: oldVersionURL)
    else {
      XCTFail("Failed to load old data model")
      fatalError()
    }
    // Create store with old model
    let coordinator = NSPersistentStoreCoordinator(managedObjectModel: oldModel)
    do {
      try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: [:])
      let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
      context.persistentStoreCoordinator = coordinator
      // Create user
      let user = NSEntityDescription.insertNewObject(forEntityName: "User", into: context)
      user.setValue("testuser", forKey: "username")
      user.setValue("America/Los_Angeles", forKey: "timezone")
      user.setValue(false, forKey: "deadbeat")
      user.setValue(Date(), forKey: "updatedAt")
      user.setValue(TestData.userLastModified, forKey: "lastModifiedLocal")

      // Create goal with minimal required fields
      let goal = NSEntityDescription.insertNewObject(forEntityName: "Goal", into: context)
      goal.setValue("test-goal", forKey: "slug")
      goal.setValue("Test Goal", forKey: "title")
      goal.setValue("test1", forKey: "id")
      // Add placeholders for all required fields
      for field in ["graphUrl", "thumbUrl", "urgencyKey", "lastTouch", "limSum", "safeSum", "yAxis"] {
        goal.setValue("", forKey: field)
      }
      for field in ["alertStart", "deadline", "initDay", "leadTime", "pledge", "safeBuf"] {
        goal.setValue(0, forKey: field)
      }
      for field in ["hhmmFormat", "queued", "todayta", "useDefaults", "won"] { goal.setValue(false, forKey: field) }
      goal.setValue(DueByDictionary(), forKey: "dueBy")
      goal.setValue(TestData.goalLastModified, forKey: "lastModifiedLocal")
      goal.setValue(user, forKey: "owner")
      // Create datapoint
      let dataPoint = NSEntityDescription.insertNewObject(forEntityName: "DataPoint", into: context)
      dataPoint.setValue("dp1", forKey: "id")
      dataPoint.setValue("20230101", forKey: "daystampRaw")
      dataPoint.setValue(NSDecimalNumber(value: 1.0), forKey: "value")
      dataPoint.setValue(TestData.dataPointLastModified, forKey: "lastModifiedLocal")
      dataPoint.setValue(goal, forKey: "goal")
      try context.save()
      return storeURL
    } catch {
      XCTFail("Failed to create store: \(error)")
      fatalError()
    }
  }
  // Test that migration from lastModifiedLocal to lastUpdatedLocal works
  func testLastUpdatedLocalMigration() throws {
    DueByTableValueTransformer.register()

    let storeURL = createStoreWithOldModel()
    let container = BeeminderPersistentContainer(name: "BeeminderModel")
    let description = NSPersistentStoreDescription(url: storeURL)
    container.persistentStoreDescriptions = [description]
    let expectation = XCTestExpectation(description: "Load store")
    var loadError: Error?
    container.loadPersistentStores { _, error in
      loadError = error
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 5.0)
    XCTAssertNil(loadError, "Migration should succeed")
    let context = container.viewContext
    // Migration on User
    let userRequest = NSFetchRequest<User>(entityName: "User")
    let users = try context.fetch(userRequest)
    XCTAssertEqual(users.count, 1, "Should have one user after migration")
    if let user = users.first {
      XCTAssertEqual(
        user.lastUpdatedLocal.timeIntervalSince1970,
        TestData.userLastModified.timeIntervalSince1970,
        accuracy: 0.001,
        "User date value should be preserved during migration"
      )
    }
    // Migration on Goal
    let goalRequest = NSFetchRequest<Goal>(entityName: "Goal")
    let goals = try context.fetch(goalRequest)
    XCTAssertEqual(goals.count, 1, "Should have one goal after migration")
    if let goal = goals.first {
      XCTAssertEqual(
        goal.lastUpdatedLocal.timeIntervalSince1970,
        TestData.goalLastModified.timeIntervalSince1970,
        accuracy: 0.001,
        "Goal date value should be preserved during migration"
      )
    }
    // Migration on DataPoint
    let dataPointRequest = NSFetchRequest<DataPoint>(entityName: "DataPoint")
    let dataPoints = try context.fetch(dataPointRequest)
    XCTAssertEqual(dataPoints.count, 1, "Should have one data point after migration")
    if let dataPoint = dataPoints.first {
      XCTAssertEqual(
        dataPoint.lastUpdatedLocal.timeIntervalSince1970,
        TestData.dataPointLastModified.timeIntervalSince1970,
        accuracy: 0.001,
        "DataPoint date value should be preserved during migration"
      )
    }
  }
  func testAutodataConfigMigration() throws {
    DueByTableValueTransformer.register()

    let storeURL = createStoreWithOldModel()
    let container = BeeminderPersistentContainer(name: "BeeminderModel")
    let description = NSPersistentStoreDescription(url: storeURL)
    container.persistentStoreDescriptions = [description]
    let expectation = XCTestExpectation(description: "Load store")
    var loadError: Error?
    container.loadPersistentStores { _, error in
      loadError = error
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 5.0)
    XCTAssertNil(loadError, "Migration should succeed")
    let context = container.viewContext
    let goalRequest = NSFetchRequest<Goal>(entityName: "Goal")
    let goals = try context.fetch(goalRequest)
    XCTAssertEqual(goals.count, 1, "Should have one goal after migration")
    let goal: Goal! = goals.first
    XCTAssertNotNil(goal.autodataConfig, "autodataConfig should not be nil after migration")
    XCTAssertTrue(goal.autodataConfig.isEmpty, "autodataConfig should be empty dict for migrated goals")
  }
}
