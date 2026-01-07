// Part of BeeSwift. Copyright Beeminder

import AppIntents
import BeeKit
import CoreData
import Foundation

enum RefreshGoalError: Error, CustomLocalizedStringResourceConvertible {
  case manualGoal
  case goalNotFound
  case refreshFailed(String)

  var localizedStringResource: LocalizedStringResource {
    switch self {
    case .manualGoal: return "This goal doesn't have automatic data. Only goals with autodata can be refreshed."
    case .goalNotFound: return "Could not find the specified goal."
    case .refreshFailed(let message): return "Failed to refresh goal: \(message)"
    }
  }
}

struct RefreshGoalIntent: AppIntent {
  static var title: LocalizedStringResource = "Refresh Goal"
  static var description = IntentDescription(
    "Refresh automatic data for a goal from Apple Health or other connected services"
  )

  @Parameter(title: "Goal") var goal: GoalEntity

  static var parameterSummary: some ParameterSummary { Summary("Refresh \(\.$goal)") }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    // Fetch the Goal from CoreData
    let container = ServiceLocator.persistentContainer
    let context = container.viewContext

    let goalObject = try await context.perform {
      let request = NSFetchRequest<Goal>(entityName: "Goal")
      request.predicate = NSPredicate(format: "id == %@", goal.id)
      request.fetchLimit = 1
      guard let result = try context.fetch(request).first else { throw RefreshGoalError.goalNotFound }
      return result
    }

    // Check if goal has autodata
    guard let autodata = goalObject.autodata, !autodata.isEmpty else { throw RefreshGoalError.manualGoal }

    do {
      if autodata == "apple" {
        // Apple Health goal - fetch from HealthKit
        try await ServiceLocator.healthStoreManager.updateWithRecentData(goalID: goalObject.objectID, days: 7)
      } else {
        // Other autodata (IFTTT, API, etc.) - server-side refresh
        try await ServiceLocator.goalManager.forceAutodataRefresh(goalObject)
        try await ServiceLocator.goalManager.refreshGoal(goalObject.objectID)
      }
      return .result(dialog: "Refreshed \(goal.slug)")
    } catch { throw RefreshGoalError.refreshFailed(error.localizedDescription) }
  }
}
