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
  /// The number of safe days before derailing. Zero means it's a beemergency.
  @Property(title: "Safe Days") var safeBuf: Int
  /// Whether any datapoints have been entered for today.
  @Property(title: "Has Data Today") var todayta: Bool
  /// The amount pledged (USD) on the goal.
  @Property(title: "Pledge") var pledge: Int
  /// Summary of what's needed to stay on track, e.g., "+2 within 1 day".
  @Property(title: "Required Action") var limSum: String
  /// Whether the goal has been successfully completed.
  @Property(title: "Completed") var won: Bool
  /// The name of the automatic data source (e.g., "apple"), or nil for manual goals.
  @Property(title: "Data Source") var autodata: String?
  var thumbUrl: String?
  var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(slug)", subtitle: "\(title)") }
  var displayTitle: String { return slug }

  var attributeSet: CSSearchableItemAttributeSet {
    let attributes = defaultAttributeSet
    attributes.displayName = displayTitle
    attributes.contentDescription = title
    return attributes
  }

  init(
    id: String,
    slug: String,
    title: String,
    safeBuf: Int = 0,
    todayta: Bool = false,
    pledge: Int = 0,
    limSum: String = "",
    won: Bool = false,
    autodata: String? = nil,
    thumbUrl: String? = nil
  ) {
    self.id = id
    self.slug = slug
    self.title = title
    self.safeBuf = safeBuf
    self.todayta = todayta
    self.pledge = pledge
    self.limSum = limSum
    self.won = won
    self.autodata = autodata
    self.thumbUrl = thumbUrl
  }

  init(from goal: Goal) {
    self.id = goal.id
    self.slug = goal.slug
    self.title = goal.title
    self.safeBuf = goal.safeBuf
    self.todayta = goal.todayta
    self.pledge = goal.pledge
    self.limSum = goal.limSum
    self.won = goal.won
    self.autodata = goal.autodata
    self.thumbUrl = goal.thumbUrl
  }

  static func == (lhs: GoalEntity, rhs: GoalEntity) -> Bool {
    return lhs.id == rhs.id && lhs.slug == rhs.slug && lhs.title == rhs.title && lhs.safeBuf == rhs.safeBuf
      && lhs.todayta == rhs.todayta && lhs.pledge == rhs.pledge && lhs.limSum == rhs.limSum && lhs.won == rhs.won
      && lhs.autodata == rhs.autodata && lhs.thumbUrl == rhs.thumbUrl
  }
}
