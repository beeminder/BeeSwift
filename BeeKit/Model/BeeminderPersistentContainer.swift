import UIKit
import SwiftData
import OSLog

public class BeeminderPersistentContainer {
    private static let logger = Logger(subsystem: "com.beeminder.beeminder", category: "BeeminderPersistentContainer")
//    private var spotlightIndexer: NSCoreDataCoreSpotlightDelegate?


    static func create() -> ModelContainer {
        let schema = Schema([User.self , Goal.self, DataPoint.self])
        let storeURL = URL.applicationSupportDirectory.appending(path: "beeeminder.sqlite")
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        let container = try! ModelContainer(configurations: configuration)

        // Spotlight indexing requires sqlite and history tracking
//        description.type = NSSQLiteStoreType
//        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
//
//        container.loadPersistentStores { description, error in
//            if let error = error {
//                fatalError("Unable to load persistent stores: \(error)")
//            }
//        }
//
//        container.spotlightIndexer = BeeminderSpotlightDelegate(forStoreWith: description, coordinator: container.persistentStoreCoordinator)
//        container.spotlightIndexer?.startSpotlightIndexing()

        return container
    }

    static func createMemoryBackedForTests() -> ModelContainer {
        let schema = Schema([User.self , Goal.self, DataPoint.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(configurations: configuration)

        return container
    }

}
