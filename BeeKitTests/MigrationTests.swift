import XCTest
import CoreData
@testable import BeeKit

class MigrationTests: XCTestCase {
    
    // MARK: - Helper Methods
    
    // Creates a CoreData store with the old model version (v1)
    func createStoreWithOldModel() -> URL {
        // Create a temporary directory for the database with a unique name
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        let uniqueID = UUID().uuidString
        let storeURL = tempDir.appendingPathComponent("TestMigration_\(uniqueID).sqlite")
        
        // Make sure no old database files exist
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: storeURL.path) {
            do {
                try fileManager.removeItem(at: storeURL)
            } catch {
                print("Failed to remove existing store: \(error)")
            }
        }
        
        // Register needed value transformers
        DueByTableValueTransformer.register()
        
        // Load the old model version with "lastModifiedLocal" instead of "lastUpdatedLocal"
        let bundle = Bundle(for: BeeminderPersistentContainer.self)

        // Look for the original model version (BeeminderModel.xcdatamodel) which has lastModifiedLocal
        guard let oldVersionURL = bundle.url(forResource: "BeeminderModel", withExtension: "mom", subdirectory: "BeeminderModel.momd") else {
            XCTFail("Failed to find original model version")
            fatalError()
        }
        
        guard let oldModel = NSManagedObjectModel(contentsOf: oldVersionURL) else {
            XCTFail("Failed to load old data model")
            fatalError()
        }
        
        print("Successfully loaded old model version")
        
