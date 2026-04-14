//
//  GoalManager.swift
//  BeeSwift
//
//  Created by Theo Spears on 2/7/23.
//  Copyright 2023 APB. All rights reserved.
//

import CoreData
import CoreDataEvolution
import Foundation
import OSLog
import OrderedCollections
import SwiftyJSON

@NSModelActor(disableGenerateInit: true) public actor GoalManager {
  private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "GoalManager")

  private let requestManager: RequestManager
  private nonisolated let currentUserManager: CurrentUserManager

  private var queuedGoalsBackgroundTaskRunning: Bool = false

  init(requestManager: RequestManager, currentUserManager: CurrentUserManager, container: BeeminderPersistentContainer)
  {
    modelContainer = container
    let context = container.newBackgroundContext()
    context.name = "GoalManager"
    modelExecutor = .init(context: context)

    self.requestManager = requestManager
    self.currentUserManager = currentUserManager

    // Actor setup complete. After this point
    // 1) The constructor is complete, so other methods may be called (which means observers can be added)
    // 2) Other methods may be called with the actor executor, so it is no longer safe for the constructor to
    //    access class properties.

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(self.onSignedOutNotification),
      name: CurrentUserManager.NotificationName.signedOut,
      object: nil
    )
  }

  /// Return the state of goals the last time they were fetched from the server. This could have been an arbitrarily long time ago.
  public nonisolated func staleGoals(context: NSManagedObjectContext) -> Set<Goal>? {
    guard let user = self.currentUserManager.user(context: context) else { return nil }
    return user.goals
  }

  /// Fetch and return the latest set of goals from the server
  public func refreshGoals() async throws {
    guard let user = self.currentUserManager.user(context: modelContext) else { return }

    let currentModelVersion = modelContainer.managedObjectModel.versionChecksum
    let modelChanged = user.lastFetchedModelVersionLocal != currentModelVersion

    let goalsUnknown = user.goals.count == 0 || user.updatedAt.timeIntervalSince1970 < 24 * 60 * 60
    if goalsUnknown || modelChanged {
      if modelChanged {
        logger.notice(
          "Model version changed from \(user.lastFetchedModelVersionLocal ?? "nil", privacy: .public) to \(currentModelVersion, privacy: .public), forcing full refresh"
        )
      }
      try await refreshGoalsFromScratch(user: user)
    } else {
      try await refreshGoalsIncremental(user: user)
    }

    // Update the stored model version after successful refresh
    if let user = self.currentUserManager.user(context: modelContext) {
      user.lastFetchedModelVersionLocal = currentModelVersion
    }

    try modelContext.save()
    await performPostGoalUpdateBookkeeping()
  }
  /// Perform a full refresh of goals for initial loads
  private func refreshGoalsFromScratch(user: User) async throws {
    logger.notice("Goals unknown, doing full fetch")
    // We must fetch the user object first, and then fetch goals afterwards, to guarantee User.updated_at is
    // a safe timestamp for future fetches without losing data
    guard let getUser = try await requestManager.get(url: "api/v1/users/{username}.json") else {
      throw GoalManagerError.getUserFailed
    }
    let userResponse = JSON(getUser)
    
    guard let getGoals = try await requestManager.get(url: "api/v1/users/{username}/goals.json", parameters: ["emaciated": "true"]) else {
      throw GoalManagerError.getGoalsFailed
    }
    let goalResponse = JSON(getGoals)

    // The user may have logged out during the network operation. If so we have nothing to do
    modelContext.refreshAllObjects()
    guard let user = modelContext.object(with: user.objectID) as? User else { return }
    user.updateToMatch(json: userResponse)
    // Delete all goals which weren't in the response
    if let goalsArray = goalResponse.array {
      let allGoalIds = Set(goalsArray.map { $0["id"].stringValue })
      let goalsToDelete = user.goals.filter { !allGoalIds.contains($0.id) }
      for goal in goalsToDelete { modelContext.delete(goal) }
    }
    try updateGoalsFromJson(goalResponse)
  }
  /// Perform an incremental refresh of goals for regular updates
  private func refreshGoalsIncremental(user: User) async throws {
    logger.notice("Doing incremental update since \(user.updatedAt, privacy: .public)")
    
    guard let getUser = try await requestManager.get(
        url: "api/v1/users/{username}.json",
        parameters: ["diff_since": user.updatedAt.timeIntervalSince1970 + 1, "emaciated": "true"]
      )
    else {
      throw GoalManagerError.getUserFailed
    }
    
    let userResponse = JSON(getUser)
    
    let goalResponse = userResponse["goals"]
    let deletedGoals = userResponse["deleted_goals"]
    // The user may have logged out during the network operation. If so we have nothing to do
    modelContext.refreshAllObjects()
    guard let user = modelContext.object(with: user.objectID) as? User else { return }
    user.updateToMatch(json: userResponse)
    // Delete all goals marked as deleted
    let deletedGoalIds = Set(deletedGoals.arrayValue.map { $0["id"].stringValue })
    let goalsToDelete = user.goals.filter { deletedGoalIds.contains($0.id) }
    for goal in goalsToDelete { modelContext.delete(goal) }
    try updateGoalsFromJson(goalResponse)
    // Update lastUpdatedLocal for all goals, even those not in response
    let now = Date()
    for goal in user.goals { goal.lastUpdatedLocal = now }
  }
  public func refreshGoal(_ goalID: NSManagedObjectID) async throws {
    guard
      let goal = try modelContext.existingObject(with: goalID) as? Goal
    else {
      throw GoalManagerError.refreshGoalFailed(goalID: goalID, reason: "goal not found")
    }
    guard let responseObject = try await requestManager.get(
      url: "/api/v1/users/\(goal.owner.username)/goals/\(goal.slug)",
      parameters: ["datapoints_count": "5", "emaciated": "true"]
    ) else {
      throw GoalManagerError.getGoalFailed(goalname: goal.slug, goalID: goal.id)
    }
    let goalJSON = JSON(responseObject)
    // The goal may have changed during the network operation, reload latest version
    modelContext.refresh(goal, mergeChanges: false)
    goal.updateToMatch(json: goalJSON)
    try modelContext.save()
    await performPostGoalUpdateBookkeeping()
  }
  public func forceAutodataRefresh(_ goal: Goal) async throws {
    let _ = try await requestManager.get(
      url: "/api/v1/users/\(goal.owner.username)/goals/\(goal.slug)/refresh_graph.json"
    )
  }

  private func updateGoalsFromJson(_ responseJSON: JSON) throws {
    guard let responseGoals = responseJSON.array else {
      logger.error("responseJSON apparently not array")
      return
    }

    guard let user = self.currentUserManager.user(context: modelContext) else {
      logger.info("The user may have logged out while waiting for the data, so ignore if so")
      return
    }

    // Create and update existing goals
    for goalJSON in responseGoals {
      guard let goalId = goalJSON["id"].string else {
        logger.error("goalJSON missing id")
        continue
      }
      let request = NSFetchRequest<Goal>(entityName: "Goal")
      request.predicate = NSPredicate(format: "id == %@", goalId)

      if let existingGoal = try modelContext.fetch(request).first {
        existingGoal.updateToMatch(json: goalJSON)
      } else {
        _ = Goal(context: modelContext, owner: user, json: goalJSON)
      }
    }

    // Remove any deleted goals
    // FIXME: We need to consult the deleted goal array for this
  }

  private func performPostGoalUpdateBookkeeping() async {
    Task {
      // Note this call can be re-entrant, but that is fine as our protection against multiple running
      // copies will make it a no-op
      await pollQueuedGoalsUntilUpdated()
    }
  }

  private func pollQueuedGoalsUntilUpdated() async {
    // Beeminder performs some goal updates asynchronously, and thus API calls are
    // not guaranteed to immediately read their own writes. To indicate this state a "queued"
    // property is set on goals. When we have goals in this state we should poll any relevant
    // goals until no longer marked as queued.

    // Run only a single version of this background polling task at a time
    if queuedGoalsBackgroundTaskRunning { return }
    queuedGoalsBackgroundTaskRunning = true

    do {
      while true {
        // If there are no queued goals then we are complete and can stop checking
        guard let user = currentUserManager.user(context: modelContext) else { break }
        modelContext.refresh(user, mergeChanges: false)
        let queuedGoals = user.goals.filter { $0.queued }
        if queuedGoals.isEmpty { break }

        // Refetch data for all queued goals
        try await withThrowingTaskGroup(of: Void.self) { group in
          for goal in queuedGoals { group.addTask { try await self.refreshGoal(goal.objectID) } }
          try await group.waitForAll()
        }

        // Allow the server time to process, and avoid polling too often
        try await Task.sleep(nanoseconds: 2_000_000_000)
      }
    } catch { logger.error("Error while updating queued goals: \(error)") }

    // In order for the actor to correctly guarantee no race conditions, we must not await between when we check
    // for any queued goals, and when we mark ourselves as no longer running. We must also always clear this when
    // ending the loop, even on error.
    queuedGoalsBackgroundTaskRunning = false
  }

  // MARK: Sign out

  @objc private nonisolated func onSignedOutNotification() { Task { await self.resetStateForSignOut() } }

  private func resetStateForSignOut() {
    // TODO: Delete from CoreData
  }
}

private extension GoalManager {
  enum GoalManagerError: Error {
    case getUserFailed
    case getGoalsFailed
    case getGoalFailed(goalname: String, goalID: String)
    case refreshGoalFailed(goalID: NSManagedObjectID, reason: String)
  }
}

extension GoalManager.GoalManagerError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .getGoalsFailed:
      return NSLocalizedString("Failed to get goals", comment: "getGoalsFailed")
    case .getUserFailed:
      return NSLocalizedString("Failed to get user", comment: "getUserFailed")
    case .getGoalFailed(let goalname, let goalID):
      return NSLocalizedString("Failed to get goal: \(goalname) with id: \(goalID)", comment: "getGoalFailed")
    case .refreshGoalFailed(let goalID, let reason):
      return NSLocalizedString("Failed to refresh goal: \(goalID) because: \(reason)", comment: "refreshGoalFailed")
    }
  }
}

