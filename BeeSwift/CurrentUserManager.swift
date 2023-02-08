//
//  CurrentUserManager.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/26/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation
import SwiftyJSON

class CurrentUserManager : NSObject {
    
    static let sharedManager = CurrentUserManager()
    static let signedInNotificationName     = "com.beeminder.signedInNotification"
    static let willSignOutNotificationName  = "com.beeminder.willSignOutNotification"
    static let failedSignInNotificationName = "com.beeminder.failedSignInNotification"
    static let signedOutNotificationName    = "com.beeminder.signedOutNotification"
    static let resetNotificationName        = "com.beeminder.resetNotification"
    static let willResetNotificationName    = "com.beeminder.willResetNotification"
    static let goalsFetchedNotificationName = "com.beeminder.goalsFetchedNotification"
    static let healthKitMetricRemovedNotificationName = "com.beeminder.healthKitMetricRemovedNotification"
    
    fileprivate let beemiosSecret = "C0QBFPWqDykIgE6RyQ2OJJDxGxGXuVA2CNqcJM185oOOl4EQTjmpiKgcwjki"
    
    fileprivate let accessTokenKey = "access_token"
    fileprivate let usernameKey = "username"
    fileprivate let deadbeatKey = "deadbeat"
    fileprivate let defaultLeadtimeKey = "default_leadtime"
    fileprivate let defaultAlertstartKey = "default_alertstart"
    fileprivate let defaultDeadlineKey = "default_deadline"
    fileprivate let beemTZKey = "timezone"
    fileprivate let cachedLastFetchedGoalsKey = "last_fetched_goals"
    
    var allKeys: [String] {
        [accessTokenKey, usernameKey, deadbeatKey, defaultLeadtimeKey, defaultAlertstartKey, defaultDeadlineKey, beemTZKey]
    }
    
