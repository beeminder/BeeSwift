//
//  SignInViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/26/15.
//  Copyright 2015 APB. All rights reserved.
//

import BeeKit
import Foundation
import MBProgressHUD
import SafariServices
import UIKit

class SignInViewController: UIViewController, UITextFieldDelegate {
  private let scrollView = UIScrollView()
  var headerLabel = BSLabel()
  var emailTextField = BSTextField()
  var passwordTextField = BSTextField()
  // The bee is separate from the wordmark so it can be swapped for the flying bee seamlessly.
  private let beeImageView = UIImageView()
  private let wordmarkImageView = UIImageView()
  var signInButton = BSButton()
  var divider = UIView()
  private let logoContainer = UIView()

  private let currentUserManager: CurrentUserManager
  private let goalManager: GoalManager
  private weak var coordinator: MainCoordinator?

  // Mounted on the window while a sign-in is in progress.
  private var flightView: BeeFlightView?

  // The bee's take-off while it waits for the keyboard to finish hiding.
  private var pendingLaunch: DispatchWorkItem?
  private var keyboardDidHideObserver: NSObjectProtocol?

  // True from the start of an attempt until the form is restored or the screen is handed off.
  private var signInInProgress = false

  private let beeSize: CGFloat = 80
  private let wordmarkSize = CGSize(width: 195, height: 22.5)
  // Spacing and vertical offset of the text relative to the bee, as in the original logo.
  private let wordmarkGap: CGFloat = 13
  private let wordmarkCenterYOffset: CGFloat = -6

  init(currentUserManager: CurrentUserManager, goalManager: GoalManager, coordinator: MainCoordinator?) {
    self.currentUserManager = currentUserManager
    self.goalManager = goalManager
    self.coordinator = coordinator
    super.init(nibName: nil, bundle: nil)
  }
  required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
  deinit {
    // Block-based observers are not removed automatically.
    if let observer = keyboardDidHideObserver { NotificationCenter.default.removeObserver(observer) }
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    self.view.addSubview(scrollView)
    scrollView.snp.makeConstraints { (make) -> Void in make.edges.equalTo(self.view) }
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(self.handleFailedSignIn(_:)),
      name: CurrentUserManager.NotificationName.failedSignIn,
      object: nil,
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(self.handleSignedIn(_:)),
      name: CurrentUserManager.NotificationName.signedIn,
      object: nil,
    )
    self.view.backgroundColor = UIColor.systemBackground

    scrollView.addSubview(self.logoContainer)
    self.logoContainer.snp.makeConstraints { (make) in
      make.centerX.equalTo(scrollView)
      make.centerY.equalToSuperview().multipliedBy(0.55)
      make.width.equalTo(beeSize + wordmarkGap + wordmarkSize.width)
      make.height.equalTo(beeSize)
    }

    self.beeImageView.image = UIImage(named: "Infinibee")
    self.beeImageView.contentMode = .scaleAspectFit
    self.logoContainer.addSubview(self.beeImageView)
    self.beeImageView.snp.makeConstraints { (make) in
      make.leading.equalTo(self.logoContainer)
      make.centerY.equalTo(self.logoContainer)
      make.width.height.equalTo(beeSize)
    }

    self.wordmarkImageView.image = UIImage(named: "website_wordmark")
    self.wordmarkImageView.contentMode = .scaleAspectFit
    self.logoContainer.addSubview(self.wordmarkImageView)
    self.wordmarkImageView.snp.makeConstraints { (make) in
      make.leading.equalTo(self.beeImageView.snp.trailing).offset(wordmarkGap)
      make.centerY.equalTo(self.beeImageView).offset(wordmarkCenterYOffset)
      make.size.equalTo(wordmarkSize)
    }

