//
//  GoalManager.swift
//  BeeSwift
//
//  Created by Theo Spears on 2/7/23.
//  Copyright © 2023 APB. All rights reserved.
//

import Foundation
import CoreData
import SwiftyJSON
import OSLog
import OrderedCollections


public actor GoalManager {
    private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "GoalManager")

    /// A notification that is triggered any time the data for one or more goals is updated
    public static let goalsUpdatedNotificationName = "com.beeminder.goalsUpdatedNotification"

    fileprivate let cachedLastFetchedGoalsKey = "last_fetched_goals"

    private let requestManager: RequestManager
    private let currentUserManager: CurrentUserManager
    private let container: BeeminderPersistentContainer

    public var goalsFetchedAt : Date? = nil

    private var queuedGoalsBackgroundTaskRunning : Bool = false

    init(requestManager: RequestManager, currentUserManager: CurrentUserManager, container: BeeminderPersistentContainer) {
        self.requestManager = requestManager
        self.currentUserManager = currentUserManager
        self.container = container

        // Load any cached goals from previous app invocation
        if let goalJSON = self.cachedLastFetchedGoals() {
            self.updateGoalsFromJson(goalJSON)
        }

        // Actor setup complete. After this point
        // 1) The constructor is complete, so other methods may be called (which means observers can be added)
        // 2) Other methods may be called with the actor executor, so it is no longer safe for the constructor to
        //    access class properties.

        NotificationCenter.default.addObserver(self, selector: #selector(self.onSignedOutNotification), name: NSNotification.Name(rawValue: CurrentUserManager.signedOutNotificationName), object: nil)
    }

    /// Return the state of goals the last time they were fetched from the server. This could have been an arbitrarily long time ago.
    public nonisolated func staleGoals(context: NSManagedObjectContext) -> [Goal]? {
        guard let user = self.currentUserManager.user(context: context) else {
            return nil
        }
        return Array(user.goals)
    }

    /// Fetch and return the latest set of goals from the server
    public func refreshGoals() async throws {
        guard let username = currentUserManager.username else {
            try await currentUserManager.signOut()
            return
        }

        let responseObject = try await requestManager.get(url: "api/v1/users/\(username)/goals.json", parameters: nil)!
        let response = JSON(responseObject)
        self.updateGoalsFromJson(response) // TODO: Return failure info

        self.updateTodayWidget()
        self.goalsFetchedAt = Date()

        self.setCachedLastFetchedGoals(response)

        await performPostGoalUpdateBookkeeping()
    }

    public func refreshGoal(_ goal: Goal) async throws {
        let responseObject = try await requestManager.get(url: "/api/v1/users/\(currentUserManager.username!)/goals/\(goal.slug)?datapoints_count=5", parameters: nil)
        let goalJSON = JSON(responseObject!)
        let goalId = goalJSON["id"].stringValue

        // Update CoreData representation
        let context = container.newBackgroundContext()
        let request = NSFetchRequest<Goal>(entityName: "Goal")
        request.predicate = NSPredicate(format: "id == %@", goalId)
        if let existingGoal = try context.fetch(request).first {
            existingGoal.updateToMatch(json: goalJSON)
        } else {
            logger.warning("Found no existing goal in CoreData store when refreshing \(goal.slug) with id \(goal.id)")
        }
        try context.save()

        await performPostGoalUpdateBookkeeping()
    }

    public func forceAutodataRefresh(_ goal: Goal) async throws {
        let _ = try await requestManager.get(url: "/api/v1/users/\(currentUserManager.username!)/goals/\(goal.slug)/refresh_graph.json", parameters: nil)
    }

    /// Update the set of goals to match those in the provided json. Existing Goal objects will be re-used when they match an ID in the json
    /// This function is nonisolated but should only be called either from isolated contexts or the constructor
    private nonisolated func updateGoalsFromJson(_ responseJSON: JSON) {
        guard let responseGoals = responseJSON.array else {
            return
        }

        //  Update CoreData representation
        let context = container.newBackgroundContext()
        // The user may have logged out while waiting for the data, so ignore if so
        if let user = self.currentUserManager.user(context: context) {

            // Create and update existing goals
            for goalJSON in responseGoals {
                let goalId = goalJSON["id"].stringValue
                let request = NSFetchRequest<Goal>(entityName: "Goal")
                request.predicate = NSPredicate(format: "id == %@", goalId)
                // TODO: Better error handling of failure here?
                if let existingGoal = try! context.fetch(request).first {
                    existingGoal.updateToMatch(json: goalJSON)
                } else {
                    let _ = Goal(context: context, owner: user, json: goalJSON)
                }
            }

            // Remove any deleted goals
            let allGoalIds = Set(responseGoals.map { $0["id"].stringValue })
            let goalsToDelete = user.goals.filter { !allGoalIds.contains($0.id) }
            for goal in goalsToDelete {
                context.delete(goal)
            }

            // Crash on save failure so we can learn about issues via testflight
            try! context.save()
        }
    }

    private func performPostGoalUpdateBookkeeping() async {
        Task {
            // Note this call can be re-entrant, but that is fine as our protection against multiple running
            // copies will make it a no-op
            await pollQueuedGoalsUntilUpdated()
        }

        // Notify all listeners of the update
        await Task { @MainActor in
            container.viewContext.refreshAllObjects()
            NotificationCenter.default.post(name: Notification.Name(rawValue: GoalManager.goalsUpdatedNotificationName), object: self)
        }.value
    }

    private func pollQueuedGoalsUntilUpdated() async {
        // Beeminder performs some goal updates asynchronously, and thus API calls are
        // not guaranteed to immediately read their own writes. To indicate this state a "queued"
        // property is set on goals. When we have goals in this state we should poll any relevant
        // goals until no longer marked as queued.

        // Run only a single version of this background polling task at a time
        if queuedGoalsBackgroundTaskRunning {
            return
        }
        queuedGoalsBackgroundTaskRunning = true

        do {
            while true {
                // If there are no queued goals then we are complete and can stop checking
                guard let user = currentUserManager.user() else { break }
                let queuedGoals = user.goals.filter { $0.queued }
                if queuedGoals.isEmpty {
                    break
                }

                // Refetch data for all queued goals
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for goal in queuedGoals {
                        group.addTask {
                            try await self.refreshGoal(goal)
                        }
                    }
                    try await group.waitForAll()
                }

                // Allow the server time to process, and avoid polling too often
                try await Task.sleep(nanoseconds: 2_000_000_000)
            }
        } catch {
            logger.error("Error while updating queued goals: \(error)")
        }

        // In order for the actor to correctly guarantee no race conditions, we must not await between when we check
        // for any queued goals, and when we mark ourselves as no longer running. We must also always clear this when
        // ending the loop, even on error.
        queuedGoalsBackgroundTaskRunning = false
    }

    // MARK: Serialized goal cache

    private func setCachedLastFetchedGoals(_ goals : JSON) {
        currentUserManager.set(goals.rawString()!, forKey: self.cachedLastFetchedGoalsKey)
    }

    /// This function is nonisolated but should only be called either from isolated contexts or the constructor
    private nonisolated func cachedLastFetchedGoals() -> JSON? {
        guard let encodedValue = currentUserManager.userDefaults.object(forKey: cachedLastFetchedGoalsKey) as? String else { return nil }
        return JSON(encodedValue)
    }

    // MARK: Sign out

    @objc
    private nonisolated func onSignedOutNotification() {
        Task {
            await self.resetStateForSignOut()
        }
    }

    private func resetStateForSignOut() {
        self.goalsFetchedAt = Date(timeIntervalSince1970: 0)
        currentUserManager.removeObject(forKey: cachedLastFetchedGoalsKey)

        if let sharedDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier) {
            sharedDefaults.removeObject(forKey: "todayGoalDictionaries")
        }

        // TODO: Delete from CoreData
    }

    // MARK: Today Widget

    private func updateTodayWidget() {
        if let sharedDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier) {
            sharedDefaults.set(self.todayGoalDictionaries(), forKey: "todayGoalDictionaries")

            // We used to explicitly need to pass the access token to the today widget. This is no longer needed
            // but make sure any previously saved value is cleaned up.
            sharedDefaults.removeObject(forKey: "accessToken")
        }
    }

    private func todayGoalDictionaries() -> Array<Any> {
        guard let user = currentUserManager.user() else { return [] }

        let todayGoals = user.goals.map { (goal) in
            let shortSlug = goal.slug.prefix(20)
            let limsum = goal.limSum
            return ["deadline" : goal.deadline, "thumbUrl": goal.cacheBustingThumbUrl, "limSum": "\(shortSlug): \(limsum)", "slug": goal.slug, "hideDataEntry": goal.hideDataEntry()] as [String : Any]
        }
        return Array(todayGoals.prefix(3)) as Array<Any>
    }
}
