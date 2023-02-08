//
//  GoalManager.swift
//  BeeSwift
//
//  Created by Theo Spears on 2/7/23.
//  Copyright © 2023 APB. All rights reserved.
//

import Foundation
import SwiftyJSON

class GoalManager {
    static let goalsFetchedNotificationName = "com.beeminder.goalsFetchedNotification"

    fileprivate let cachedLastFetchedGoalsKey = "last_fetched_goals"

    private let requestManager: RequestManager
    private let currentUserManager: CurrentUserManager

    /// The known set of goals
    /// Has two slightly differenty empty states. If nil, it means we have not fetched goals. If an empty dictionary, means we have
    /// fetched goals and found there to be none.
    private var goals : [String: Goal]? = nil
    var goalsFetchedAt : Date? = nil

    init(requestManager: RequestManager, currentUserManager: CurrentUserManager) {
        self.requestManager = requestManager
        self.currentUserManager = currentUserManager

        NotificationCenter.default.addObserver(self, selector: #selector(self.signedOut), name: NSNotification.Name(rawValue: CurrentUserManager.signedOutNotificationName), object: nil)
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

        await Task { @MainActor in
            NotificationCenter.default.post(name: Notification.Name(rawValue: GoalManager.goalsFetchedNotificationName), object: self)
        }.value

        return Array(goals.values)
    }

    /// Return the state of goals the last time they were fetched from the server. This could have been an arbitrarily long time ago.
    func staleGoals() -> [Goal]? {
        if let goals = self.goals {
            return Array(goals.values)
        }

        guard let goalJSON = self.cachedLastFetchedGoals() else { return nil }
        guard let goals = self.updateGoalsFromJson(goalJSON) else { return nil }

        return Array(goals.values)

    }

    private func setCachedLastFetchedGoals(_ goals : JSON) {
        currentUserManager.set(goals.rawString()!, forKey: self.cachedLastFetchedGoalsKey)
    }

    private func cachedLastFetchedGoals() -> JSON? {
        guard let encodedValue = currentUserManager.userDefaults.object(forKey: cachedLastFetchedGoalsKey) as? String else { return nil }
        return JSON.parse(encodedValue)
    }

    @objc
    private func signedOut() {
        self.goals = nil
        self.goalsFetchedAt = Date(timeIntervalSince1970: 0)
        currentUserManager.removeObject(forKey: cachedLastFetchedGoalsKey)
    }



    /// Update the set of goals to match those in the provided json. Existing Goal objects will be re-used when they match an ID in the json
    private func updateGoalsFromJson(_ responseJSON: JSON) -> [String: Goal]? {
        var updatedGoals: [String: Goal] = [:]
        guard let responseGoals = responseJSON.array else {
            self.goals = nil
            return nil
        }

        let existingGoals = self.goals ?? [:]

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

        self.goals = updatedGoals
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
        guard let goals = self.goals else { return [] }

        let todayGoals = goals.values.map { (goal) in
            let shortSlug = goal.slug.prefix(20)
            let limsum = goal.limsum ?? ""
            return ["deadline" : goal.deadline.intValue, "thumbUrl": goal.cacheBustingThumbUrl, "limSum": "\(shortSlug): \(limsum)", "slug": goal.slug, "hideDataEntry": goal.hideDataEntry()]
        }
        return Array(todayGoals.prefix(3)) as Array<Any>
    }
}
