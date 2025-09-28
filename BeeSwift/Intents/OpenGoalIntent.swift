// Part of BeeSwift. Copyright Beeminder

import AppIntents
import BeeKit
import Foundation
import UIKit

struct OpenGoalIntent: AppIntent {
  static var title: LocalizedStringResource = "Open Goal"
  static var description = IntentDescription("Open Beeminder app to view a specific goal or the goal gallery")

  @Parameter(title: "Goal") var goal: GoalEntity?
  static var parameterSummary: some ParameterSummary {
    When(\OpenGoalIntent.$goal, .equalTo, nil) {
      Summary("Open Beeminder")
    } otherwise: {
      Summary("Open \(\OpenGoalIntent.$goal) in Beeminder")
    }
  }
  static var openAppWhenRun: Bool = true
  func perform() async throws -> some IntentResult {
    if let goal = goal {
      await MainActor.run {
        NotificationCenter.default.post(
          name: GalleryViewController.NotificationName.openGoal,
          object: nil,
          userInfo: ["slug": goal.slug]
        )
      }
    } else {
      await MainActor.run {
        NotificationCenter.default.post(name: GalleryViewController.NotificationName.navigateToGallery, object: nil)
      }
    }
    return .result()
  }
}
