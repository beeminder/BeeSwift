//
//  SignInViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/26/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation
import MBProgressHUD
import SafariServices

import BeeKit

class SignInViewController : UIViewController, UITextFieldDelegate {
    
    var headerLabel = BSLabel()
    var emailTextField = BSTextField()
    var passwordTextField = BSTextField()
    var beeImageView = UIImageView()
    var signInButton = BSButton()
    var divider = UIView()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let scrollView = UIScrollView()
        self.view.addSubview(scrollView)
        scrollView.snp.makeConstraints { (make) -> Void in
            make.edges.equalTo(self.view)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleFailedSignIn(_:)), name: NSNotification.Name(rawValue: CurrentUserManager.failedSignInNotificationName), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleSignedIn(_:)), name: NSNotification.Name(rawValue: CurrentUserManager.signedInNotificationName), object: nil)
        self.view.backgroundColor = UIColor.systemBackground
        
        
        self.beeImageView.image = UIImage(named: "website_logo_mid")
        scrollView.addSubview(self.beeImageView)
        self.beeImageView.snp.makeConstraints { (make) in
            make.centerX.equalTo(scrollView)
            make.centerY.equalToSuperview().multipliedBy(0.55)
        }
        
        scrollView.addSubview(self.headerLabel)
        self.headerLabel.textAlignment = NSTextAlignment.center
        self.headerLabel.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(beeImageView.snp.bottom)
            make.centerX.equalToSuperview()
        }
        
        scrollView.addSubview(self.emailTextField)
        self.emailTextField.isHidden = true
        self.emailTextField.placeholder = "Email or username"
        self.emailTextField.autocapitalizationType = .none
        self.emailTextField.autocorrectionType = .no
        self.emailTextField.keyboardType = UIKeyboardType.emailAddress
        self.emailTextField.returnKeyType = .next
        self.emailTextField.delegate = self
        self.emailTextField.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(self.headerLabel.snp.bottom).offset(15)
            make.centerX.equalTo(scrollView)
            make.width.equalTo(scrollView).multipliedBy(0.75)
            make.height.equalTo(Constants.defaultTextFieldHeight)
        }
        
        scrollView.addSubview(self.passwordTextField)
        self.passwordTextField.isHidden = true
        self.passwordTextField.placeholder = "Password"
        self.passwordTextField.isSecureTextEntry = true
        self.passwordTextField.returnKeyType = .done
        self.passwordTextField.autocapitalizationType = .none
        self.passwordTextField.delegate = self
        self.passwordTextField.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(self.emailTextField.snp.bottom).offset(15)
            make.centerX.equalTo(self.emailTextField)
            make.width.equalTo(self.emailTextField)
            make.height.equalTo(Constants.defaultTextFieldHeight)
        }

        scrollView.addSubview(self.signInButton)
        self.signInButton.isHidden = true
        self.signInButton.setTitle("Sign In", for: UIControl.State())
        self.signInButton.titleLabel?.font = UIFont.beeminder.defaultFontPlain.withSize(20)
        self.signInButton.titleLabel?.textColor = UIColor.white
        self.signInButton.addTarget(self, action: #selector(SignInViewController.signInButtonPressed), for: UIControl.Event.touchUpInside)
        self.signInButton.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(self.passwordTextField)
            make.right.equalTo(self.passwordTextField)
            make.top.equalTo(self.passwordTextField.snp.bottom).offset(15)
            make.height.equalTo(Constants.defaultTextFieldHeight)
        }
        
        scrollView.addSubview(self.divider)
        self.divider.isHidden = true
        self.divider.backgroundColor = UIColor.Beeminder.gray
        
        self.chooseSignInButtonPressed()
    }
    
    @objc func chooseSignInButtonPressed() {
        self.emailTextField.isHidden = false
        self.passwordTextField.isHidden = false
        self.headerLabel.text = "Sign in to Beeminder"
        self.headerLabel.isHidden = false
        self.signInButton.isHidden = false
        self.divider.snp.remakeConstraints { (make) -> Void in
            make.left.equalTo(self.signInButton)
            make.right.equalTo(self.signInButton)
            make.height.equalTo(1)
            make.top.equalTo(self.signInButton.snp.bottom).offset(15)
        }
    }
    
    var missingDataOnSignIn: UIAlertController {
        let lackOfCredentials = UIAlertController(title: "Incomplete Account Details", message: "Username and Password are required", preferredStyle: .alert)
        lackOfCredentials.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        
        return lackOfCredentials
    }
    
    @objc func handleFailedSignIn(_ notification : Notification) {
        let failureAC = UIAlertController(title: "Could not sign in", message: "Invalid credentials", preferredStyle: .alert)
        failureAC.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        self.present(failureAC, animated: true, completion: nil)
        MBProgressHUD.hide(for: self.view, animated: true)
    }
    
    @objc func handleSignedIn(_ notification : Notification) {
        MBProgressHUD.hide(for: self.view, animated: true)
    }
    
    @objc func signInButtonPressed() {
        Task { @MainActor in
            guard let email = self.emailTextField.text?.trimmingCharacters(in: .whitespaces), let password = self.passwordTextField.text, !email.isEmpty, !password.isEmpty else {
                self.present(self.missingDataOnSignIn, animated: true, completion: nil)
                return
            }

            MBProgressHUD.showAdded(to: self.view, animated: true)
            await ServiceLocator.currentUserManager.signInWithEmail(email, password: password)
        }
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
