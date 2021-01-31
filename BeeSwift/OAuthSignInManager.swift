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
    static let shared = OAuthSignInManager()
    
    func signUpWith(email: String, password: String, username: String) {
        SignedRequestManager.signedPOST(url: "/api/v1/users", parameters: ["email": email, "password": password, "username": username], success: { (responseObject) -> Void in
            CurrentUserManager.shared.handleSuccessfulSignin(JSON(responseObject!))
        }) { (responseError, errorMessage) -> Void in
            if responseError != nil  { CurrentUserManager.shared.handleFailedSignup(responseError!, errorMessage: errorMessage) }
        }
    }
}