    let userDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier)!
    
    override init() {
        super.init()
        migrateValues()
    }
    
    /// Migrate settings values from the standard store to a group store
    ///
    /// Originally BeeSwift stored all configuration values in the standard UserDefaults store. However
    /// these values are not available within extensions. To address this now values are stored in a
    /// group-scoped settings object. Values written by old versions of the app may be in the previous store
    /// so we migrate any such values on initialization.
    private func migrateValues() {
        for key in allKeys {
            let standardValue = UserDefaults.standard.object(forKey: key)
            let groupValue = userDefaults.object(forKey: key)
            
            if groupValue == nil && standardValue != nil {
                userDefaults.set(standardValue, forKey: key)
                // It would be neater to clean up, but for now we want to support
                // downgrading to prior versions, so leave old keys in place.
                // userDefaults.removeObject(forKey: key)
            }
        }
    }
    
    /// Write a value to the UserDefaults store
    ///
    /// During migration to the appGroup shared store we still want to support users downgrading
    /// to prior versions, and thus write all values to both stores.
    private func set(_ value: Any, forKey key: String) {
        userDefaults.set(value, forKey: key)
        UserDefaults.standard.set(value, forKey: key)
    }
    
    private func removeObject(forKey key: String) {
        userDefaults.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: key)
    }

    /// The known set of goals
    /// Has two slightly differenty empty states. If nil, it means we have not fetched goals. If an empty dictionary, means we have
    /// fetched goals and found there to be none.
    private var goals : [String: Goal]? = nil
    var goalsFetchedAt : Date? = nil
    
    var accessToken :String? {
        return userDefaults.object(forKey: accessTokenKey) as! String?
    }
    
    var username :String? {
        return userDefaults.object(forKey: usernameKey) as! String?
    }
    
    var signingUp : Bool = false
    
    func defaultLeadTime() -> NSNumber {
        return (userDefaults.object(forKey: self.defaultLeadtimeKey) ?? 0) as! NSNumber
    }
    
    func setDefaultLeadTime(_ leadtime : NSNumber) {
        self.set(leadtime, forKey: self.defaultLeadtimeKey)    }
    
    func defaultAlertstart() -> NSNumber {
        return (userDefaults.object(forKey: self.defaultAlertstartKey) ?? 0) as! NSNumber
    }
    
    func setDefaultAlertstart(_ alertstart : NSNumber) {
        self.set(alertstart, forKey: self.defaultAlertstartKey)
    }
    
    func defaultDeadline() -> NSNumber {
        return (userDefaults.object(forKey: self.defaultDeadlineKey) ?? 0) as! NSNumber
    }
    
    func setDefaultDeadline(_ deadline : NSNumber) {
        self.set(deadline, forKey: self.defaultDeadlineKey)
    }
    
    func signedIn() -> Bool {
        return self.accessToken != nil && self.username != nil
    }
    
    func isDeadbeat() -> Bool {
        return userDefaults.object(forKey: deadbeatKey) != nil
    }
    
    func timezone() -> String {
        return userDefaults.object(forKey: beemTZKey) as? String ?? "Unknown"
    }

    func setCachedLastFetchedGoals(_ goals : JSON) {
        self.set(goals.rawString()!, forKey: self.cachedLastFetchedGoalsKey)
    }

    private func cachedLastFetchedGoals() -> JSON? {
        guard let encodedValue = userDefaults.object(forKey: cachedLastFetchedGoalsKey) as? String else { return nil }
        return JSON.parse(encodedValue)
    }
    
    func setDeadbeat(_ deadbeat: Bool) {
        if deadbeat {
            self.set(true, forKey: deadbeatKey)
        } else {
            self.removeObject(forKey: deadbeatKey)
        }
    }
    
    func setAccessToken(_ accessToken: String) {
        self.set(accessToken, forKey: accessTokenKey)
    }
    
    func signInWithEmail(_ email: String, password: String) async {
        do {
           let response = try await RequestManager.post(url: "api/private/sign_in", parameters: ["user": ["login": email, "password": password], "beemios_secret": self.beemiosSecret] as Dictionary<String, Any>)
            await self.handleSuccessfulSignin(JSON(response!))
        } catch {
            await self.handleFailedSignin(error, errorMessage: error.localizedDescription)
        }
    }
    
    func handleSuccessfulSignin(_ responseJSON: JSON) async {
        if responseJSON["deadbeat"].boolValue {
            self.setDeadbeat(true)
        }
        self.set(responseJSON[accessTokenKey].string!, forKey: accessTokenKey)
        self.set(responseJSON[usernameKey].string!, forKey: usernameKey)
        self.set(responseJSON[defaultAlertstartKey].number!, forKey: defaultAlertstartKey)
        self.set(responseJSON[defaultDeadlineKey].number!, forKey: defaultDeadlineKey)
        self.set(responseJSON[defaultLeadtimeKey].number!, forKey: defaultLeadtimeKey)
        self.set(responseJSON[beemTZKey].string!, forKey: beemTZKey)
        await Task { @MainActor in
            NotificationCenter.default.post(name: Notification.Name(rawValue: CurrentUserManager.signedInNotificationName), object: self)
        }.value
    }
    
    func syncNotificationDefaults() async throws {
        let response = try await RequestManager.get(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!).json", parameters: [:])
        let responseJSON = JSON(response!)
        self.set(responseJSON["default_alertstart"].number!, forKey: "default_alertstart")
        self.set(responseJSON["default_deadline"].number!, forKey: "default_deadline")
        self.set(responseJSON["default_leadtime"].number!, forKey: "default_leadtime")

    }
    
    func handleFailedSignin(_ responseError: Error, errorMessage : String?) async {
        await Task { @MainActor in
            NotificationCenter.default.post(name: Notification.Name(rawValue: CurrentUserManager.failedSignInNotificationName), object: self, userInfo: ["error" : responseError])
        }.value
        await self.signOut()
    }
    
    func signOut() async {
        self.goals = [:]
        self.goalsFetchedAt = Date(timeIntervalSince1970: 0)

        await Task { @MainActor in
            NotificationCenter.default.post(name: Notification.Name(rawValue: CurrentUserManager.willSignOutNotificationName), object: self)
        }.value
        self.removeObject(forKey: accessTokenKey)
        self.removeObject(forKey: deadbeatKey)
        self.removeObject(forKey: usernameKey)
        self.removeObject(forKey: cachedLastFetchedGoalsKey)
        await Task { @MainActor in
            NotificationCenter.default.post(name: Notification.Name(rawValue: CurrentUserManager.signedOutNotificationName), object: self)
        }.value
    }
    
    func fetchGoals() async throws -> [Goal] {
        guard let username = self.username else {
            await CurrentUserManager.sharedManager.signOut()
            return []
        }

        let responseObject = try await RequestManager.get(url: "api/v1/users/\(username)/goals.json", parameters: nil)!
        let response = JSON(responseObject)
        guard let goals = self.updateGoalsFromJson(response) else { return [] }

        self.updateTodayWidget()
        self.goalsFetchedAt = Date()

        self.setCachedLastFetchedGoals(response)

        await Task { @MainActor in
            NotificationCenter.default.post(name: Notification.Name(rawValue: CurrentUserManager.goalsFetchedNotificationName), object: self)
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

    func updateTodayWidget() {
        if let sharedDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier) {
            sharedDefaults.set(self.todayGoalDictionaries(), forKey: "todayGoalDictionaries")
            // Note this key is different to accessTokenKey
            sharedDefaults.set(CurrentUserManager.sharedManager.accessToken, forKey: "accessToken")
        }
    }
    
    func todayGoalDictionaries() -> Array<Any> {
        guard let goals = self.goals else { return [] }

        let todayGoals = goals.values.map { (goal) in
            let shortSlug = goal.slug.prefix(20)
            let limsum = goal.limsum ?? ""
            return ["deadline" : goal.deadline.intValue, "thumbUrl": goal.cacheBustingThumbUrl, "limSum": "\(shortSlug): \(limsum)", "slug": goal.slug, "hideDataEntry": goal.hideDataEntry()]
        }
        return Array(todayGoals.prefix(3)) as Array<Any>
    }
}
