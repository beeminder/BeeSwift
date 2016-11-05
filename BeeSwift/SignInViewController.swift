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
        NotificationCenter.default.addObserver(self, selector: #selector(SignInViewController.handleFailedSignIn(_:)), name: NSNotification.Name(rawValue: CurrentUserManager.failedSignInNotificationName), object: nil)
        self.view.backgroundColor = UIColor.white
        
        let scrollView = UIScrollView()
        self.view.addSubview(scrollView)
        scrollView.snp.makeConstraints { (make) -> Void in
            make.edges.equalTo(self.view)
        }
        
        scrollView.addSubview(self.signInLabel)
        self.signInLabel.text = "Sign in to Beeminder"
        self.signInLabel.textAlignment = NSTextAlignment.center
        self.signInLabel.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(50)
            make.centerX.equalTo(scrollView)
        }
        
        scrollView.addSubview(self.emailTextField)
        self.emailTextField.layer.borderColor = UIColor.beeGrayColor().cgColor
        self.emailTextField.tintColor = UIColor.beeGrayColor()
        self.emailTextField.layer.borderWidth = 1
        self.emailTextField.placeholder = "Email or username"
        self.emailTextField.autocapitalizationType = .none
        self.emailTextField.autocorrectionType = .no
        self.emailTextField.textAlignment = NSTextAlignment.center
        self.emailTextField.font = UIFont(name: "Avenir", size: 20)
        self.emailTextField.keyboardType = UIKeyboardType.emailAddress
        self.emailTextField.returnKeyType = .next
        self.emailTextField.delegate = self
        self.emailTextField.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(self.signInLabel.snp.bottom).offset(20)
            make.centerX.equalTo(0)
            make.width.equalTo(scrollView).multipliedBy(0.75)
            make.height.equalTo(44)
        }
        
        scrollView.addSubview(self.passwordTextField)
        self.passwordTextField.layer.borderColor = UIColor.beeGrayColor().cgColor
        self.passwordTextField.tintColor = UIColor.beeGrayColor()
        self.passwordTextField.layer.borderWidth = 1
        self.passwordTextField.placeholder = "Password"
        self.passwordTextField.textAlignment = NSTextAlignment.center
        self.passwordTextField.font = UIFont(name: "Avenir", size: 20)
        self.passwordTextField.isSecureTextEntry = true
        self.passwordTextField.returnKeyType = .done
        self.passwordTextField.delegate = self
        self.passwordTextField.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(self.emailTextField.snp.bottom).offset(20)
            make.centerX.equalTo(self.emailTextField)
            make.width.equalTo(self.emailTextField)
            make.height.equalTo(44)
        }
        
        let signInButton = UIButton()
        scrollView.addSubview(signInButton)
        signInButton.setTitle("Sign In", for: UIControlState())
        signInButton.backgroundColor = UIColor.beeGrayColor()
        signInButton.titleLabel?.font = UIFont(name: "Avenir", size: 20)
        signInButton.titleLabel?.textColor = UIColor.white
        signInButton.addTarget(self, action: #selector(SignInViewController.signInButtonPressed), for: UIControlEvents.touchUpInside)
        signInButton.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(self.passwordTextField)
            make.right.equalTo(self.passwordTextField)
            make.top.equalTo(self.passwordTextField.snp.bottom).offset(20)
            make.height.equalTo(44)
        }
        
        let divider = UIView()
        scrollView.addSubview(divider)
        divider.backgroundColor = UIColor.beeGrayColor()
        divider.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(signInButton)
            make.right.equalTo(signInButton)
            make.height.equalTo(1)
            make.top.equalTo(signInButton.snp.bottom).offset(20)
        }

        let twitterLoginButton = TWTRLogInButton { (session, error) in
            if error == nil {
                CurrentUserManager.sharedManager.loginWithTwitterSession(session)
            }
            else {
                // show error
            }
        }
        
        scrollView.addSubview(twitterLoginButton!)
        twitterLoginButton?.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(divider.snp.bottom).offset(20)
            make.centerX.equalTo(signInButton)
            make.width.equalTo(signInButton)
            make.height.equalTo(signInButton)
        }
        
        let facebookLoginButton : FBSDKLoginButton = FBSDKLoginButton()
        scrollView.addSubview(facebookLoginButton)
        facebookLoginButton.readPermissions = ["public_profile", "email", "user_friends"]
        facebookLoginButton.delegate = self
        facebookLoginButton.snp.makeConstraints { (make) -> Void in
            make.top.equalTo((twitterLoginButton?.snp.bottom)!).offset(20)
            make.centerX.equalTo(signInButton)
            make.width.equalTo(signInButton)
            make.height.equalTo(signInButton)
        }
        if FBSDKAccessToken.current() != nil {
            FBSDKAccessToken.setCurrent(nil)
        }
        
        let googleSigninButton = GIDSignInButton()
        GIDSignIn.sharedInstance().uiDelegate = self
        GIDSignIn.sharedInstance().delegate = CurrentUserManager.sharedManager
        GIDSignIn.sharedInstance().scopes = ["profile", "email"]
        GIDSignIn.sharedInstance().shouldFetchBasicProfile = true
        scrollView.addSubview(googleSigninButton)
        googleSigninButton.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(facebookLoginButton.snp.bottom).offset(20)
            make.centerX.equalTo(signInButton)
            make.width.equalTo(signInButton)
            make.height.equalTo(signInButton)
            make.bottom.equalTo(-20)
        }
    }
    
    func alertView(_ alertView: UIAlertView, clickedButtonAt buttonIndex: Int) {
        if buttonIndex == 1 {
            UIApplication.shared.openURL(URL(string: "https://www.beeminder.com")!)
        }
    }
    
    func loginButton(_ loginButton: FBSDKLoginButton!, didCompleteWith result: FBSDKLoginManagerLoginResult!, error: Error!) {
        // show message if error
        CurrentUserManager.sharedManager.loginButton(loginButton, didCompleteWith: result, error: error as NSError!)
    }
    
    func loginButtonDidLogOut(_ loginButton: FBSDKLoginButton!) {
        CurrentUserManager.sharedManager.loginButtonDidLogOut(loginButton)
    }
    
    func handleFailedSignIn(_ notification : Notification) {
//        notification.userInfo["error"]
        UIAlertView(title: "Could not sign in", message: "Invalid credentials", delegate: self, cancelButtonTitle: "OK").show()
    }
    
    func signInButtonPressed() {
        CurrentUserManager.sharedManager.signInWithEmail(self.emailTextField.text!, password: self.passwordTextField.text!)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField.isEqual(self.emailTextField) {
            self.passwordTextField.becomeFirstResponder()
        }
        else if textField.isEqual(self.passwordTextField) {
            self.signInButtonPressed()
        }
        return true
    }
    
}
