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
    private let accessTokenKey = "accessToken"
    private let beemiosSecret = "C0QBFPWqDykIgE6RyQ2OJJDxGxGXuVA2CNqcJM185oOOl4EQTjmpiKgcwjki"
    
    var accessToken :String? {
        return NSUserDefaults.standardUserDefaults().objectForKey(accessTokenKey) as! String?
    }
    
    func setAccessToken(accessToken: String) {
        NSUserDefaults.standardUserDefaults().setObject(accessToken, forKey: accessTokenKey)
        NSUserDefaults.standardUserDefaults().synchronize()
    }
    
    func signInWithEmail(email: String, password: String, success: (()->Void)!, error: ((message: String)->Void)!) {        
        BSHTTPSessionManager.sharedManager.POST("/api/private/sign_in", parameters: ["user": ["login": email, "password": password], "beemios_secret": self.beemiosSecret], success: { (dataTask, responseObject) -> Void in
            NSUserDefaults.standardUserDefaults().setObject(responseObject["access_token"], forKey: self.accessTokenKey)
            NSUserDefaults.standardUserDefaults().synchronize()
            success()
        }) { (dataTask, responseError) -> Void in
            error(message: responseError.description)
            }
    }
    
    func signOut() {
        DataSyncManager.sharedManager.setLastSynced(nil)
        LocalNotificationsManager.sharedManager.turnNotificationsOff()
        NSUserDefaults.standardUserDefaults().removeObjectForKey(accessTokenKey)
        NSUserDefaults.standardUserDefaults().synchronize()
        for goal in Goal.MR_findAll() {
            goal.MR_deleteEntity()
        }
        NSManagedObjectContext.MR_defaultContext().save(nil)
    }
    
    func loginButton(loginButton: FBSDKLoginButton!, didCompleteWithResult result: FBSDKLoginManagerLoginResult!, error: NSError!) {
        //facebook
    }
    
    func loginButtonDidLogOut(loginButton: FBSDKLoginButton!) {
        //facebook
    }
    
    func loginWithTwitterSession(session: TWTRSession!, error: NSError!) {
        //twitter
    }
    
    func signIn(signIn: GIDSignIn!, didDisconnectWithUser user: GIDGoogleUser!, withError error: NSError!) {
        //foo
    }
    
    func signIn(signIn: GIDSignIn!, didSignInForUser user: GIDGoogleUser!, withError error: NSError!) {
        //foo
    }

}