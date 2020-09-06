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
    
    var accessToken :String? {
        return UserDefaults.standard.object(forKey: accessTokenKey) as! String?
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
    
    var isSignedIn: Bool {
        return self.accessToken != nil && self.username != nil
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
    
    func setAccessToken(_ accessToken: String) {
        UserDefaults.standard.set(accessToken, forKey: accessTokenKey)
        UserDefaults.standard.synchronize()
    }
    
    func signInWithEmail(_ email: String, password: String) {
        let parameters: [String: Any] =
            [
                "user":
                    [
                        "login": email,
                        "password": password
                ],
                "beemios_secret":
                    self.beemiosSecret
        ]
        
        RequestManager.post(url: "api/private/sign_in",
                            parameters: parameters,
                            success: { (responseObject) in
                                self.handleSuccessfulSignin(JSON(responseObject))
        }, errorHandler: { (responseError) in
            if responseError != nil { self.handleFailedSignin(responseError!) }
        })
    }
    
    func handleSuccessfulSignin(_ responseJSON: JSON) {
        
        if responseJSON["deadbeat"].boolValue {
            self.setDeadbeat(true)
        }
        UserDefaults.standard.set(responseJSON[accessTokenKey].string!, forKey: accessTokenKey)
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
        }, errorHandler: { (error) -> Void in
                if (failure != nil) { failure!() }
        })
    }
    
    func handleFailedSignin(_ responseError: Error) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: CurrentUserManager.failedSignInNotificationName), object: self, userInfo: ["error" : responseError])
        self.signOut()
    }
    
    func handleFailedSignup(_ responseError: Error) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: CurrentUserManager.failedSignUpNotificationName), object: self, userInfo: ["error" : responseError])
        self.signOut()
    }
    
    func signOut() {
        self.goals = []
        self.goalsFetchedAt = Date(timeIntervalSince1970: 0)
        NotificationCenter.default.post(name: Notification.Name(rawValue: CurrentUserManager.willSignOutNotificationName), object: self)
        UserDefaults.standard.removeObject(forKey: accessTokenKey)
        UserDefaults.standard.removeObject(forKey: deadbeatKey)
        UserDefaults.standard.removeObject(forKey: usernameKey)
        UserDefaults.standard.synchronize()
        NotificationCenter.default.post(name: Notification.Name(rawValue: CurrentUserManager.signedOutNotificationName), object: self)
    }
    
    // MARK: fetching user
    
    func fetchUser(success: ((_ user: JSONUser) -> Void)? = nil, error: ((_ error: Error?) -> Void)? = nil) {
        RequestManager.get(url: "api/v1/users/me.json",
                           parameters: nil,
                           success: { responseJSON in
                            
                            guard let responseJSON = responseJSON else {
                                error?(ApiError.jsonDeserializationError)
                                return
                            }

                            let json = JSON(responseJSON)
                            guard let responseUser = JSONUser(json: json) else {
                                error?(ApiError.jsonDeserializationError)
                                return
                            }

                            self.setDeadbeat(responseUser.deadbeat)
                            
                            success?(responseUser)
        }, errorHandler: { responseError in
            error?(responseError)
        })
    }
    
    // MARK: fetching goals
    
    var userUpdatedAtTimestampWhenGoalsLastFetched: TimeInterval = 0
    
    
    /// fetch the user's goals
    /// - Parameters:
    ///   - success: callback in case of success
    ///   - error: callback in case of error
    ///   - userInvoked: true if the user invoked the request to fetch goals
    func fetchGoals(success: ((_ goals : [JSONGoal]) -> ())?, error: ((_ error : Error?) -> ())?, userInvoked: Bool = false) {
        guard let username = self.username else {
            success?([])
            return
        }

        self.fetchUser(success: { user in
            let neverFetched = self.userUpdatedAtTimestampWhenGoalsLastFetched == 0
            let newerGoalDataAvailable = user.updated_at > self.userUpdatedAtTimestampWhenGoalsLastFetched
            let shouldFetchGoals: Bool = userInvoked || neverFetched || newerGoalDataAvailable
            
            guard shouldFetchGoals else {
                success?(self.goals)
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
                self.userUpdatedAtTimestampWhenGoalsLastFetched = user.updated_at
                NotificationCenter.default.post(name: Notification.Name(rawValue: CurrentUserManager.goalsFetchedNotificationName), object: self)
                success?(jGoals)
            }) { (responseError) in
                error?(responseError)
            }
        })
    }
    
    func updateTodayWidget() {
        if let sharedDefaults = UserDefaults(suiteName: "group.beeminder.beeminder") {
            sharedDefaults.set(self.todayGoalDictionaries(), forKey: "todayGoalDictionaries")
            sharedDefaults.set(CurrentUserManager.sharedManager.accessToken, forKey: "accessToken")
            sharedDefaults.set(CurrentUserManager.sharedManager.username, forKey: "username")
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
