// Part of BeeSwift. Copyright Beeminder

import AppIntents
import BeeKit
import CoreSpotlight
import Foundation

struct GoalEntity: AppEntity, IndexedEntity, Equatable {
  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Goal"
  static var defaultQuery = GoalEntityQuery()
  var id: String
  @Property(title: "Slug") var slug: String
  @Property(title: "Title") var title: String
  var thumbUrl: String?
  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: "\(displayTitle)", subtitle: "\(slug)")
  }
  var displayTitle: String { return title.isEmpty ? slug : title }

  var attributeSet: CSSearchableItemAttributeSet {
    let attributes = defaultAttributeSet
    attributes.displayName = slug
    attributes.contentDescription = title
    return attributes
  }
  init(id: String, slug: String, title: String, thumbUrl: String? = nil) {
    self.id = id
    self.slug = slug
    self.title = title
    self.thumbUrl = thumbUrl
  }
  init(from goal: Goal) {
    self.id = goal.id
    self.slug = goal.slug
    self.title = goal.title
    self.thumbUrl = goal.thumbUrl
  }

  static func == (lhs: GoalEntity, rhs: GoalEntity) -> Bool {
    return lhs.id == rhs.id && lhs.slug == rhs.slug && lhs.title == rhs.title && lhs.thumbUrl == rhs.thumbUrl
  }
}
