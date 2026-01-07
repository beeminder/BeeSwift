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
    // Fetch the Goal from CoreData to get objectID
    let container = ServiceLocator.persistentContainer
    let context = container.viewContext

    let goalID = try await context.perform {
      let request = NSFetchRequest<Goal>(entityName: "Goal")
      request.predicate = NSPredicate(format: "id == %@", goal.id)
      request.fetchLimit = 1
      guard let result = try context.fetch(request).first else { throw RefreshGoalError.goalNotFound }
      return result.objectID
    }

    do {
      try await ServiceLocator.refreshManager.refreshGoalAutodata(goalID)
      return .result(dialog: "Refreshed \(goal.slug)")
    } catch RefreshError.manualGoal { throw RefreshGoalError.manualGoal } catch RefreshError.goalNotFound {
      throw RefreshGoalError.goalNotFound
    } catch { throw RefreshGoalError.refreshFailed(error.localizedDescription) }
  }
}
