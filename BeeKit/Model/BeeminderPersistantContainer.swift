import UIKit
import CoreData

class BeeminderPersistentContainer: NSPersistentContainer {

    override open class func defaultDirectoryURL() -> URL {
        let storeURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.beeminder.beeminder")
        return storeURL!
    }

}
