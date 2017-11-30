//
//  OAuthSignInManager.swift
//  BeeSwift
//
//  Created by Andy Brett on 11/30/17.
//  Copyright © 2017 APB. All rights reserved.
//

import Foundation
import FBSDKLoginKit
import SwiftyJSON
import TwitterKit

class OAuthSignInManager: NSObject, GIDSignInDelegate, FBSDKLoginButtonDelegate {
    static let sharedManager = OAuthSignInManager()
    
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
    
    func sign(_ signIn: GIDSignIn!, didDisconnectWith user: GIDGoogleUser!, withError error: Error!) {
        // never called
    }
    
    func signUpWith(email: String, password: String, username: String) {
        SignedRequestManager.signedPOST(url: "/api/v1/users", parameters: ["email": email, "password": password, "username": username], success: { (responseObject) -> Void in
            CurrentUserManager.sharedManager.handleSuccessfulSignin(JSON(responseObject!))
        }) { (responseError) -> Void in
            if responseError != nil  { CurrentUserManager.sharedManager.handleFailedSignup(responseError!) }
        }
    }
    
    func signInWithOAuthUserId(_ userId: String, provider: String) {
        let params = ["oauth_user_id": userId, "provider": provider]
        SignedRequestManager.signedPOST(url: "api/private/sign_in", parameters: params, success: { (responseObject) -> Void in
            CurrentUserManager.sharedManager.handleSuccessfulSignin(JSON(responseObject!))
        }) { (responseError) -> Void in
            if responseError != nil { CurrentUserManager.sharedManager.handleFailedSignin(responseError!) }
        }
    }
}
