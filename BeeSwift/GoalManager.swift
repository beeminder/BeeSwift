//
//  GoalManager.swift
//  BeeSwift
//
//  Created by Theo Spears on 2/7/23.
//  Copyright © 2023 APB. All rights reserved.
//

import Foundation
import SwiftyJSON
import OSLog
import OrderedCollections


actor GoalManager {
    private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "GoalManager")

    /// A notification that is triggered any time the data for one or more goals is updated
    static let goalsUpdatedNotificationName = "com.beeminder.goalsUpdatedNotification"

    fileprivate let cachedLastFetchedGoalsKey = "last_fetched_goals"

    private let requestManager: RequestManager
    private let currentUserManager: CurrentUserManager

    /// The known set of goals
    /// Has two slightly differenty empty states. If nil, it means we have not fetched goals. If an empty dictionary, means we have
    /// fetched goals and found there to be none.
    /// Can be read in non-isolated context, so protected with a synchronized wrapper.
    private let goalsBox = SynchronizedBox<OrderedDictionary<String, Goal>?>(nil)

    var goalsFetchedAt : Date? = nil

    private var queuedGoalsBackgroundTaskRunning : Bool = false

    init(requestManager: RequestManager, currentUserManager: CurrentUserManager) {
        self.requestManager = requestManager
        self.currentUserManager = currentUserManager

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
    nonisolated func staleGoals() -> [Goal]? {
        guard let goals = self.goalsBox.get() else { return nil }
        return Array(goals.values)
    }

    /// Fetch and return the latest set of goals from the server
    func fetchGoals() async throws -> [Goal] {
        guard let username = currentUserManager.username else {
            await currentUserManager.signOut()
            return []
        }

        let responseObject = try await requestManager.get(url: "api/v1/users/\(username)/goals.json", parameters: nil)!
        let response = JSON(responseObject)
        guard let goals = self.updateGoalsFromJson(response) else { return [] }

        self.updateTodayWidget()
        self.goalsFetchedAt = Date()

        self.setCachedLastFetchedGoals(response)

        await performPostGoalUpdateBookkeeping()

        return Array(goals.values)
    }

    func refreshGoal(_ goal: Goal) async throws {
        let responseObject = try await requestManager.get(url: "/api/v1/users/\(currentUserManager.username!)/goals/\(goal.slug)?access_token=\(currentUserManager.accessToken!)&datapoints_count=5", parameters: nil)
        goal.updateToMatch(json: JSON(responseObject!))

        await performPostGoalUpdateBookkeeping()
    }

    func forceAutodataRefresh(_ goal: Goal) async throws {
        let _ = try await requestManager.get(url: "/api/v1/users/\(currentUserManager.username!)/goals/\(goal.slug)/refresh_graph.json?access_token=\(currentUserManager.accessToken!)&datapoints_count=5", parameters: nil)
    }

    /// Update the set of goals to match those in the provided json. Existing Goal objects will be re-used when they match an ID in the json
    /// This function is nonisolated but should only be called either from isolated contexts or the constructor
    @discardableResult
    private nonisolated func updateGoalsFromJson(_ responseJSON: JSON) -> OrderedDictionary<String, Goal>? {
        var updatedGoals = OrderedDictionary<String, Goal>()
        guard let responseGoals = responseJSON.array else {
            self.goalsBox.set(nil)
            return nil
        }

        let existingGoals = self.goalsBox.get() ?? OrderedDictionary()

        for goalJSON in responseGoals {
            let goalId = goalJSON["id"].stringValue
            if let existingGoal = existingGoals[goalId] {
                existingGoal.updateToMatch(json: goalJSON)
                updatedGoals[existingGoal.id] = existingGoal
            } else {
                let newGoal = Goal(json: goalJSON)
                updatedGoals[newGoal.id] = newGoal
            }
        }

        self.goalsBox.set(updatedGoals)
        return updatedGoals
    }

    private func performPostGoalUpdateBookkeeping() async {
        Task {
            // Note this call can be re-entrant, but that is fine as our protection against multiple running
            // copies will make it a no-op
            await pollQueuedGoalsUntilUpdated()
        }

        // Notify all listeners of the update
        await Task { @MainActor in
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
                guard let goals = goalsBox.get() else { break }
                let queuedGoals = goals.values.filter { goal in goal.queued ?? false }
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
        self.goalsBox.set(nil)
        self.goalsFetchedAt = Date(timeIntervalSince1970: 0)
        currentUserManager.removeObject(forKey: cachedLastFetchedGoalsKey)
    }

    // MARK: Today Widget

    private func updateTodayWidget() {
        if let sharedDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier) {
            sharedDefaults.set(self.todayGoalDictionaries(), forKey: "todayGoalDictionaries")
            // Note this key is different to accessTokenKey
            sharedDefaults.set(currentUserManager.accessToken, forKey: "accessToken")
        }
    }

    private func todayGoalDictionaries() -> Array<Any> {
        guard let goals = self.goalsBox.get() else { return [] }

        let todayGoals = goals.values.map { (goal) in
            let shortSlug = goal.slug.prefix(20)
            let limsum = goal.limsum ?? ""
            return ["deadline" : goal.deadline.intValue, "thumbUrl": goal.cacheBustingThumbUrl, "limSum": "\(shortSlug): \(limsum)", "slug": goal.slug, "hideDataEntry": goal.hideDataEntry()] as [String : Any]
        }
        return Array(todayGoals.prefix(3)) as Array<Any>
    }
}
