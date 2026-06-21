//
//  SignInViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/26/15.
//  Copyright 2015 APB. All rights reserved.
//

import BeeKit
import Foundation
import SafariServices
import UIKit

class SignInViewController: UIViewController, UITextFieldDelegate {
  private let scrollView = UIScrollView()
  var headerLabel = BSLabel()
  var emailTextField = BSTextField()
  var passwordTextField = BSTextField()
  // The bee is split out from the wordmark so it can be the *same* view that animates,
  // avoiding any discontinuity between the resting logo and the flying bee.
  var beeImageView = UIImageView()
  var wordmarkImageView = UIImageView()
  var signInButton = BSButton()
  var divider = UIView()
  private let logoContainer = UIView()

  private let currentUserManager: CurrentUserManager
  private let goalManager: GoalManager
  private weak var coordinator: MainCoordinator?

  // The bee flight + trail animation, mounted on the window while a sign-in is in progress.
  private var flightView: BeeFlightView?

  // True from when a sign-in attempt starts until the form is restored (failure) or the screen is
  // handed off (success). The bee's home glide on failure clears the flight view's `isFlying` ~1.6s
  // before the form is back, so this flag — not the flight state — is what gates re-entry.
  private var signInInProgress = false

  // The bee in the logo occupies the left ~28% of the wordmark image; slice it off so we
  // show only the "BEEMINDER" text. (Measured from website_logo_mid: bee 0-158px, text 184px+.)
  private let wordmarkCropFraction: CGFloat = 170.0 / 574.0
  private let beeSize: CGFloat = 80
  private let logoGap: CGFloat = 6
  private let wordmarkWidth: CGFloat = 202
  private let logoHeight: CGFloat = 80

  init(currentUserManager: CurrentUserManager, goalManager: GoalManager, coordinator: MainCoordinator?) {
    self.currentUserManager = currentUserManager
    self.goalManager = goalManager
    self.coordinator = coordinator
    super.init(nibName: nil, bundle: nil)
  }
  required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

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

    // Logo: a standalone bee + the sliced "BEEMINDER" wordmark, laid out to read as one logo.
    scrollView.addSubview(self.logoContainer)
    self.logoContainer.snp.makeConstraints { (make) in
      make.centerX.equalTo(scrollView)
      make.centerY.equalToSuperview().multipliedBy(0.55)
      make.width.equalTo(beeSize + logoGap + wordmarkWidth)
      make.height.equalTo(logoHeight)
    }

    self.beeImageView.image = UIImage(named: "Infinibee")
    self.beeImageView.contentMode = .scaleAspectFit
    self.logoContainer.addSubview(self.beeImageView)
    self.beeImageView.snp.makeConstraints { (make) in
      make.leading.equalTo(self.logoContainer)
      make.centerY.equalTo(self.logoContainer)
      make.width.height.equalTo(beeSize)
    }

    self.wordmarkImageView.contentMode = .scaleAspectFit
    self.logoContainer.addSubview(self.wordmarkImageView)
    self.wordmarkImageView.snp.makeConstraints { (make) in
      make.leading.equalTo(self.beeImageView.snp.trailing).offset(logoGap)
      make.centerY.equalTo(self.logoContainer)
      make.width.equalTo(wordmarkWidth)
      make.height.equalTo(logoHeight)
    }
    self.updateWordmark()

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

