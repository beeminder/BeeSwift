import XCTest
import CoreData
@testable import BeeKit

class MigrationTests: XCTestCase {
    
    override func tearDown() {
        super.tearDown()
        // Clean up any test files
        cleanupTestFiles()
    }
    
    // MARK: - Helper Methods
    
    private func cleanupTestFiles() {
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
        let storeURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("TestMigration_\(UUID().uuidString).sqlite")
        
        // Register needed value transformers
        DueByTableValueTransformer.register()
        
        // Load the old model version
        let bundle = Bundle(for: BeeminderPersistentContainer.self)
        guard let oldVersionURL = bundle.url(forResource: "BeeminderModel", withExtension: "mom", subdirectory: "BeeminderModel.momd"),
              let oldModel = NSManagedObjectModel(contentsOf: oldVersionURL) else {
            XCTFail("Failed to load old data model")
            fatalError()
        }
        
        // Create store with old model
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: oldModel)
        
        do {
            try coordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: storeURL,
                options: [:]
            )
            
            let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
            context.persistentStoreCoordinator = coordinator
            
            // Create minimal test data with specific dates
            let testDates = [
                "user": Date(timeIntervalSince1970: 1600000000),      // Sep 13, 2020
                "goal": Date(timeIntervalSince1970: 1610000000),      // Jan 7, 2021
                "datapoint": Date(timeIntervalSince1970: 1620000000)  // May 3, 2021
            ]
            
            // Create user
            let user = NSEntityDescription.insertNewObject(forEntityName: "User", into: context)
            user.setValue("testuser", forKey: "username")
            user.setValue("America/Los_Angeles", forKey: "timezone")
            user.setValue(false, forKey: "deadbeat")
            user.setValue(Date(), forKey: "updatedAt")
            user.setValue(testDates["user"], forKey: "lastModifiedLocal")
            
            // Create goal with minimal required fields
            let goal = NSEntityDescription.insertNewObject(forEntityName: "Goal", into: context)
            goal.setValue("test-goal", forKey: "slug")
            goal.setValue("Test Goal", forKey: "title")
            goal.setValue("test1", forKey: "id")
            
            // Set required string fields to empty
            for field in ["graphUrl", "thumbUrl", "urgencyKey", "lastTouch", "limSum", "safeSum", "yAxis"] {
                goal.setValue("", forKey: field)
            }
            
            // Set required numeric fields to 0
            for field in ["alertStart", "deadline", "initDay", "leadTime", "pledge", "safeBuf"] {
                goal.setValue(0, forKey: field)
            }
            
            // Set required boolean fields to false
            for field in ["hhmmFormat", "queued", "todayta", "useDefaults", "won"] {
                goal.setValue(false, forKey: field)
            }
            
            goal.setValue(DueByDictionary(), forKey: "dueBy")
            goal.setValue(testDates["goal"], forKey: "lastModifiedLocal")
            goal.setValue(user, forKey: "owner")
            
            // Create datapoint
            let dataPoint = NSEntityDescription.insertNewObject(forEntityName: "DataPoint", into: context)
            dataPoint.setValue("dp1", forKey: "id")
            dataPoint.setValue("2023-01-01", forKey: "daystampRaw")
            dataPoint.setValue(NSDecimalNumber(value: 1.0), forKey: "value")
            dataPoint.setValue(testDates["datapoint"], forKey: "lastModifiedLocal")
            dataPoint.setValue(goal, forKey: "goal")
            
            try context.save()
            
            // Verify data was saved correctly
            let verifyRequest = NSFetchRequest<NSManagedObject>(entityName: "User")
            let savedUsers = try context.fetch(verifyRequest)
            if let savedUser = savedUsers.first {
                let savedDate = savedUser.value(forKey: "lastModifiedLocal") as? Date
                print("Before migration - User lastModifiedLocal: \(String(describing: savedDate))")
            }
            
            return storeURL
        } catch {
            XCTFail("Failed to create store: \(error)")
            fatalError()
        }
    }
    
    // Test that migration from lastModifiedLocal to lastUpdatedLocal works
    func testMigration() throws {
        // Define expected test dates
        let expectedDates = [
            "user": Date(timeIntervalSince1970: 1600000000),      // Sep 13, 2020
            "goal": Date(timeIntervalSince1970: 1610000000),      // Jan 7, 2021
            "datapoint": Date(timeIntervalSince1970: 1620000000)  // May 3, 2021
        ]
        
        // 1. Create a store with the old model
        let storeURL = createStoreWithOldModel()
        
        // 2. Load the store with the current model (which should be v2) to trigger migration
        // Create container using BeeminderPersistentContainer to ensure proper setup
        DueByTableValueTransformer.register() // Ensure transformers are registered
        let container = BeeminderPersistentContainer(name: "BeeminderModel")
        let description = NSPersistentStoreDescription(url: storeURL)
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [description]
        
        // Load store with migration
        let expectation = XCTestExpectation(description: "Load store")
        var loadError: Error?
        
        container.loadPersistentStores { _, error in
            loadError = error
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        XCTAssertNil(loadError, "Migration should succeed")
        
        // 3. Verify migration completed successfully with correct values
        let context = container.viewContext
        
        // Force a refresh to ensure we're seeing migrated data
        context.refreshAllObjects()
        
        // Helper to verify entity migration and value preservation
        func verifyEntityMigration(_ entityName: String, expectedDate: Date) throws {
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            let results = try context.fetch(request)
            
            XCTAssertEqual(results.count, 1, "Should have one \(entityName) after migration")
            
            if let entity = results.first {
                // Verify new attribute exists
                let hasNewAttribute = entity.entity.attributesByName.keys.contains("lastUpdatedLocal")
                XCTAssertTrue(hasNewAttribute, "\(entityName) should have lastUpdatedLocal attribute")
                
                // Verify old attribute name no longer exists
                let hasOldAttribute = entity.entity.attributesByName.keys.contains("lastModifiedLocal")
                XCTAssertFalse(hasOldAttribute, "\(entityName) should not have lastModifiedLocal attribute")
                
                // Verify the value was migrated correctly
                let migratedValue = entity.value(forKey: "lastUpdatedLocal")
                print("\(entityName) - lastUpdatedLocal value: \(String(describing: migratedValue))")
                
                if let migratedDate = migratedValue as? Date {
                    XCTAssertEqual(migratedDate.timeIntervalSince1970, expectedDate.timeIntervalSince1970,
                                 accuracy: 0.001, "\(entityName) date should be preserved during migration")
                } else {
                    XCTFail("\(entityName).lastUpdatedLocal should have migrated date value, but got: \(String(describing: migratedValue))")
                }
            }
        }
        
        // Verify each entity type with its expected date
        try verifyEntityMigration("User", expectedDate: expectedDates["user"]!)
        try verifyEntityMigration("Goal", expectedDate: expectedDates["goal"]!)
        try verifyEntityMigration("DataPoint", expectedDate: expectedDates["datapoint"]!)
    }
}
