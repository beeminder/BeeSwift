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

class SignInViewController : UIViewController, UITextFieldDelegate, SFSafariViewControllerDelegate {
    
    var headerLabel = BSLabel()
    var emailTextField = BSTextField()
    var passwordTextField = BSTextField()
    var newEmailTextField = BSTextField()
    var newUsernameTextField = BSTextField()
    var newPasswordTextField = BSTextField()
    var chooseSignInButton = BSButton()
    var chooseSignUpButton = BSButton()
    var beeImageView = UIImageView()
    var signUpButton = BSButton()
    var backToSignInButton = BSButton()
    var backToSignUpButton = BSButton()
    var signInButton = BSButton()
    var divider = UIView()
    lazy var resetPasswordButton: BSButton = {
        let button = BSButton()
        button.setTitle("Forgot password?", for: .normal)
        button.titleLabel?.font = UIFont.beeminder.defaultFontHeavy
        button.setTitleColor(UIColor.label, for: .normal)
        button.backgroundColor = UIColor.systemBackground
        button.addTarget(self, action: #selector(SignInViewController.resetPasswordTapped), for: .touchUpInside)

        return button
    }()
    
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
            make.top.equalTo(beeImageView.snp_bottom)
            make.centerX.equalToSuperview()
        }
        
        scrollView.addSubview(self.chooseSignInButton)
        self.chooseSignInButton.setTitle("I have a Beeminder account", for: .normal)
        self.chooseSignInButton.snp.makeConstraints { (make) in
            make.centerX.equalToSuperview()
            make.top.equalTo(self.headerLabel.snp_bottom).offset(40)
            make.width.equalToSuperview().multipliedBy(0.75)
            make.height.equalTo(Constants.defaultTextFieldHeight)
        }
        self.chooseSignInButton.addTarget(self, action: #selector(SignInViewController.chooseSignInButtonPressed), for: .touchUpInside)
        
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

        scrollView.addSubview(self.resetPasswordButton)
        self.resetPasswordButton.isHidden = true
        self.resetPasswordButton.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(self.passwordTextField)
            make.right.equalTo(self.passwordTextField)
            make.top.equalTo(self.passwordTextField.snp.bottom).offset(15)
            make.height.equalTo(Constants.defaultTextFieldHeight)
        }
        
        scrollView.addSubview(self.signInButton)
        self.signInButton.isHidden = true
        self.signInButton.setTitle("Sign In", for: UIControl.State())
        self.signInButton.backgroundColor = UIColor.beeminder.gray
        self.signInButton.titleLabel?.font = UIFont.beeminder.defaultFontPlain.withSize(20)
        self.signInButton.titleLabel?.textColor = UIColor.white
        self.signInButton.addTarget(self, action: #selector(SignInViewController.signInButtonPressed), for: UIControl.Event.touchUpInside)
        self.signInButton.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(self.passwordTextField)
            make.right.equalTo(self.passwordTextField)
            make.top.equalTo(self.resetPasswordButton.snp.bottom).offset(15)
            make.height.equalTo(Constants.defaultTextFieldHeight)
        }
        
        scrollView.addSubview(self.divider)
        self.divider.isHidden = true
        self.divider.backgroundColor = UIColor.beeminder.gray
        
        scrollView.addSubview(self.newUsernameTextField)
        self.newUsernameTextField.isHidden = true
        self.newUsernameTextField.autocapitalizationType = .none
        self.newUsernameTextField.snp.makeConstraints { (make) in
            make.top.equalTo(self.headerLabel.snp.bottom).offset(15)
            make.centerX.equalTo(scrollView)
            make.height.equalTo(Constants.defaultTextFieldHeight)
            make.width.equalTo(self.view).multipliedBy(0.75)
        }
        self.newUsernameTextField.placeholder = "Username"
        
