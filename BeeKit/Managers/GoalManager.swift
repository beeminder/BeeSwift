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

  public enum NotificationName {
    /// A notification that is triggered any time the data for one or more goals is updated
    public static let goalsUpdated = NSNotification.Name(rawValue: "com.beeminder.goalsUpdatedNotification")
  }
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
    let goalsUnknown = user.goals.count == 0 || user.updatedAt.timeIntervalSince1970 < 24 * 60 * 60
    if goalsUnknown {
      try await refreshGoalsFromScratch(user: user)
    } else {
      try await refreshGoalsIncremental(user: user)
    }
    try modelContext.save()
    await performPostGoalUpdateBookkeeping()
  }
  /// Perform a full refresh of goals for initial loads
  private func refreshGoalsFromScratch(user: User) async throws {
    logger.notice("Goals unknown, doing full fetch")
    // We must fetch the user object first, and then fetch goals afterwards, to guarantee User.updated_at is
    // a safe timestamp for future fetches without losing data
    let userResponse = JSON(try await requestManager.get(url: "api/v1/users/{username}.json")!)
    let goalResponse = JSON(
      try await requestManager.get(url: "api/v1/users/{username}/goals.json", parameters: ["emaciated": "true"])!
    )

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
    updateGoalsFromJson(goalResponse)
  }
  /// Perform an incremental refresh of goals for regular updates
  private func refreshGoalsIncremental(user: User) async throws {
    logger.notice("Doing incremental update since \(user.updatedAt, privacy: .public)")
    let userResponse = JSON(
      try await requestManager.get(
        url: "api/v1/users/{username}.json",
        parameters: ["diff_since": user.updatedAt.timeIntervalSince1970 + 1, "emaciated": "true"]
      )!
    )
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
    updateGoalsFromJson(goalResponse)
    // Update lastUpdatedLocal for all goals, even those not in response
    let now = Date()
    for goal in user.goals { goal.lastUpdatedLocal = now }
  }

  public func refreshGoal(_ goalID: NSManagedObjectID) async throws {
    let goal = try modelContext.existingObject(with: goalID) as! Goal

    let responseObject = try await requestManager.get(
      url: "/api/v1/users/\(currentUserManager.username!)/goals/\(goal.slug)",
      parameters: ["datapoints_count": "5", "emaciated": "true"]
    )
    let goalJSON = JSON(responseObject!)

    // The goal may have changed during the network operation, reload latest version
    modelContext.refresh(goal, mergeChanges: false)
    goal.updateToMatch(json: goalJSON)

    try modelContext.save()

    await performPostGoalUpdateBookkeeping()
  }

  public func forceAutodataRefresh(_ goal: Goal) async throws {
    let _ = try await requestManager.get(
      url: "/api/v1/users/\(currentUserManager.username!)/goals/\(goal.slug)/refresh_graph.json"
    )
  }

  private func updateGoalsFromJson(_ responseJSON: JSON) {
    guard let responseGoals = responseJSON.array else { return }

    // The user may have logged out while waiting for the data, so ignore if so
    guard let user = self.currentUserManager.user(context: modelContext) else { return }

    // Create and update existing goals
    for goalJSON in responseGoals {
      let goalId = goalJSON["id"].stringValue
      let request = NSFetchRequest<Goal>(entityName: "Goal")
      request.predicate = NSPredicate(format: "id == %@", goalId)
      // TODO: Better error handling of failure here?
      if let existingGoal = try! modelContext.fetch(request).first {
        existingGoal.updateToMatch(json: goalJSON)
      } else {
        let _ = Goal(context: modelContext, owner: user, json: goalJSON)
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

    // Notify all listeners of the update
    await Task { @MainActor in
      modelContainer.viewContext.refreshAllObjects()
      NotificationCenter.default.post(name: GoalManager.NotificationName.goalsUpdated, object: self)
    }.value
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
