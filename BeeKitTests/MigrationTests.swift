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
  // Creates a CoreData store with an old model version (defaults to v1, "BeeminderModel")
  private func createStoreWithOldModel(version: String = "BeeminderModel") -> URL {
    // v1 named the local-modification timestamp `lastModifiedLocal`; it was renamed in v2.
    let lastUpdatedKey = version == "BeeminderModel" ? "lastModifiedLocal" : "lastUpdatedLocal"
    let storeURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(
      "TestMigration_\(UUID().uuidString).sqlite"
    )
    // Register needed value transformers
    DueByTableValueTransformer.register()
    // Load the old model version
    let bundle = Bundle(for: BeeminderPersistentContainer.self)
    guard
      let oldVersionURL = bundle.url(forResource: version, withExtension: "mom", subdirectory: "BeeminderModel.momd"),
      let oldModel = NSManagedObjectModel(contentsOf: oldVersionURL)
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
      user.setValue(TestData.userLastModified, forKey: lastUpdatedKey)

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
      goal.setValue(TestData.goalLastModified, forKey: lastUpdatedKey)
      goal.setValue(user, forKey: "owner")
      // Create datapoint
      let dataPoint = NSEntityDescription.insertNewObject(forEntityName: "DataPoint", into: context)
      dataPoint.setValue("dp1", forKey: "id")
      dataPoint.setValue("20230101", forKey: "daystampRaw")
      dataPoint.setValue(NSDecimalNumber(value: 1.0), forKey: "value")
      dataPoint.setValue(TestData.dataPointLastModified, forKey: lastUpdatedKey)
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
        "User date value should be preserved during migration",
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
        "Goal date value should be preserved during migration",
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
        "DataPoint date value should be preserved during migration",
      )
    }
  }
  // Shipped model versions must never be edited in place: Core Data locates a store's source model by
  // matching its version hashes against the bundled versions, so changing a shipped version means
  // existing stores no longer match anything and `loadPersistentStores` fails ("Can't find model for
  // source store"). Schema changes go in a new version. These checksums are the ones Xcode prints at
  // build time (they are what `GoalManager` compares to force a full refresh after a model change).
  func testShippedModelVersionsAreUnchanged() throws {
    let shippedChecksums = [
      "BeeminderModel": "Z6+a9G/hRxFiCm6y8ogfqoWpYvVUbDA7WmLpeKtwD00=",
      "BeeminderModel2": "0LI7wEnFZnYJFWYS3TGErsHhIZofUp7xrJ/1pg7XQvE=",
      "BeeminderModel3": "DS6ijiKCKtwHb87IGYWZDkBXvlu0COQmp0MUhjFWWkI=",
    ]
    let bundle = Bundle(for: BeeminderPersistentContainer.self)
    for (version, checksum) in shippedChecksums {
      let url = try XCTUnwrap(
        bundle.url(forResource: version, withExtension: "mom", subdirectory: "BeeminderModel.momd")
      )
      let model = try XCTUnwrap(NSManagedObjectModel(contentsOf: url))
      XCTAssertEqual(
        model.versionChecksum,
        checksum,
        "\(version) has shipped and must not change; add a new model version for schema changes",
      )
    }
  }
  // Model version 3 shipped (6.8 stores were created with it), so the current model must be reachable
  // from it by lightweight migration, with the new `svgUrl` attribute taking its default.
  func testMigrationFromModelVersion3() throws {
    DueByTableValueTransformer.register()

    let storeURL = createStoreWithOldModel(version: "BeeminderModel3")
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
    XCTAssertNil(loadError, "Migration from model version 3 should succeed")
    let context = container.viewContext
    let goals = try context.fetch(NSFetchRequest<Goal>(entityName: "Goal"))
    XCTAssertEqual(goals.count, 1, "Should have one goal after migration")
    let goal: Goal! = goals.first
    XCTAssertEqual(goal.slug, "test-goal")
    XCTAssertEqual(goal.svgUrl, "", "svgUrl should default to empty for migrated goals")
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
