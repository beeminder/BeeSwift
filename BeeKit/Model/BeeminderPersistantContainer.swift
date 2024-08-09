import UIKit
import CoreData
import OSLog

public class BeeminderPersistentContainer: NSPersistentContainer {
    private static let logger = Logger(subsystem: "com.beeminder.beeminder", category: "BeeminderPersistentContainer")

    override open class func defaultDirectoryURL() -> URL {
        let storeURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.beeminder.beeminder")
        return storeURL!
    }

    static func create() -> BeeminderPersistentContainer {
        let container = BeeminderPersistentContainer(name: "BeeminderModel")
        container.loadPersistentStores { description, error in
            if let error = error {
                logger.error("Unable to load persistent stores: \(error, privacy: .public)")
                // TODO: Reconsider this approach after we use this data for real
                for storeDescription in container.persistentStoreDescriptions {
                    if let url = storeDescription.url {
                        try! FileManager.default.removeItem(at: url)
                    } else {
                        logger.warning("No URL for store description: \(storeDescription, privacy: .public)")
                    }
                }
                container.loadPersistentStores { description, error in
                    if let error = error {
                        fatalError("Unable to load persistent stores on retry: \(error)")
                    }
                }
            }
        }
        return container
    }

    static func createMemoryBackedForTests() -> BeeminderPersistentContainer {
        let container = BeeminderPersistentContainer(name: "BeeminderModel")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }

        return container
    }

}