    scrollView.addSubview(self.headerLabel)
    self.headerLabel.textAlignment = NSTextAlignment.center
    self.headerLabel.snp.makeConstraints { (make) -> Void in
      make.top.equalTo(self.logoContainer.snp.bottom).offset(8)
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
    self.signInButton.addTarget(
      self,
      action: #selector(SignInViewController.signInButtonPressed),
      for: UIControl.Event.touchUpInside,
    )
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

  // MARK: - Alerts

  var missingDataOnSignIn: UIAlertController {
    let lackOfCredentials = UIAlertController(
      title: "Incomplete Account Details",
      message: "Username and Password are required",
      preferredStyle: .alert,
    )
    lackOfCredentials.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
    return lackOfCredentials
  }
  private var couldNotSignInAlertController: UIAlertController {
    let controller = UIAlertController(
      title: "Could not sign in",
      message: "Invalid credentials",
      preferredStyle: .alert,
    )
    controller.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
    return controller
  }

  // MARK: - Sign in

  @objc func signInButtonPressed() {
    Task { @MainActor in
      guard !self.signInInProgress else { return }
      guard let email = self.emailTextField.text?.trimmingCharacters(in: .whitespaces),
        let password = self.passwordTextField.text, !email.isEmpty, !password.isEmpty
      else {
        self.present(self.missingDataOnSignIn, animated: true, completion: nil)
        return
      }

      self.signInInProgress = true
      self.showSignInProgress()
      await self.currentUserManager.signInWithEmail(email, password: password)
    }
  }

  @objc func handleFailedSignIn(_ notification: Notification) {
    self.cancelPendingLaunch()
    if let flightView = self.flightView, flightView.isFlying {
      flightView.abortHome { [weak self] in self?.restoreFormAndShowFailure() }
    } else {
      self.restoreFormAndShowFailure()
    }
  }

  @objc func handleSignedIn(_ notification: Notification) {
    // Fetch goals before revealing the gallery so it doesn't appear empty.
    Task { @MainActor in
      try? await self.goalManager.refreshGoals()
      if let flightView = self.flightView, flightView.isFlying {
        flightView.flyAway { [weak self] duration in self?.coordinator?.completeSignIn(revealDuration: duration) }
      } else {
        self.cancelPendingLaunch()
        MBProgressHUD.hide(for: self.view, animated: true)
        self.coordinator?.completeSignIn()
      }
    }
  }

  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    if textField.isEqual(self.emailTextField) {
      self.passwordTextField.becomeFirstResponder()
    } else if textField.isEqual(self.passwordTextField) {
      self.signInButtonPressed()
    }
    return true
  }

  // MARK: - Sign-in flight

  /// Shows that a sign-in attempt is under way: the bee flight, or a progress HUD under Reduce Motion.
  private func showSignInProgress() {
    self.signInButton.isUserInteractionEnabled = false
    let keyboardWasShowing = self.emailTextField.isFirstResponder || self.passwordTextField.isFirstResponder
    self.view.endEditing(true)

    guard !UIAccessibility.isReduceMotionEnabled else {
      MBProgressHUD.showAdded(to: self.view, animated: true)
      return
    }

    // Dim the form straight away for feedback, even if the bee has to wait for the keyboard.
    UIView.animate(withDuration: 0.3) {
      self.headerLabel.alpha = 0.15
      self.emailTextField.alpha = 0.15
      self.passwordTextField.alpha = 0.15
      self.signInButton.alpha = 0.15
    }
    if keyboardWasShowing { self.launchBeeWhenSettled() } else { self.launchBee() }
  }

  /// Launches the bee once the keyboard has hidden and the form has scrolled back to its resting
  /// layout, so the bee's home matches where the logo will be. Times out in case no notification
  /// arrives (e.g. a hardware keyboard).
  private func launchBeeWhenSettled() {
    let launch = DispatchWorkItem { [weak self] in self?.launchBee() }
    self.pendingLaunch = launch
    self.keyboardDidHideObserver = NotificationCenter.default.addObserver(
      forName: UIResponder.keyboardDidHideNotification,
      object: nil,
      queue: .main,
    ) { [weak self] _ in self?.pendingLaunch?.perform() }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: launch)
  }

  private func cancelPendingLaunch() {
    self.pendingLaunch?.cancel()
    self.pendingLaunch = nil
    if let observer = self.keyboardDidHideObserver {
      NotificationCenter.default.removeObserver(observer)
      self.keyboardDidHideObserver = nil
    }
  }

  /// Replaces the logo bee with a window-mounted `BeeFlightView` launching from the same spot.
  private func launchBee() {
    self.cancelPendingLaunch()
    guard self.signInInProgress, self.flightView == nil else { return }
    self.view.layoutIfNeeded()

    let host: UIView = self.view.window ?? self.view
    let flight = BeeFlightView(beeImage: UIImage(named: "Infinibee"), beeSize: self.beeSize)
    flight.frame = host.bounds
    host.addSubview(flight)
    self.flightView = flight

    let beeCentre = CGPoint(x: self.beeImageView.bounds.midX, y: self.beeImageView.bounds.midY)
    let home = flight.convert(beeCentre, from: self.beeImageView)
    self.beeImageView.isHidden = true

    UIView.animate(withDuration: 0.3) { self.wordmarkImageView.alpha = 0 }

    flight.start(home: home)
  }

  private func restoreFormAndShowFailure() {
    self.signInInProgress = false
    self.flightView = nil  // it removes itself from the window
    MBProgressHUD.hide(for: self.view, animated: true)
    self.beeImageView.isHidden = false
    self.signInButton.isUserInteractionEnabled = true
    UIView.animate(withDuration: 0.3) {
      self.wordmarkImageView.alpha = 1
      self.headerLabel.alpha = 1
      self.emailTextField.alpha = 1
      self.passwordTextField.alpha = 1
      self.signInButton.alpha = 1
    }
    self.present(self.couldNotSignInAlertController, animated: true, completion: nil)
  }
}
