//
//  CurrentUserManager.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/26/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation
import MagicalRecord
import AFNetworking
import FBSDKLoginKit
import SwiftyJSON
import TwitterKit

class CurrentUserManager : NSObject, GIDSignInDelegate, FBSDKLoginButtonDelegate {
    
    static let sharedManager = CurrentUserManager()
    static let signedInNotificationName     = "com.beeminder.signedInNotification"
    static let willSignOutNotificationName  = "com.beeminder.willSignOutNotification"
    static let failedSignInNotificationName = "com.beeminder.failedSignInNotification"
    static let signedOutNotificationName    = "com.beeminder.signedOutNotification"
    static let resetNotificationName        = "com.beeminder.resetNotification"
    static let willResetNotificationName    = "com.beeminder.willResetNotification"
    fileprivate let accessTokenKey = "access_token"
    fileprivate let usernameKey = "username"
    fileprivate let deadbeatKey = "deadbeat"
    fileprivate let defaultLeadtimeKey = "default_leadtime"
    fileprivate let defaultAlertstartKey = "default_alertstart"
    fileprivate let defaultDeadlineKey = "default_deadline"
    fileprivate let beemiosSecret = "C0QBFPWqDykIgE6RyQ2OJJDxGxGXuVA2CNqcJM185oOOl4EQTjmpiKgcwjki"
    
    var accessToken :String? {
        return UserDefaults.standard.object(forKey: accessTokenKey) as! String?
    }
    
    var username :String? {
        return UserDefaults.standard.object(forKey: usernameKey) as! String?
    }
    
    func defaultLeadTime() -> NSNumber {
        return (UserDefaults.standard.object(forKey: self.defaultLeadtimeKey) ?? 0) as! NSNumber
    }
    
    func setDefaultLeadTime(_ leadtime : NSNumber) {
        UserDefaults.standard.set(leadtime, forKey: self.defaultLeadtimeKey)
        UserDefaults.standard.synchronize()
        let goals = Goal.mr_find(byAttribute: "use_defaults", withValue: NSNumber(value: true as Bool)) as! [Goal]
        for goal in goals {
            goal.leadtime = leadtime
        }
        NSManagedObjectContext.mr_default().mr_saveToPersistentStore(completion: nil)
    }
    
    func defaultAlertstart() -> NSNumber {
        return (UserDefaults.standard.object(forKey: self.defaultAlertstartKey) ?? 0) as! NSNumber
    }
    
    func setDefaultAlertstart(_ alertstart : NSNumber) {
        UserDefaults.standard.set(alertstart, forKey: self.defaultAlertstartKey)
        UserDefaults.standard.synchronize()
        let goals = Goal.mr_find(byAttribute: "use_defaults", withValue: NSNumber(value: true as Bool)) as! [Goal]
        for goal in goals {
            goal.alertstart = alertstart
        }
        NSManagedObjectContext.mr_default().mr_saveToPersistentStore(completion: nil)
    }
    
    func defaultDeadline() -> NSNumber {
        return (UserDefaults.standard.object(forKey: self.defaultDeadlineKey) ?? 0) as! NSNumber
    }
    
    func setDefaultDeadline(_ deadline : NSNumber) {
        UserDefaults.standard.set(deadline, forKey: self.defaultDeadlineKey)
        UserDefaults.standard.synchronize()
        let goals = Goal.mr_find(byAttribute: "use_defaults", withValue: NSNumber(value: true as Bool)) as! [Goal]
        for goal in goals {
            goal.deadline = deadline
        }
        NSManagedObjectContext.mr_default().mr_saveToPersistentStore(completion: nil)
    }
    
    func signedIn() -> Bool {
        return self.accessToken != nil && self.username != nil
    }
    
    func isDeadbeat() -> Bool {
        return UserDefaults.standard.object(forKey: deadbeatKey) != nil
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
        BSHTTPSessionManager.sharedManager.post("/api/private/sign_in", parameters: ["user": ["login": email, "password": password], "beemios_secret": self.beemiosSecret] as Dictionary<String, Any>, progress: nil, success: { (dataTask, responseObject) in
                self.handleSuccessfulSignin(JSON(responseObject))
            }) { (dataTask, responseError) in
                self.handleFailedSignin(responseError)
        }
        
        
//        BSHTTPSessionManager.sharedManager.post("/api/private/sign_in", parameters: ["user": ["login": email, "password": password], "beemios_secret": self.beemiosSecret] as AnyObject, success: { (dataTask, responseObject) -> Void in
//            self.handleSuccessfulSignin(JSON(responseObject!))
//        }) { (dataTask, responseError) -> Void in
//            self.handleFailedSignin(responseError)
//            }
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
        UserDefaults.standard.synchronize()
        NotificationCenter.default.post(name: Notification.Name(rawValue: CurrentUserManager.signedInNotificationName), object: self)
    }
    
