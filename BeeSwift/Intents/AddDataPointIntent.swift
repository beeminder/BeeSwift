// Part of BeeSwift. Copyright Beeminder

import AppIntents
import BeeKit
import Foundation

struct AddDataPointIntent: AppIntent {
  static var title: LocalizedStringResource = "Add Datapoint"
  static var description = IntentDescription("Add a datapoint to a Beeminder goal")
  @Parameter(title: "Goal") var goal: GoalEntity
  @Parameter(title: "Value") var value: Double
  @Parameter(title: "Comment", default: "Added via iOS Shortcut") var comment: String?
  static var parameterSummary: some ParameterSummary { Summary("Add \(\.$value) to \(\.$goal)") { \.$comment } }
  func perform() async throws -> some IntentResult & ProvidesDialog {
    let dataComment = comment ?? ""
    do {
      guard let username = await ServiceLocator.currentUserManager.username else { throw AddDataError.noUser }
      let urtext = "^ \(value) \"\(dataComment)\""
      let _ = try await ServiceLocator.requestManager.request(
        endpoint: .createDatapoint(username: username, goalname: goal.slug, urtext: urtext)
      )
      // Use displayTitle to show title with slug fallback
      let formatter = NumberFormatter()
      formatter.minimumFractionDigits = 0
      formatter.maximumFractionDigits = 5
      let formattedValue = formatter.string(from: NSNumber(value: value)) ?? String(value)
      return .result(dialog: "Added \(formattedValue) to \(goal.displayTitle)")
    } catch ServerError.notFound { throw AddDataError.apiError("Goal '\(goal.slug)' not found") } catch {
      throw AddDataError.apiError(error.localizedDescription)
    }
  }
}
