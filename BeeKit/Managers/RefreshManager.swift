// Part of BeeSwift. Copyright Beeminder

import CoreData
import Foundation
import OSLog

public enum RefreshError: Error {
  case goalNotFound
  case manualGoal
}

public class RefreshManager {
  private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "RefreshManager")
  private let healthStoreManager: HealthStoreManager
  private let goalManager: GoalManager
  private let container: NSPersistentContainer

  public init(healthStoreManager: HealthStoreManager, goalManager: GoalManager, container: NSPersistentContainer) {
    self.healthStoreManager = healthStoreManager
    self.goalManager = goalManager
    self.container = container
  }

  /// Refresh autodata for a single goal from Apple Health or server.
  /// Throws RefreshError.manualGoal if the goal has no autodata source.
  public func refreshGoalAutodata(_ goalID: NSManagedObjectID) async throws {
    let context = container.viewContext
    let (autodata, isHealthKit) = try await context.perform {
      guard let goal = try? context.existingObject(with: goalID) as? Goal else { throw RefreshError.goalNotFound }
      return (goal.autodata, goal.isLinkedToHealthKit)
    }

    guard let autodata, !autodata.isEmpty else { throw RefreshError.manualGoal }

    if isHealthKit {
      try await healthStoreManager.updateWithRecentData(goalID: goalID, days: 7)
    } else {
      // Server-side autodata (IFTTT, API, etc.)
      let goal = try await context.perform { try context.existingObject(with: goalID) as! Goal }
      try await goalManager.forceAutodataRefresh(goal)
      try await goalManager.refreshGoal(goalID)
    }
  }

  @MainActor public func refreshGoalsAndHealthKitData() async {
    await withTaskGroup(of: Void.self) { group in
      group.addTask {
        do { let _ = try await self.healthStoreManager.updateAllGoalsWithRecentData(days: 7) } catch {
          self.logger.error("Error updating from healthkit: \(error)")
        }
      }
      group.addTask {
        do { try await self.goalManager.refreshGoals() } catch { self.logger.error("Error refreshing goals: \(error)") }
      }
    }
  }
}