    func syncNotificationDefaults(_ success: (() -> Void)?, failure: (() -> Void)?) {
        BSHTTPSessionManager.sharedManager.get("api/v1/users/me.json", parameters: [] as AnyObject,
            success: { (task, responseObject) -> Void in
                let responseJSON = JSON(responseObject!)
                UserDefaults.standard.set(responseJSON["default_alertstart"].number!, forKey: "default_alertstart")
                UserDefaults.standard.set(responseJSON["default_deadline"].number!, forKey: "default_deadline")
                UserDefaults.standard.set(responseJSON["default_leadtime"].number!, forKey: "default_leadtime")
                UserDefaults.standard.synchronize()
                if (success != nil) { success!() }
            }, failure: { (task, error) -> Void in
                if (failure != nil) { failure!() }
        })
    }
    
    func handleFailedSignin(_ responseError: Error) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: CurrentUserManager.failedSignInNotificationName), object: self, userInfo: ["error" : responseError])
        self.signOut()
    }
    
    func signOut() {
        NotificationCenter.default.post(name: Notification.Name(rawValue: CurrentUserManager.willSignOutNotificationName), object: self)
        UserDefaults.standard.removeObject(forKey: accessTokenKey)
        UserDefaults.standard.removeObject(forKey: deadbeatKey)
        UserDefaults.standard.removeObject(forKey: usernameKey)
        UserDefaults.standard.synchronize()
        for datapoint in Datapoint.mr_findAll()! {
            datapoint.mr_deleteEntity()
        }
        for goal in Goal.mr_findAll()! {
            goal.mr_deleteEntity()
        }
        NSManagedObjectContext.mr_default().mr_saveToPersistentStore { (success, error) -> Void in
            NotificationCenter.default.post(name: Notification.Name(rawValue: CurrentUserManager.signedOutNotificationName), object: self)
        }
    }
    
    func reset() {
        NotificationCenter.default.post(name: Notification.Name(rawValue: CurrentUserManager.willResetNotificationName), object: self)
        for datapoint in Datapoint.mr_findAll()! {
            datapoint.mr_deleteEntity()
        }
        for goal in Goal.mr_findAll()! {
            goal.mr_deleteEntity()
        }
        DataSyncManager.sharedManager.setLastSynced(nil)
        NSManagedObjectContext.mr_default().mr_saveToPersistentStore { (success, error) -> Void in
            NotificationCenter.default.post(name: Notification.Name(rawValue: CurrentUserManager.resetNotificationName), object: self)
        }
    }
    
    func signInWithOAuthUserId(_ userId: String, provider: String) {
        BSHTTPSessionManager.sharedManager.signedPOST("/api/private/sign_in", parameters: ["oauth_user_id": userId, "provider": provider], success: { (dataTask, responseObject) -> Void in
            self.handleSuccessfulSignin(JSON(responseObject!))
        }) { (dataTask, responseError) -> Void in
            self.handleFailedSignin(responseError)
        }
    }
    
    func loginButton(_ loginButton: FBSDKLoginButton!, didCompleteWith result: FBSDKLoginManagerLoginResult!, error: Error!) {
        if (result.token != nil) {
            self.signInWithOAuthUserId(result.token.userID, provider: "facebook")
        }
    }
    
    func loginButtonDidLogOut(_ loginButton: FBSDKLoginButton!) {
        // never called
    }
    
    func loginWithTwitterSession(_ session: TWTRSession!) {
        self.signInWithOAuthUserId(session.userID, provider: "twitter")
    }
    
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
        if error != nil {
            return
        }
        self.signInWithOAuthUserId(user.userID, provider: "google_oauth2")
    }
    
    func sign(_ signIn: GIDSignIn!, didDisconnectWith user: GIDGoogleUser!, withError error: NSError!) {
        // never called
    }
}
