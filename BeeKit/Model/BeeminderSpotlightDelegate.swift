import CoreData
import CoreSpotlight
import Foundation

class BeeminderSpotlightDelegate: NSCoreDataCoreSpotlightDelegate {

  override func attributeSet(for object: NSManagedObject) -> CSSearchableItemAttributeSet? {
    if let goal = object as? Goal {
      let attributeSet = CSSearchableItemAttributeSet(contentType: .content)
      attributeSet.identifier = goal.slug
      attributeSet.displayName = goal.slug
      attributeSet.contentDescription = goal.title
      return attributeSet
    }
    return nil
  }
}
