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
import TwitterKit

class CurrentUserManager : NSObject, GIDSignInDelegate, FBSDKLoginButtonDelegate {
    
    static let sharedManager = CurrentUserManager()
    static let signedInNotificationName     = "com.beeminder.signedInNotification"
    static let failedSignInNotificationName = "com.beeminder.failedSignInNotification"
    static let signedOutNotificationName    = "com.beeminder.signedOutNotification"
    private let accessTokenKey = "access_token"
    private let usernameKey = "username"
    private let beemiosSecret = "C0QBFPWqDykIgE6RyQ2OJJDxGxGXuVA2CNqcJM185oOOl4EQTjmpiKgcwjki"
    
    var accessToken :String? {
        return NSUserDefaults.standardUserDefaults().objectForKey(accessTokenKey) as! String?
    }
    
    var username :String? {
        return NSUserDefaults.standardUserDefaults().objectForKey(usernameKey) as! String?
    }
    
    func signedIn() -> Bool {
        return self.accessToken != nil && self.username != nil
    }
    
    func setAccessToken(accessToken: String) {
        NSUserDefaults.standardUserDefaults().setObject(accessToken, forKey: accessTokenKey)
        NSUserDefaults.standardUserDefaults().synchronize()
    }
    
    func signInWithEmail(email: String, password: String) {
        BSHTTPSessionManager.sharedManager.POST("/api/private/sign_in", parameters: ["user": ["login": email, "password": password], "beemios_secret": self.beemiosSecret], success: { (dataTask, responseObject) -> Void in
            self.handleSuccessfulSignin(responseObject)
        }) { (dataTask, responseError) -> Void in
            self.handleFailedSignin(responseError)
            }
    }
    
    func handleSuccessfulSignin(responseObject: AnyObject) {
        NSUserDefaults.standardUserDefaults().setObject(responseObject[accessTokenKey] as! String, forKey: accessTokenKey)
        NSUserDefaults.standardUserDefaults().setObject(responseObject[usernameKey] as! String, forKey: usernameKey)
        NSUserDefaults.standardUserDefaults().synchronize()
        NSNotificationCenter.defaultCenter().postNotificationName(CurrentUserManager.signedInNotificationName, object: self)
    }
    
    func handleFailedSignin(responseError: NSError) {
        NSNotificationCenter.defaultCenter().postNotificationName(CurrentUserManager.failedSignInNotificationName, object: self, userInfo: ["error" : responseError])
        self.signOut()
    }
    
    func signOut() {
        NSUserDefaults.standardUserDefaults().removeObjectForKey(accessTokenKey)
        NSUserDefaults.standardUserDefaults().synchronize()
        for datapoint in Datapoint.MR_findAll() {
            datapoint.MR_deleteEntity()
        }
        for goal in Goal.MR_findAll() {
            goal.MR_deleteEntity()
        }
        NSManagedObjectContext.MR_defaultContext().save(nil)
        NSNotificationCenter.defaultCenter().postNotificationName(CurrentUserManager.signedOutNotificationName, object: self)
    }
    
    func signInWithOAuthUserId(userId: String, provider: String) {
        BSHTTPSessionManager.sharedManager.signedPOST("/api/private/sign_in", parameters: ["oauth_user_id" : userId, "provider" : provider], success: { (dataTask, responseObject) -> Void in
            self.handleSuccessfulSignin(responseObject)
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
        self.signInWithOAuthUserId(user.userID, provider: "google_oauth2")
    }
    
    func signIn(signIn: GIDSignIn!, didDisconnectWithUser user: GIDGoogleUser!, withError error: NSError!) {
        // never called
    }
}