    // Re-slice the wordmark when switching between light and dark mode.
    registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _: UITraitCollection) in
      self.updateWordmark()
    }
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

  // MARK: - Wordmark slicing

  private func updateWordmark() { self.wordmarkImageView.image = self.slicedWordmark() }

  /// The full Beeminder logo with the bee sliced off, leaving only the "BEEMINDER" text.
  private func slicedWordmark() -> UIImage? {
    guard let asset = UIImage(named: "website_logo_mid") else { return nil }
    let resolved = asset.imageAsset?.image(with: traitCollection) ?? asset
    guard let cg = resolved.cgImage else { return resolved }
    let cropX = Int((CGFloat(cg.width) * wordmarkCropFraction).rounded())
    let rect = CGRect(x: cropX, y: 0, width: cg.width - cropX, height: cg.height)
    guard let cropped = cg.cropping(to: rect) else { return resolved }
    return UIImage(cgImage: cropped, scale: resolved.scale, orientation: resolved.imageOrientation)
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
      // Ignore repeat taps and Return-key presses while an attempt (including its failure glide) is
      // still in progress, so we never spawn a second flight or desync the restored form.
      guard !signInInProgress else { return }
      guard let email = self.emailTextField.text?.trimmingCharacters(in: .whitespaces),
        let password = self.passwordTextField.text, !email.isEmpty, !password.isEmpty
      else {
        self.present(self.missingDataOnSignIn, animated: true, completion: nil)
        return
      }

      signInInProgress = true
      self.startSignInAnimation()
      await currentUserManager.signInWithEmail(email, password: password)
    }
  }

  @objc func handleFailedSignIn(_ notification: Notification) {
    if let flightView, flightView.isFlying {
      // Fly the bee home, then restore the form and report the error.
      flightView.abortHome { [weak self] in self?.restoreFormAndShowFailure() }
    } else {
      self.present(couldNotSignInAlertController, animated: true, completion: nil)
    }
  }

  @objc func handleSignedIn(_ notification: Notification) {
    guard let flightView, flightView.isFlying else {
      // No animation in flight (shouldn't happen during an interactive sign-in) — just hand off.
      coordinator?.completeSignIn()
      return
    }
    // Keep the bee looping until the gallery's goals have actually been fetched, so we never
    // reveal an empty "no goals yet" gallery. Then fly off and reveal the populated gallery.
    Task { @MainActor in
      try? await goalManager.refreshGoals()
      flightView.flyAway { [weak self] duration in self?.coordinator?.completeSignIn(revealDuration: duration) }
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

  /// Hands the bee off to a window-mounted `BeeFlightView` (so it can keep flying as this screen is
  /// torn down) and dims the form behind it. The bee launches from exactly where the resting logo
  /// bee sits, which is then hidden so the swap is invisible.
  private func startSignInAnimation() {
    guard flightView?.isFlying != true else { return }
    self.view.endEditing(true)
    self.view.layoutIfNeeded()  // make sure the logo is laid out before we read its position

    let host: UIView = view.window ?? view
    let flight = BeeFlightView(beeImage: UIImage(named: "Infinibee"), beeSize: beeSize)
    flight.frame = host.bounds
    host.addSubview(flight)
    flightView = flight

    let home = flight.convert(CGPoint(x: beeImageView.bounds.midX, y: beeImageView.bounds.midY), from: beeImageView)
    beeImageView.isHidden = true
    signInButton.isUserInteractionEnabled = false

    // Fade the wordmark out entirely and the rest of the form back to the background.
    UIView.animate(withDuration: 0.3) {
      self.wordmarkImageView.alpha = 0
      self.headerLabel.alpha = 0.15
      self.emailTextField.alpha = 0.15
      self.passwordTextField.alpha = 0.15
      self.signInButton.alpha = 0.15
    }

    flight.start(home: home)
  }

  /// Restores the form after a failed sign-in. The bee has already glided home (and the flight view
  /// tears itself down once its trail finishes fading), so we just bring the logo and form back.
  private func restoreFormAndShowFailure() {
    signInInProgress = false
    beeImageView.isHidden = false
    signInButton.isUserInteractionEnabled = true
    UIView.animate(withDuration: 0.3) {
      self.wordmarkImageView.alpha = 1
      self.headerLabel.alpha = 1
      self.emailTextField.alpha = 1
      self.passwordTextField.alpha = 1
      self.signInButton.alpha = 1
    }
    self.present(couldNotSignInAlertController, animated: true, completion: nil)
  }
}
