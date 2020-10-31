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
    static let failedSignUpNotificationName = "com.beeminder.failedSignUpNotification"
    static let signedOutNotificationName    = "com.beeminder.signedOutNotification"
    static let resetNotificationName        = "com.beeminder.resetNotification"
    static let willResetNotificationName    = "com.beeminder.willResetNotification"
    static let goalsFetchedNotificationName = "com.beeminder.goalsFetchedNotification"
    static let healthKitMetricRemovedNotificationName = "com.beeminder.healthKitMetricRemovedNotification"
    
    fileprivate struct UserDefaultsKeys {
        static let apiTokenType = "api-token-type"
        static let apiTokenValue = "api-token-value"
        
        static let accessToken = "access_token"
    }
    
    fileprivate let apiTokenKey = "api_token_key"
    fileprivate let accessTokenKey = "access_token"
    fileprivate let usernameKey = "username"
    fileprivate let deadbeatKey = "deadbeat"
    fileprivate let defaultLeadtimeKey = "default_leadtime"
    fileprivate let defaultAlertstartKey = "default_alertstart"
    fileprivate let defaultDeadlineKey = "default_deadline"
    fileprivate let beemTZKey = "timezone"
    fileprivate let beemiosSecret = "C0QBFPWqDykIgE6RyQ2OJJDxGxGXuVA2CNqcJM185oOOl4EQTjmpiKgcwjki"
    
    var goals : [JSONGoal] = []
    var goalsFetchedAt : Date = Date()
    
    var apiToken: ApiToken? {
        guard let typeStr = UserDefaults.standard.string(forKey: UserDefaultsKeys.apiTokenType),
            let type = ApiTokenType(typeStr),
            let value = UserDefaults.standard.string(forKey: UserDefaultsKeys.apiTokenValue) else { return nil }
        
        return ApiToken(type: type, token: value)
    }
    
    var username :String? {
        return UserDefaults.standard.object(forKey: usernameKey) as! String?
    }
    
    var signingUp : Bool = false
    
    func defaultLeadTime() -> NSNumber {
        return (UserDefaults.standard.object(forKey: self.defaultLeadtimeKey) ?? 0) as! NSNumber
    }
    
    func setDefaultLeadTime(_ leadtime : NSNumber) {
        UserDefaults.standard.set(leadtime, forKey: self.defaultLeadtimeKey)
        UserDefaults.standard.synchronize()
    }
    
    func defaultAlertstart() -> NSNumber {
        return (UserDefaults.standard.object(forKey: self.defaultAlertstartKey) ?? 0) as! NSNumber
    }
    
    func setDefaultAlertstart(_ alertstart : NSNumber) {
        UserDefaults.standard.set(alertstart, forKey: self.defaultAlertstartKey)
        UserDefaults.standard.synchronize()
    }
    
    func defaultDeadline() -> NSNumber {
        return (UserDefaults.standard.object(forKey: self.defaultDeadlineKey) ?? 0) as! NSNumber
    }
    
    func setDefaultDeadline(_ deadline : NSNumber) {
        UserDefaults.standard.set(deadline, forKey: self.defaultDeadlineKey)
        UserDefaults.standard.synchronize()
    }
    
    func signedIn() -> Bool {
        return self.apiToken != nil && self.username != nil
    }
    
    func isDeadbeat() -> Bool {
        return UserDefaults.standard.object(forKey: deadbeatKey) != nil
    }
    
    func timezone() -> String {
        return UserDefaults.standard.object(forKey: beemTZKey) as? String ?? "Unknown"
    }
    
    func setDeadbeat(_ deadbeat: Bool) {
        if deadbeat {
            UserDefaults.standard.set(true, forKey: deadbeatKey)
        } else {
            UserDefaults.standard.removeObject(forKey: deadbeatKey)
        }
        UserDefaults.standard.synchronize()
    }
    
    func setApiToken(_ apiToken: ApiToken) {
        UserDefaults.standard.set(apiToken.type.rawValue, forKey: UserDefaultsKeys.apiTokenType)
        UserDefaults.standard.set(apiToken.value, forKey: UserDefaultsKeys.apiTokenValue)
        UserDefaults.standard.synchronize()
    }
    
    func signInWithEmail(_ email: String, password: String) {
        RequestManager.post(url: "api/private/sign_in", parameters: ["user": ["login": email, "password": password], "beemios_secret": self.beemiosSecret] as Dictionary<String, Any>, success: { (responseObject) in
                self.handleSuccessfulSignin(JSON(responseObject))
            }) { (responseError, errorMessage) in
                if responseError != nil { self.handleFailedSignin(responseError!, errorMessage: errorMessage) }
        }
    }
    
    func handleSuccessfulSignup(_ responseJSON: JSON) {
        guard let authToken = responseJSON["authentication_token"].string, let username = responseJSON["username"].string else {
            return
        }
        
        CurrentUserManager.sharedManager.setApiToken(ApiToken(type: .AuthenticationToken, token: authToken))

        UserDefaults.standard.set(username, forKey: usernameKey)
        UserDefaults.standard.synchronize()
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: CurrentUserManager.signedInNotificationName), object: self)
    }
    
    func handleSuccessfulSignin(_ responseJSON: JSON) {
        if responseJSON["deadbeat"].boolValue {
            self.setDeadbeat(true)
        }

        CurrentUserManager.sharedManager.setApiToken(ApiToken(type: .AccessToken, token:responseJSON[accessTokenKey].string!))
        UserDefaults.standard.set(responseJSON[usernameKey].string!, forKey: usernameKey)
        UserDefaults.standard.set(responseJSON[defaultAlertstartKey].number!, forKey: defaultAlertstartKey)
        UserDefaults.standard.set(responseJSON[defaultDeadlineKey].number!, forKey: defaultDeadlineKey)
        UserDefaults.standard.set(responseJSON[defaultLeadtimeKey].number!, forKey: defaultLeadtimeKey)
        UserDefaults.standard.set(responseJSON[beemTZKey].string!, forKey: beemTZKey)
        UserDefaults.standard.synchronize()
        NotificationCenter.default.post(name: Notification.Name(rawValue: CurrentUserManager.signedInNotificationName), object: self)
    }
    
    func syncNotificationDefaults(_ success: (() -> Void)?, failure: (() -> Void)?) {
        RequestManager.get(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!).json", parameters: [:],
            success: { (responseObject) -> Void in
                let responseJSON = JSON(responseObject!)
                UserDefaults.standard.set(responseJSON["default_alertstart"].number!, forKey: "default_alertstart")
                UserDefaults.standard.set(responseJSON["default_deadline"].number!, forKey: "default_deadline")
                UserDefaults.standard.set(responseJSON["default_leadtime"].number!, forKey: "default_leadtime")
                UserDefaults.standard.synchronize()
                if (success != nil) { success!() }
        }, errorHandler: { (error, errorMessage) -> Void in
                if (failure != nil) { failure!() }
        })
    }
    
    func handleFailedSignin(_ responseError: Error, errorMessage : String?) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: CurrentUserManager.failedSignInNotificationName), object: self, userInfo: ["error" : responseError])
        self.signOut()
    }
    
    func handleFailedSignup(_ responseError: Error, errorMessage : String?) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: CurrentUserManager.failedSignUpNotificationName), object: self, userInfo: ["error" : errorMessage])
        self.signOut()
    }
    
    func signOut() {
        self.goals = []
        self.goalsFetchedAt = Date(timeIntervalSince1970: 0)
        NotificationCenter.default.post(name: Notification.Name(rawValue: CurrentUserManager.willSignOutNotificationName), object: self)

        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
        }

        NotificationCenter.default.post(name: Notification.Name(rawValue: CurrentUserManager.signedOutNotificationName), object: self)
    }
    
    func fetchGoals(success: ((_ goals : [JSONGoal]) -> ())?, error: ((_ error : Error?, _ errorMessage : String?) -> ())?) {
        guard let username = self.username else {
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
        if let sharedDefaults = UserDefaults(suiteName: "group.beeminder.beeminder"), let apiToken =
            CurrentUserManager.sharedManager.apiToken {
            sharedDefaults.set(self.todayGoalDictionaries(), forKey: "todayGoalDictionaries")
            sharedDefaults.set(apiToken.type.rawValue, forKey: UserDefaultsKeys.apiTokenType)
            sharedDefaults.set(apiToken.value, forKey: UserDefaultsKeys.apiTokenValue)
            
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
    
    func migrateToApiToken() {
        guard let previousAccessToken = UserDefaults.standard.string(forKey: UserDefaultsKeys.accessToken) else {
            // migration apparently not needed
            return
        }
        
        CurrentUserManager.sharedManager.setApiToken(ApiToken(type: .AccessToken, token: previousAccessToken))
    }
}
