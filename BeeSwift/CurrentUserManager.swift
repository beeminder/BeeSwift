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
    
    var allKeys: [String] {
        return [accessTokenKey, usernameKey, deadbeatKey, defaultLeadtimeKey, defaultAlertstartKey, defaultDeadlineKey, beemTZKey]
    }
    

    // TODO: suiteName needs to be a constant somewhere!
    let userDefaults = UserDefaults(suiteName: "group.beeminder.beeminder")!
    
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
                // It would be neater to clean up, but for now it breaks branch switching
                // userDefaults.removeObject(forKey: key)
            }
        }
    }
    
    var goals : [JSONGoal] = []
    var goalsFetchedAt : Date = Date()
    
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
        userDefaults.set(leadtime, forKey: self.defaultLeadtimeKey)
        userDefaults.synchronize()
    }
    
    func defaultAlertstart() -> NSNumber {
        return (userDefaults.object(forKey: self.defaultAlertstartKey) ?? 0) as! NSNumber
    }
    
    func setDefaultAlertstart(_ alertstart : NSNumber) {
        userDefaults.set(alertstart, forKey: self.defaultAlertstartKey)
        userDefaults.synchronize()
    }
    
    func defaultDeadline() -> NSNumber {
        return (userDefaults.object(forKey: self.defaultDeadlineKey) ?? 0) as! NSNumber
    }
    
    func setDefaultDeadline(_ deadline : NSNumber) {
        userDefaults.set(deadline, forKey: self.defaultDeadlineKey)
        userDefaults.synchronize()
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
    
    func setDeadbeat(_ deadbeat: Bool) {
        if deadbeat {
            userDefaults.set(true, forKey: deadbeatKey)
        } else {
            userDefaults.removeObject(forKey: deadbeatKey)
        }
        userDefaults.synchronize()
    }
    
    func setAccessToken(_ accessToken: String) {
        userDefaults.set(accessToken, forKey: accessTokenKey)
        userDefaults.synchronize()
    }
    
    func signInWithEmail(_ email: String, password: String) {
        RequestManager.post(url: "api/private/sign_in", parameters: ["user": ["login": email, "password": password], "beemios_secret": self.beemiosSecret] as Dictionary<String, Any>, success: { (responseObject) in
            self.handleSuccessfulSignin(JSON(responseObject!))
            }) { (responseError, errorMessage) in
                if responseError != nil { self.handleFailedSignin(responseError!, errorMessage: errorMessage) }
        }
    }
    
    func handleSuccessfulSignin(_ responseJSON: JSON) {
        if responseJSON["deadbeat"].boolValue {
            self.setDeadbeat(true)
        }
        userDefaults.set(responseJSON[accessTokenKey].string!, forKey: accessTokenKey)
        userDefaults.set(responseJSON[usernameKey].string!, forKey: usernameKey)
        userDefaults.set(responseJSON[defaultAlertstartKey].number!, forKey: defaultAlertstartKey)
        userDefaults.set(responseJSON[defaultDeadlineKey].number!, forKey: defaultDeadlineKey)
        userDefaults.set(responseJSON[defaultLeadtimeKey].number!, forKey: defaultLeadtimeKey)
        userDefaults.set(responseJSON[beemTZKey].string!, forKey: beemTZKey)
        userDefaults.synchronize()
        NotificationCenter.default.post(name: Notification.Name(rawValue: CurrentUserManager.signedInNotificationName), object: self)
    }
    
    func syncNotificationDefaults(_ success: (() -> Void)?, failure: (() -> Void)?) {
        RequestManager.get(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!).json", parameters: [:],
            success: { (responseObject) -> Void in
                let responseJSON = JSON(responseObject!)
                self.userDefaults.set(responseJSON["default_alertstart"].number!, forKey: "default_alertstart")
                self.userDefaults.set(responseJSON["default_deadline"].number!, forKey: "default_deadline")
                self.userDefaults.set(responseJSON["default_leadtime"].number!, forKey: "default_leadtime")
                self.userDefaults.synchronize()
                if (success != nil) { success!() }
        }, errorHandler: { (error, errorMessage) -> Void in
                if (failure != nil) { failure!() }
        })
    }
    
    func handleFailedSignin(_ responseError: Error, errorMessage : String?) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: CurrentUserManager.failedSignInNotificationName), object: self, userInfo: ["error" : responseError])
        self.signOut()
    }
    
    func signOut() {
        self.goals = []
        self.goalsFetchedAt = Date(timeIntervalSince1970: 0)
        NotificationCenter.default.post(name: Notification.Name(rawValue: CurrentUserManager.willSignOutNotificationName), object: self)
        userDefaults.removeObject(forKey: accessTokenKey)
        userDefaults.removeObject(forKey: deadbeatKey)
        userDefaults.removeObject(forKey: usernameKey)
        userDefaults.synchronize()
        NotificationCenter.default.post(name: Notification.Name(rawValue: CurrentUserManager.signedOutNotificationName), object: self)
    }
    
    func fetchGoals(success: ((_ goals : [JSONGoal]) -> ())?, error: ((_ error : Error?, _ errorMessage : String?) -> ())?) {
        guard let username = self.username else {
            CurrentUserManager.sharedManager.signOut()
            success?([])
            return
        }
        RequestManager.get(url: "api/v1/users/\(username)/goals.json", parameters: nil, success: { (responseJSON) in
            guard let responseGoals = JSON(responseJSON!).array else { return }
            var jGoals : [JSONGoal] = []
            responseGoals.forEach({ (goalJSON) in
                let g = JSONGoal(json: goalJSON)
                jGoals.append(g)
            })
            self.goals = jGoals
            self.updateTodayWidget()
            self.goalsFetchedAt = Date()
            NotificationCenter.default.post(name: Notification.Name(rawValue: CurrentUserManager.goalsFetchedNotificationName), object: self)
            success?(jGoals)
        }) { (responseError, errorMessage) in
            error?(responseError, errorMessage)
        }
    }

    func updateTodayWidget() {
        if let sharedDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier) {
            sharedDefaults.set(self.todayGoalDictionaries(), forKey: "todayGoalDictionaries")
            sharedDefaults.set(CurrentUserManager.sharedManager.accessToken, forKey: "accessToken")
            sharedDefaults.synchronize()
        }
    }
    
    func todayGoalDictionaries() -> Array<Any> {
        let todayGoals = self.goals.map { (goal) -> Any? in
            let shortSlug = goal.slug.prefix(20)
            let limsum = goal.limsum ?? ""
            return ["deadline" : goal.deadline.intValue, "thumbUrl": goal.cacheBustingThumbUrl, "limSum": "\(shortSlug): \(limsum)", "slug": goal.slug, "hideDataEntry": goal.hideDataEntry()]
        }
        return Array(todayGoals.prefix(3)) as Array<Any>
    }
}
