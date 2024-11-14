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

        return container
    }

    static func createMemoryBackedForTests() -> ModelContainer {
        let schema = Schema([User.self , Goal.self, DataPoint.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(configurations: configuration)

        return container
    }

}
