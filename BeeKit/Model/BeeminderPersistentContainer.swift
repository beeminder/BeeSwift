import CoreData
import OSLog
import UIKit

public class BeeminderPersistentContainer: NSPersistentContainer, @unchecked Sendable {
  private static let logger = Logger(subsystem: "com.beeminder.beeminder", category: "BeeminderPersistentContainer")
  private var spotlightIndexer: NSCoreDataCoreSpotlightDelegate?

  override open class func defaultDirectoryURL() -> URL {
    let storeURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.beeminder.beeminder")
    return storeURL!
  }

  static func create() -> BeeminderPersistentContainer {
    DueByTableValueTransformer.register()
    let container = BeeminderPersistentContainer(name: "BeeminderModel")

    guard let description = container.persistentStoreDescriptions.first else {
      fatalError("Failed to retrieve a persistent store description.")
    }
    // Spotlight indexing requires sqlite and history tracking
    description.type = NSSQLiteStoreType
    description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)

    description.shouldMigrateStoreAutomatically = true
    description.shouldInferMappingModelAutomatically = true

    container.loadPersistentStores { description, error in
      if let error = error { fatalError("Unable to load persistent stores: \(error)") }
    }

    container.viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy

    NotificationCenter.default.addObserver(
      forName: .NSManagedObjectContextDidSave,
      object: nil,
      queue: nil
    ) { notification in
      guard let savedContext = notification.object as? NSManagedObjectContext,
        savedContext !== container.viewContext,
        savedContext.persistentStoreCoordinator === container.persistentStoreCoordinator
      else { return }

      container.viewContext.perform {
        container.viewContext.mergeChanges(fromContextDidSave: notification)
      }
    }

    container.spotlightIndexer = BeeminderSpotlightDelegate(
      forStoreWith: description,
      coordinator: container.persistentStoreCoordinator
    )
    container.spotlightIndexer?.startSpotlightIndexing()

    return container
  }

  static func createMemoryBackedForTests() -> BeeminderPersistentContainer {
    DueByTableValueTransformer.register()
    let container = BeeminderPersistentContainer(name: "BeeminderModel")
    let description = NSPersistentStoreDescription()
    description.type = NSInMemoryStoreType
    container.persistentStoreDescriptions = [description]

    container.loadPersistentStores { (storeDescription, error) in
      if let error = error as NSError? { fatalError("Unresolved error \(error), \(error.userInfo)") }
    }

    return container
  }

}