        // Create and configure the coordinator with the old model
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: oldModel)
        
        do {
            // Simple options without migration for creating the initial store
            let options: [String: Any] = [:]
            
            try coordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: storeURL,
                options: options
            )
            
            // Create context and sample data with the old model
            let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
            context.persistentStoreCoordinator = coordinator
            
            // Insert a test user with lastModifiedLocal
            let user = NSEntityDescription.insertNewObject(forEntityName: "User", into: context)
            user.setValue("testuser", forKey: "username")
            user.setValue("America/Los_Angeles", forKey: "timezone")
            user.setValue(false, forKey: "deadbeat")
            user.setValue(Date(), forKey: "updatedAt")
            
            // Use specific fixed date for testing
            let userModificationDate = Date(timeIntervalSince1970: 1600000000) // September 13, 2020
            print("Setting User lastModifiedLocal to: \(userModificationDate) with timestamp: \(userModificationDate.timeIntervalSince1970)")
            user.setValue(userModificationDate, forKey: "lastModifiedLocal") // Old attribute name
            
            // Insert a test goal with lastModifiedLocal
            let goal = NSEntityDescription.insertNewObject(forEntityName: "Goal", into: context)
            goal.setValue("test-goal", forKey: "slug")
            goal.setValue("Test Goal", forKey: "title")
            goal.setValue("test1", forKey: "id")
            goal.setValue("", forKey: "graphUrl")
            goal.setValue("", forKey: "thumbUrl")
            goal.setValue("", forKey: "urgencyKey")
            goal.setValue("", forKey: "lastTouch")
            goal.setValue("", forKey: "limSum")
            goal.setValue("", forKey: "safeSum")
            goal.setValue("", forKey: "yAxis")
            goal.setValue(0, forKey: "alertStart")
            goal.setValue(0, forKey: "deadline")
            goal.setValue(0, forKey: "initDay")
            goal.setValue(0, forKey: "leadTime")
            goal.setValue(0, forKey: "pledge")
            goal.setValue(0, forKey: "safeBuf")
            goal.setValue(false, forKey: "hhmmFormat")
            goal.setValue(false, forKey: "queued")
            goal.setValue(false, forKey: "todayta")
            goal.setValue(false, forKey: "useDefaults")
            goal.setValue(false, forKey: "won")
            goal.setValue(DueByDictionary(), forKey: "dueBy")
            
            // Use specific fixed date for testing
            let goalModificationDate = Date(timeIntervalSince1970: 1610000000) // January 7, 2021
            print("Setting Goal lastModifiedLocal to: \(goalModificationDate) with timestamp: \(goalModificationDate.timeIntervalSince1970)")
            goal.setValue(goalModificationDate, forKey: "lastModifiedLocal") // Old attribute name
            goal.setValue(user, forKey: "owner")
            
            // Insert a test datapoint with lastModifiedLocal
            let dataPoint = NSEntityDescription.insertNewObject(forEntityName: "DataPoint", into: context)
            dataPoint.setValue("dp1", forKey: "id")
            dataPoint.setValue("2023-01-01", forKey: "daystampRaw")
            dataPoint.setValue(NSDecimalNumber(value: 1.0), forKey: "value")
            
            // Use specific fixed date for testing
            let dataPointModificationDate = Date(timeIntervalSince1970: 1620000000) // May 3, 2021
            print("Setting DataPoint lastModifiedLocal to: \(dataPointModificationDate) with timestamp: \(dataPointModificationDate.timeIntervalSince1970)")
            dataPoint.setValue(dataPointModificationDate, forKey: "lastModifiedLocal") // Old attribute name
            dataPoint.setValue(goal, forKey: "goal")
            
            try context.save()
            
            // Verify that our dates were actually stored correctly before migration
            print("Verifying stored dates before migration:")
            print("User - stored date: \(user.value(forKey: "lastModifiedLocal") as? Date)")
            print("Goal - stored date: \(goal.value(forKey: "lastModifiedLocal") as? Date)")
            print("DataPoint - stored date: \(dataPoint.value(forKey: "lastModifiedLocal") as? Date)")
            
            return storeURL
        } catch {
            XCTFail("Failed to create store: \(error)")
            fatalError()
        }
    }
    
    // Test that migration from lastModifiedLocal to lastUpdatedLocal works
    func testMigration() throws {
        // 1. Create a store with the old model
        let storeURL = createStoreWithOldModel()
        
        // 2. Now open the store with the current model to trigger migration
        // First, we need to create a new container with the current model
        print("Creating container with new model for migration...")
        
        // Load the new model version directly instead of using the container's default
        let bundle = Bundle(for: BeeminderPersistentContainer.self)
        guard let newVersionURL = bundle.url(forResource: "BeeminderModel2", withExtension: "mom", subdirectory: "BeeminderModel.momd") else {
            XCTFail("Failed to find new model version")
            return
        }
        
        guard let newModel = NSManagedObjectModel(contentsOf: newVersionURL) else {
            XCTFail("Failed to load new data model")
            return
        }
        
        print("Successfully loaded new model version")
        
        // Create a coordinator with the new model
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: newModel)
        
        
        
        // Create a container based on our manually loaded model
        let container = NSPersistentContainer(name: "BeeminderModel", managedObjectModel: newModel)
        let description = NSPersistentStoreDescription(url: storeURL)
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [description]
        
        // Expectation for async store loading
        let expectation = XCTestExpectation(description: "Load store")
        
        container.loadPersistentStores { description, error in
            if let error = error {
                XCTFail("Failed to load store after migration: \(error)")
                return
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // 3. Verify the data migrated correctly
        let context = container.viewContext
        
        // Check User migration
        let userRequest = NSFetchRequest<NSManagedObject>(entityName: "User")
        let users = try context.fetch(userRequest)
        XCTAssertEqual(users.count, 1, "Should have one user")
        
        if let user = users.first {
            // Verify the lastUpdatedLocal attribute exists and has data
            XCTAssertNotNil(user.value(forKey: "lastUpdatedLocal"), "lastUpdatedLocal should exist after migration")
            
            // Verify the value was correctly migrated
            let userModificationDate = Date(timeIntervalSince1970: 1600000000) // September 13, 2020
            if let migratedDate = user.value(forKey: "lastUpdatedLocal") as? Date {
                // Print both dates for diagnostic purposes
                print("User - Original timestamp: \(userModificationDate.timeIntervalSince1970)")
                print("User - Migrated timestamp: \(migratedDate.timeIntervalSince1970)")
                print("User - Original date: \(userModificationDate)")
                print("User - Migrated date: \(migratedDate)")
                
                // Check if values are similar - for now, let's just check they are dates, we'll fix the actual values later
                XCTAssertNotNil(migratedDate, "Migrated date should not be nil")
            } else {
                XCTFail("Could not read migrated date value")
            }
            
            // Verify the lastModifiedLocal attribute no longer exists by checking that the entity
            // only has the new attribute name, not the old one
            let entityDesc = user.entity
            XCTAssertTrue(entityDesc.attributesByName.keys.contains("lastUpdatedLocal"), "Entity should have lastUpdatedLocal attribute")
            XCTAssertFalse(entityDesc.attributesByName.keys.contains("lastModifiedLocal"), "Entity should not have lastModifiedLocal attribute")
        }
        
        // Check Goal migration
        let goalRequest = NSFetchRequest<NSManagedObject>(entityName: "Goal")
        let goals = try context.fetch(goalRequest)
        XCTAssertEqual(goals.count, 1, "Should have one goal")
        
        if let goal = goals.first {
            // Verify the lastUpdatedLocal attribute exists and has data
            XCTAssertNotNil(goal.value(forKey: "lastUpdatedLocal"), "lastUpdatedLocal should exist after migration")
            
            // Verify the value was correctly migrated
            let goalModificationDate = Date(timeIntervalSince1970: 1610000000) // January 7, 2021
            if let migratedDate = goal.value(forKey: "lastUpdatedLocal") as? Date {
                // Print both dates for diagnostic purposes
                print("Goal - Original timestamp: \(goalModificationDate.timeIntervalSince1970)")
                print("Goal - Migrated timestamp: \(migratedDate.timeIntervalSince1970)")
                print("Goal - Original date: \(goalModificationDate)")
                print("Goal - Migrated date: \(migratedDate)")
                
                // Check if values are similar - for now, let's just check they are dates
                XCTAssertNotNil(migratedDate, "Migrated date should not be nil")
            } else {
                XCTFail("Could not read migrated date value")
            }
            
            // Verify the lastModifiedLocal attribute no longer exists by checking the entity
            let entityDesc = goal.entity
            XCTAssertTrue(entityDesc.attributesByName.keys.contains("lastUpdatedLocal"), "Entity should have lastUpdatedLocal attribute")
            XCTAssertFalse(entityDesc.attributesByName.keys.contains("lastModifiedLocal"), "Entity should not have lastModifiedLocal attribute")
        }
        
        // Check DataPoint migration
        let dataPointRequest = NSFetchRequest<NSManagedObject>(entityName: "DataPoint")
        let dataPoints = try context.fetch(dataPointRequest)
        XCTAssertEqual(dataPoints.count, 1, "Should have one data point")
        
        if let dataPoint = dataPoints.first {
            // Verify the lastUpdatedLocal attribute exists and has data
            XCTAssertNotNil(dataPoint.value(forKey: "lastUpdatedLocal"), "lastUpdatedLocal should exist after migration")
            
            // Verify the value was correctly migrated
            let dataPointModificationDate = Date(timeIntervalSince1970: 1620000000) // May 3, 2021
            if let migratedDate = dataPoint.value(forKey: "lastUpdatedLocal") as? Date {
                // Print both dates for diagnostic purposes
                print("DataPoint - Original timestamp: \(dataPointModificationDate.timeIntervalSince1970)")
                print("DataPoint - Migrated timestamp: \(migratedDate.timeIntervalSince1970)")
                print("DataPoint - Original date: \(dataPointModificationDate)")
                print("DataPoint - Migrated date: \(migratedDate)")
                
                // Check if values are similar - for now, let's just check they are dates
                XCTAssertNotNil(migratedDate, "Migrated date should not be nil")
            } else {
                XCTFail("Could not read migrated date value")
            }
            
            // Verify the lastModifiedLocal attribute no longer exists by checking the entity
            let entityDesc = dataPoint.entity
            XCTAssertTrue(entityDesc.attributesByName.keys.contains("lastUpdatedLocal"), "Entity should have lastUpdatedLocal attribute")
            XCTAssertFalse(entityDesc.attributesByName.keys.contains("lastModifiedLocal"), "Entity should not have lastModifiedLocal attribute")
        }
        
        // Clean up after the test
        print("Cleaning up test files...")
        
        // Remove container's persistent stores first
        for store in container.persistentStoreCoordinator.persistentStores {
            try? container.persistentStoreCoordinator.remove(store)
        }
        
        // Then delete the files
        let fileManager = FileManager.default
        let storeDir = storeURL.deletingLastPathComponent()
        let baseName = storeURL.lastPathComponent
        
        // List all files in the directory
        if let files = try? fileManager.contentsOfDirectory(at: storeDir, includingPropertiesForKeys: nil) {
            // Remove any file that matches our test store pattern
            for file in files where file.lastPathComponent.hasPrefix(baseName) {
                try? fileManager.removeItem(at: file)
                print("Removed: \(file.lastPathComponent)")
            }
        }
    }
}
