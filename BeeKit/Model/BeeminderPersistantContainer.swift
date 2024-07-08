import UIKit
import CoreData

public class BeeminderPersistentContainer: NSPersistentContainer {

    override open class func defaultDirectoryURL() -> URL {
        let storeURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.beeminder.beeminder")
        return storeURL!
    }

}
