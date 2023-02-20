//
//  GoalManager.swift
//  BeeSwift
//
//  Created by Theo Spears on 2/7/23.
//  Copyright © 2023 APB. All rights reserved.
//

import Foundation
import SwiftyJSON

actor GoalManager {
    /// A notification that is triggered any time the data for one or more goals is updated
    static let goalsUpdatedNotificationName = "com.beeminder.goalsUpdatedNotification"

    fileprivate let cachedLastFetchedGoalsKey = "last_fetched_goals"

    private let requestManager: RequestManager
    private let currentUserManager: CurrentUserManager

    /// The known set of goals
    /// Has two slightly differenty empty states. If nil, it means we have not fetched goals. If an empty dictionary, means we have
    /// fetched goals and found there to be none.
    /// Can be read in non-isolated context, so protected with a synchronized wrapper.
    private let goalsBox = SynchronizedBox<[String: Goal]?>(nil)

    var goalsFetchedAt : Date? = nil

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

        await notifyGoalsUpdated()

        return Array(goals.values)
    }

    func refreshGoal(_ goal: Goal) async throws {
        let responseObject = try await requestManager.get(url: "/api/v1/users/\(currentUserManager.username!)/goals/\(goal.slug)?access_token=\(currentUserManager.accessToken!)&datapoints_count=5", parameters: nil)
        goal.updateToMatch(json: JSON(responseObject!))

        await notifyGoalsUpdated()
    }

    /// Return the state of goals the last time they were fetched from the server. This could have been an arbitrarily long time ago.
    nonisolated func staleGoals() -> [Goal]? {
        guard let goals = self.goalsBox.get() else { return nil }
        return Array(goals.values)
    }

    private func notifyGoalsUpdated() async {
        await Task { @MainActor in
            NotificationCenter.default.post(name: Notification.Name(rawValue: GoalManager.goalsUpdatedNotificationName), object: self)
        }.value
    }

    private func setCachedLastFetchedGoals(_ goals : JSON) {
        currentUserManager.set(goals.rawString()!, forKey: self.cachedLastFetchedGoalsKey)
    }

    /// This function is nonisolated but should only be called either from isolated contexts or the constructor
    private nonisolated func cachedLastFetchedGoals() -> JSON? {
        guard let encodedValue = currentUserManager.userDefaults.object(forKey: cachedLastFetchedGoalsKey) as? String else { return nil }
        return JSON.parse(encodedValue)
    }

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

    /// Update the set of goals to match those in the provided json. Existing Goal objects will be re-used when they match an ID in the json
    /// This function is nonisolated but should only be called either from isolated contexts or the constructor
    @discardableResult
    private nonisolated func updateGoalsFromJson(_ responseJSON: JSON) -> [String: Goal]? {
        var updatedGoals: [String: Goal] = [:]
        guard let responseGoals = responseJSON.array else {
            self.goalsBox.set(nil)
            return nil
        }

        let existingGoals = self.goalsBox.get() ?? [:]

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
            return ["deadline" : goal.deadline.intValue, "thumbUrl": goal.cacheBustingThumbUrl, "limSum": "\(shortSlug): \(limsum)", "slug": goal.slug, "hideDataEntry": goal.hideDataEntry()]
        }
        return Array(todayGoals.prefix(3)) as Array<Any>
    }
}