        scrollView.addSubview(self.newEmailTextField)
        self.newEmailTextField.isHidden = true
        self.newEmailTextField.autocapitalizationType = .none
        self.newEmailTextField.snp.makeConstraints { (make) in
            make.top.equalTo(self.newUsernameTextField.snp.bottom).offset(15)
            make.centerX.equalTo(scrollView)
            make.height.equalTo(Constants.defaultTextFieldHeight)
            make.width.equalTo(self.view).multipliedBy(0.75)
        }
        self.newEmailTextField.placeholder = "Email"
        
        scrollView.addSubview(self.newPasswordTextField)
        self.newPasswordTextField.isHidden = true
        self.newPasswordTextField.autocapitalizationType = .none
        self.newPasswordTextField.isSecureTextEntry = true
        self.newPasswordTextField.snp.makeConstraints { (make) in
            make.top.equalTo(self.newEmailTextField.snp.bottom).offset(15)
            make.centerX.equalTo(scrollView)
            make.height.equalTo(Constants.defaultTextFieldHeight)
            make.width.equalTo(self.view).multipliedBy(0.75)
        }
        
        self.newPasswordTextField.placeholder = "Password"
        
        scrollView.addSubview(self.signUpButton)
        self.signUpButton.isHidden = true
        self.signUpButton.setTitle("Sign Up", for: .normal)
        self.signUpButton.titleLabel?.font = UIFont.beeminder.defaultFontPlain.withSize(20)
        self.signUpButton.snp.makeConstraints { (make) in
            make.top.equalTo(self.newPasswordTextField.snp.bottom).offset(15)
            make.centerX.equalTo(self.view)
            make.height.equalTo(Constants.defaultTextFieldHeight)
            make.width.equalTo(self.view).multipliedBy(0.75)
        }
        
        scrollView.addSubview(self.backToSignInButton)
        self.backToSignInButton.isHidden = true
        self.backToSignInButton.setTitle("Back to Sign In", for: .normal)
        self.backToSignInButton.snp.makeConstraints { (make) in
            make.top.equalTo(divider.snp.bottom).offset(15)
            make.height.equalTo(Constants.defaultTextFieldHeight)
            make.centerX.equalTo(self.view)
            make.width.equalTo(self.view).multipliedBy(0.75)
        }
        self.backToSignInButton.addTarget(self, action: #selector(SignInViewController.chooseSignInButtonPressed), for: .touchUpInside)
        self.chooseSignInButtonPressed()
    }
    
    @objc func chooseSignInButtonPressed() {
        CurrentUserManager.sharedManager.signingUp = false
        //self.divider.isHidden = false
        //self.backToSignUpButton.isHidden = false
        self.emailTextField.isHidden = false
        self.passwordTextField.isHidden = false
        self.backToSignInButton.isHidden = true
        self.newUsernameTextField.isHidden = true
        self.newPasswordTextField.isHidden = true
        self.newEmailTextField.isHidden = true
        self.chooseSignInButton.isHidden = true
        self.chooseSignUpButton.isHidden = true
        self.headerLabel.text = "Sign in to Beeminder"
        self.headerLabel.isHidden = false
        self.signInButton.isHidden = false
        self.signUpButton.isHidden = true
        self.resetPasswordButton.isHidden = false
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
        MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
    }
    
    @objc func handleSignedIn(_ notification : Notification) {
        MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
    }
    
    @objc func signInButtonPressed() {
        guard let email = self.emailTextField.text?.trimmingCharacters(in: .whitespaces), let password = self.passwordTextField.text, !email.isEmpty, !password.isEmpty else {
            self.present(self.missingDataOnSignIn, animated: true, completion: nil)
            return
        }
        
        MBProgressHUD.showAdded(to: self.view, animated: true)
        CurrentUserManager.sharedManager.signInWithEmail(email, password: password)
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
    
    @objc func resetPasswordTapped() {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = true;
        let safariVC = SFSafariViewController(url: self.passwordResetUrl, configuration: config);
        self.present(safariVC, animated: true, completion: nil)
    }
    
    
    var passwordResetUrl: URL {
        return URL(string: "https://www.beeminder.com/users/password/new")!
    }
    
    // MARK: - SFSafariViewControllerDelegate
    
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
}
