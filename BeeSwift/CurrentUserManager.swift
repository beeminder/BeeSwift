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
    private let accessTokenKey = "access_token"
    private let usernameKey = "username"
    private let deadbeatKey = "deadbeat"
    private let defaultLeadtimeKey = "default_leadtime"
    private let defaultAlertstartKey = "default_alertstart"
    private let defaultDeadlineKey = "default_deadline"
    private let beemiosSecret = "C0QBFPWqDykIgE6RyQ2OJJDxGxGXuVA2CNqcJM185oOOl4EQTjmpiKgcwjki"
    
    var accessToken :String? {
        return NSUserDefaults.standardUserDefaults().objectForKey(accessTokenKey) as! String?
    }
    
    var username :String? {
        return NSUserDefaults.standardUserDefaults().objectForKey(usernameKey) as! String?
    }
    
    func defaultLeadTime() -> NSNumber {
        return (NSUserDefaults.standardUserDefaults().objectForKey(self.defaultLeadtimeKey) ?? 0) as! NSNumber
    }
    
    func setDefaultLeadTime(leadtime : NSNumber) {
        NSUserDefaults.standardUserDefaults().setObject(leadtime, forKey: self.defaultLeadtimeKey)
        NSUserDefaults.standardUserDefaults().synchronize()
        let goals = Goal.MR_findByAttribute("use_defaults", withValue: NSNumber(bool: true)) as! [Goal]
        for goal in goals {
            goal.leadtime = leadtime
        }
        NSManagedObjectContext.MR_defaultContext().MR_saveToPersistentStoreWithCompletion(nil)
    }
    
    func defaultAlertstart() -> NSNumber {
        return (NSUserDefaults.standardUserDefaults().objectForKey(self.defaultAlertstartKey) ?? 0) as! NSNumber
    }
    
    func setDefaultAlertstart(alertstart : NSNumber) {
        NSUserDefaults.standardUserDefaults().setObject(alertstart, forKey: self.defaultAlertstartKey)
        NSUserDefaults.standardUserDefaults().synchronize()
        let goals = Goal.MR_findByAttribute("use_defaults", withValue: NSNumber(bool: true)) as! [Goal]
        for goal in goals {
            goal.alertstart = alertstart
        }
        NSManagedObjectContext.MR_defaultContext().MR_saveToPersistentStoreWithCompletion(nil)
    }
    
    func defaultDeadline() -> NSNumber {
        return (NSUserDefaults.standardUserDefaults().objectForKey(self.defaultDeadlineKey) ?? 0) as! NSNumber
    }
    
    func setDefaultDeadline(deadline : NSNumber) {
        NSUserDefaults.standardUserDefaults().setObject(deadline, forKey: self.defaultDeadlineKey)
        NSUserDefaults.standardUserDefaults().synchronize()
        let goals = Goal.MR_findByAttribute("use_defaults", withValue: NSNumber(bool: true)) as! [Goal]
        for goal in goals {
            goal.deadline = deadline
        }
        NSManagedObjectContext.MR_defaultContext().MR_saveToPersistentStoreWithCompletion(nil)
    }
    
    func signedIn() -> Bool {
        return self.accessToken != nil && self.username != nil
    }
    
    func isDeadbeat() -> Bool {
        return NSUserDefaults.standardUserDefaults().objectForKey(deadbeatKey) != nil
    }
    
    func setDeadbeat(deadbeat: Bool) {
        if deadbeat {
            NSUserDefaults.standardUserDefaults().setObject(true, forKey: deadbeatKey)
        } else {
            NSUserDefaults.standardUserDefaults().removeObjectForKey(deadbeatKey)
        }
        NSUserDefaults.standardUserDefaults().synchronize()
    }
    
    func setAccessToken(accessToken: String) {
        NSUserDefaults.standardUserDefaults().setObject(accessToken, forKey: accessTokenKey)
        NSUserDefaults.standardUserDefaults().synchronize()
    }
    
    func signInWithEmail(email: String, password: String) {
        BSHTTPSessionManager.sharedManager.POST("/api/private/sign_in", parameters: ["user": ["login": email, "password": password], "beemios_secret": self.beemiosSecret], success: { (dataTask, responseObject) -> Void in
            self.handleSuccessfulSignin(JSON(responseObject))
        }) { (dataTask, responseError) -> Void in
            self.handleFailedSignin(responseError)
            }
    }
    
    func handleSuccessfulSignin(responseJSON: JSON) {
        if responseJSON["deadbeat"].boolValue {
            self.setDeadbeat(true)
        }
        NSUserDefaults.standardUserDefaults().setObject(responseJSON[accessTokenKey].string!, forKey: accessTokenKey)
        NSUserDefaults.standardUserDefaults().setObject(responseJSON[usernameKey].string!, forKey: usernameKey)
        NSUserDefaults.standardUserDefaults().setObject(responseJSON[defaultAlertstartKey].number!, forKey: defaultAlertstartKey)
        NSUserDefaults.standardUserDefaults().setObject(responseJSON[defaultDeadlineKey].number!, forKey: defaultDeadlineKey)
        NSUserDefaults.standardUserDefaults().setObject(responseJSON[defaultLeadtimeKey].number!, forKey: defaultLeadtimeKey)
        NSUserDefaults.standardUserDefaults().synchronize()
        NSNotificationCenter.defaultCenter().postNotificationName(CurrentUserManager.signedInNotificationName, object: self)
    }
    
    func syncNotificationDefaults(success: (() -> Void)?, failure: (() -> Void)?) {
        BSHTTPSessionManager.sharedManager.GET("api/v1/users/me.json", parameters: [],
            success: { (task, responseObject) -> Void in
                let responseJSON = JSON(responseObject)
                NSUserDefaults.standardUserDefaults().setObject(responseJSON["default_alertstart"].number!, forKey: "default_alertstart")
                NSUserDefaults.standardUserDefaults().setObject(responseJSON["default_deadline"].number!, forKey: "default_deadline")
                NSUserDefaults.standardUserDefaults().setObject(responseJSON["default_leadtime"].number!, forKey: "default_leadtime")
                NSUserDefaults.standardUserDefaults().synchronize()
                if (success != nil) { success!() }
            }, failure: { (task, error) -> Void in
                if (failure != nil) { failure!() }
        })
    }
    
    func handleFailedSignin(responseError: NSError) {
        NSNotificationCenter.defaultCenter().postNotificationName(CurrentUserManager.failedSignInNotificationName, object: self, userInfo: ["error" : responseError])
        self.signOut()
    }
    
    func signOut() {
        NSNotificationCenter.defaultCenter().postNotificationName(CurrentUserManager.willSignOutNotificationName, object: self)
        NSUserDefaults.standardUserDefaults().removeObjectForKey(accessTokenKey)
        NSUserDefaults.standardUserDefaults().removeObjectForKey(deadbeatKey)
        NSUserDefaults.standardUserDefaults().removeObjectForKey(usernameKey)
        NSUserDefaults.standardUserDefaults().synchronize()
        for datapoint in Datapoint.MR_findAll() {
            datapoint.MR_deleteEntity()
        }
        for goal in Goal.MR_findAll() {
            goal.MR_deleteEntity()
        }
        NSManagedObjectContext.MR_defaultContext().MR_saveToPersistentStoreWithCompletion { (success: Bool, error: NSError!) -> Void in
            NSNotificationCenter.defaultCenter().postNotificationName(CurrentUserManager.signedOutNotificationName, object: self)
        }

    }
    
    func signInWithOAuthUserId(userId: String, provider: String) {
        BSHTTPSessionManager.sharedManager.signedPOST("/api/private/sign_in", parameters: ["oauth_user_id": userId, "provider": provider], success: { (dataTask, responseObject) -> Void in
            self.handleSuccessfulSignin(JSON(responseObject))
        }) { (dataTask, responseError) -> Void in
            self.handleFailedSignin(responseError)
        }
    }
    
    func loginButton(loginButton: FBSDKLoginButton!, didCompleteWithResult result: FBSDKLoginManagerLoginResult!, error: NSError!) {
        self.signInWithOAuthUserId(result.token.userID, provider: "facebook")
    }
    
    func loginButtonDidLogOut(loginButton: FBSDKLoginButton!) {
        // never called
    }
    
    func loginWithTwitterSession(session: TWTRSession!) {
        self.signInWithOAuthUserId(session.userID, provider: "twitter")
    }
    
    func signIn(signIn: GIDSignIn!, didSignInForUser user: GIDGoogleUser!, withError error: NSError!) {
        if error != nil {
            return
        }
        self.signInWithOAuthUserId(user.userID, provider: "google_oauth2")
    }
    
    func signIn(signIn: GIDSignIn!, didDisconnectWithUser user: GIDGoogleUser!, withError error: NSError!) {
        // never called
    }
}