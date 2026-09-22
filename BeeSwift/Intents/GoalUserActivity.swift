// Part of BeeSwift. Copyright Beeminder

import AppIntents
import BeeKit
import Foundation

extension NSUserActivity {
  static let viewingGoalActivityType = "com.beeminder.beeminder.viewGoal"

  /// The entity is resolved by id at request time, so the activity need not be refreshed when
  /// the goal changes.
  @MainActor static func viewingGoal(_ goal: Goal) -> NSUserActivity {
    let activity = NSUserActivity(activityType: viewingGoalActivityType)
    activity.title = goal.slug
    activity.userInfo = ["slug": goal.slug]
    activity.requiredUserInfoKeys = ["slug"]
    activity.webpageURL = DeeplinkGenerator.generateDeepLinkToGoal(username: goal.owner.username, goalName: goal.slug)
    activity.appEntityIdentifier = GoalEntity.identifier(for: goal)
    return activity
  }
}
