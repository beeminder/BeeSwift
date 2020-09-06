//
//  OAuthSignInManager.swift
//  BeeSwift
//
//  Created by Andy Brett on 11/30/17.
//  Copyright © 2017 APB. All rights reserved.
//

import Foundation
import SwiftyJSON

class OAuthSignInManager: NSObject {
    static let sharedManager = OAuthSignInManager()
    
    func signUpWith(email: String, password: String, username: String) {
        SignedRequestManager.signedPOST(url: "/api/v1/users", parameters: ["email": email, "password": password, "username": username], success: { (responseObject) -> Void in
            CurrentUserManager.sharedManager.handleSuccessfulSignup(JSON(responseObject!))
        }) { (responseError) -> Void in
            if responseError != nil  { CurrentUserManager.sharedManager.handleFailedSignup(responseError!) }
        }
    }
}
