// Part of BeeSwift. Copyright Beeminder

import AppIntents
import BeeKit
import Foundation
import UIKit

struct OpenGoalIntent: AppIntent, OpenIntent {
  static var title: LocalizedStringResource = "Open Goal"
  static var description = IntentDescription("Open Beeminder app to view a specific goal")

  @Parameter(title: "Goal") var target: GoalEntity

  static var parameterSummary: some ParameterSummary { Summary("Open \(\.$target) in Beeminder") }

  func perform() async throws -> some IntentResult {
    await MainActor.run {
      NotificationCenter.default.post(
        name: GalleryViewController.NotificationName.openGoal,
        object: nil,
        userInfo: ["slug": target.slug]
      )
    }
    return .result()
  }
}
