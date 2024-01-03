import UIKit
import CoreData

class BeeminderPersistentContainer: NSPersistentContainer {

    override open class func defaultDirectoryURL() -> URL {
        var storeURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.beeminder.beeminder")
        storeURL = storeURL?.appendingPathComponent("beeminder.sqlite")
        return storeURL!
    }

}
