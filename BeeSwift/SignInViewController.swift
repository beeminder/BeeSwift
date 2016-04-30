//
//  SignInViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/26/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation
import TwitterKit
import FBSDKLoginKit

class SignInViewController : UIViewController, FBSDKLoginButtonDelegate, GIDSignInUIDelegate, UITextFieldDelegate, UIAlertViewDelegate {
    
    var signInLabel :BSLabel = BSLabel()
    var emailTextField :UITextField = UITextField()
    var passwordTextField :UITextField = UITextField()
    
    override func viewDidLoad() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(SignInViewController.handleFailedSignIn(_:)), name: CurrentUserManager.failedSignInNotificationName, object: nil)
        self.view.backgroundColor = UIColor.whiteColor()
        
        let scrollView = UIScrollView()
        self.view.addSubview(scrollView)
        scrollView.snp_makeConstraints { (make) -> Void in
            make.edges.equalTo(self.view)
        }
        
        scrollView.addSubview(self.signInLabel)
        self.signInLabel.text = "Sign in to Beeminder"
        self.signInLabel.textAlignment = NSTextAlignment.Center
        self.signInLabel.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(50)
            make.centerX.equalTo(scrollView)
        }
        
        scrollView.addSubview(self.emailTextField)
        self.emailTextField.layer.borderColor = UIColor.beeGrayColor().CGColor
        self.emailTextField.tintColor = UIColor.beeGrayColor()
        self.emailTextField.layer.borderWidth = 1
        self.emailTextField.placeholder = "Email or username"
        self.emailTextField.autocapitalizationType = .None
        self.emailTextField.autocorrectionType = .No
        self.emailTextField.textAlignment = NSTextAlignment.Center
        self.emailTextField.font = UIFont(name: "Avenir", size: 20)
        self.emailTextField.keyboardType = UIKeyboardType.EmailAddress
        self.emailTextField.returnKeyType = .Next
        self.emailTextField.delegate = self
        self.emailTextField.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(self.signInLabel.snp_bottom).offset(20)
            make.centerX.equalTo(0)
            make.width.equalTo(scrollView).multipliedBy(0.75)
            make.height.equalTo(44)
        }
        
        scrollView.addSubview(self.passwordTextField)
        self.passwordTextField.layer.borderColor = UIColor.beeGrayColor().CGColor
        self.passwordTextField.tintColor = UIColor.beeGrayColor()
        self.passwordTextField.layer.borderWidth = 1
        self.passwordTextField.placeholder = "Password"
        self.passwordTextField.textAlignment = NSTextAlignment.Center
        self.passwordTextField.font = UIFont(name: "Avenir", size: 20)
        self.passwordTextField.secureTextEntry = true
        self.passwordTextField.returnKeyType = .Done
        self.passwordTextField.delegate = self
        self.passwordTextField.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(self.emailTextField.snp_bottom).offset(20)
            make.centerX.equalTo(self.emailTextField)
            make.width.equalTo(self.emailTextField)
            make.height.equalTo(44)
        }
        
        let signInButton = UIButton()
        scrollView.addSubview(signInButton)
        signInButton.setTitle("Sign In", forState: .Normal)
        signInButton.backgroundColor = UIColor.beeGrayColor()
        signInButton.titleLabel?.font = UIFont(name: "Avenir", size: 20)
        signInButton.titleLabel?.textColor = UIColor.whiteColor()
        signInButton.addTarget(self, action: "signInButtonPressed", forControlEvents: UIControlEvents.TouchUpInside)
        signInButton.snp_makeConstraints { (make) -> Void in
            make.left.equalTo(self.passwordTextField)
            make.right.equalTo(self.passwordTextField)
            make.top.equalTo(self.passwordTextField.snp_bottom).offset(20)
            make.height.equalTo(44)
        }
        
        let divider = UIView()
        scrollView.addSubview(divider)
        divider.backgroundColor = UIColor.beeGrayColor()
        divider.snp_makeConstraints { (make) -> Void in
            make.left.equalTo(signInButton)
            make.right.equalTo(signInButton)
            make.height.equalTo(1)
            make.top.equalTo(signInButton.snp_bottom).offset(20)
        }

        let twitterLoginButton = TWTRLogInButton(logInCompletion: {
            (session: TWTRSession!, error: NSError!) in
            if error == nil {
                CurrentUserManager.sharedManager.loginWithTwitterSession(session)
            }
            else {
                // show error
            }
        })
        scrollView.addSubview(twitterLoginButton)
        twitterLoginButton.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(divider.snp_bottom).offset(20)
            make.centerX.equalTo(signInButton)
            make.width.equalTo(signInButton)
            make.height.equalTo(signInButton)
        }
        
        let facebookLoginButton : FBSDKLoginButton = FBSDKLoginButton()
        scrollView.addSubview(facebookLoginButton)
        facebookLoginButton.readPermissions = ["public_profile", "email", "user_friends"]
        facebookLoginButton.delegate = self
        facebookLoginButton.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(twitterLoginButton.snp_bottom).offset(20)
            make.centerX.equalTo(signInButton)
            make.width.equalTo(signInButton)
            make.height.equalTo(signInButton)
        }
        if FBSDKAccessToken.currentAccessToken() != nil {
            FBSDKAccessToken.setCurrentAccessToken(nil)
        }
        
        let googleSigninButton = GIDSignInButton()
        GIDSignIn.sharedInstance().uiDelegate = self
        GIDSignIn.sharedInstance().delegate = CurrentUserManager.sharedManager
        GIDSignIn.sharedInstance().scopes = ["profile", "email"]
        GIDSignIn.sharedInstance().shouldFetchBasicProfile = true
        scrollView.addSubview(googleSigninButton)
        googleSigninButton.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(facebookLoginButton.snp_bottom).offset(20)
            make.centerX.equalTo(signInButton)
            make.width.equalTo(signInButton)
            make.height.equalTo(signInButton)
            make.bottom.equalTo(-20)
        }
    }
    
    func alertView(alertView: UIAlertView, clickedButtonAtIndex buttonIndex: Int) {
        if buttonIndex == 1 {
            UIApplication.sharedApplication().openURL(NSURL(string: "https://www.beeminder.com")!)
        }
    }
    
    func loginButton(loginButton: FBSDKLoginButton!, didCompleteWithResult result: FBSDKLoginManagerLoginResult!, error: NSError!) {
        // show message if error
        CurrentUserManager.sharedManager.loginButton(loginButton, didCompleteWithResult: result, error: error)
    }
    
    func loginButtonDidLogOut(loginButton: FBSDKLoginButton!) {
        CurrentUserManager.sharedManager.loginButtonDidLogOut(loginButton)
    }
    
    func handleFailedSignIn(notification : NSNotification) {
//        notification.userInfo["error"]
        UIAlertView(title: "Could not sign in", message: "Invalid credentials", delegate: self, cancelButtonTitle: "OK").show()
    }
    
    func signInButtonPressed() {
        CurrentUserManager.sharedManager.signInWithEmail(self.emailTextField.text!, password: self.passwordTextField.text!)
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        if textField.isEqual(self.emailTextField) {
            self.passwordTextField.becomeFirstResponder()
        }
        else if textField.isEqual(self.passwordTextField) {
            self.signInButtonPressed()
        }
        return true
    }
    
}