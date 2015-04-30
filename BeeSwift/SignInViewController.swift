//
//  SignInViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/26/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation

class SignInViewController : UIViewController {
    
    var signInLabel :BSLabel = BSLabel()
    var emailTextField :UITextField = UITextField()
    var passwordTextField :UITextField = UITextField()
    
    override func viewDidLoad() {
        self.view.backgroundColor = UIColor.whiteColor()
        
        self.view.addSubview(self.signInLabel)
        self.signInLabel.text = "Sign in to Beeminder"
        self.signInLabel.textAlignment = NSTextAlignment.Center
        self.signInLabel.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(50)
            make.left.equalTo(0)
            make.right.equalTo(0)
        }
        
        self.view.addSubview(self.emailTextField)
        self.emailTextField.layer.borderColor = UIColor.beeGrayColor().CGColor
        self.emailTextField.tintColor = UIColor.beeGrayColor()
        self.emailTextField.layer.borderWidth = 1
        self.emailTextField.placeholder = "Email"
        self.emailTextField.textAlignment = NSTextAlignment.Center
        self.emailTextField.font = UIFont(name: "Avenir", size: 20)
        self.emailTextField.keyboardType = UIKeyboardType.EmailAddress
        self.emailTextField.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(self.signInLabel.snp_bottom).offset(20)
            make.centerX.equalTo(0)
            make.width.equalTo(self.view).multipliedBy(0.75)
            make.height.equalTo(44)
        }
        
        self.view.addSubview(self.passwordTextField)
        self.passwordTextField.layer.borderColor = UIColor.beeGrayColor().CGColor
        self.passwordTextField.tintColor = UIColor.beeGrayColor()
        self.passwordTextField.layer.borderWidth = 1
        self.passwordTextField.placeholder = "Password"
        self.passwordTextField.textAlignment = NSTextAlignment.Center
        self.passwordTextField.font = UIFont(name: "Avenir", size: 20)
        self.passwordTextField.secureTextEntry = true
        self.passwordTextField.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(self.emailTextField.snp_bottom).offset(20)
            make.centerX.equalTo(0)
            make.width.equalTo(self.view).multipliedBy(0.75)
            make.height.equalTo(44)
        }
        
        var signInButton = UIButton()
        self.view.addSubview(signInButton)
        signInButton.setTitle("Sign In", forState: UIControlState.Normal)
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
    }
    
    func signInButtonPressed() {
        CurrentUserManager.sharedManager.signInWithEmail(self.emailTextField.text, password: self.passwordTextField.text, success: { () -> Void in
            self.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
            }) { (message: String) -> Void in
            println(message)
        }
    }
    
}