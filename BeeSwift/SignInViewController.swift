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
  private let flyingBee = UIImageView()
  var signInButton = BSButton()
  var divider = UIView()
  private let logoContainer = UIView()

  private let currentUserManager: CurrentUserManager
  private let goalManager: GoalManager
  private weak var coordinator: MainCoordinator?

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

    // A free-floating copy of the bee used purely for the flight animation. It is shown at the
    // exact frame of the resting bee (same image), so swapping between them is invisible.
    self.flyingBee.image = UIImage(named: "Infinibee")
    self.flyingBee.contentMode = .scaleAspectFit
    self.flyingBee.translatesAutoresizingMaskIntoConstraints = true
    self.flyingBee.isHidden = true
    scrollView.addSubview(self.flyingBee)

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
      guard let email = self.emailTextField.text?.trimmingCharacters(in: .whitespaces),
        let password = self.passwordTextField.text, !email.isEmpty, !password.isEmpty
      else {
        self.present(self.missingDataOnSignIn, animated: true, completion: nil)
        return
      }

      self.startSignInAnimation()
      await currentUserManager.signInWithEmail(email, password: password)
    }
  }

  @objc func handleFailedSignIn(_ notification: Notification) {
    if isFlying {
      // Stop the bee gracefully, fly it home, then restore the form and report the error.
      abortFlightAndReturnHome()
    } else {
      self.present(couldNotSignInAlertController, animated: true, completion: nil)
    }
  }

  @objc func handleSignedIn(_ notification: Notification) {
    guard isFlying else {
      // No animation in flight (shouldn't happen during an interactive sign-in) — just hand off.
      coordinator?.completeSignIn()
      return
    }
    // Keep the bee looping until the gallery's goals have actually been fetched, so we never
    // reveal an empty "no goals yet" gallery. Then fly off and reveal the populated gallery.
    Task { @MainActor in
      try? await goalManager.refreshGoals()
      beginExit()
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

  // MARK: - Bee flight animation

  private struct Cubic { let p0, p1, p2, p3: CGPoint }

  private let flightStations = 120
  private var isFlying = false
  private var flightHome: CGPoint = .zero
  private var lemniscateCenter: CGPoint = .zero
  private var lemniscateHalfWidth: CGFloat = 0
  private var lemniscateHalfHeight: CGFloat = 0
  private var flightSpeed: CGFloat = 1  // points per second, shared by every phase

  private func startSignInAnimation() {
    guard !isFlying else { return }
    self.view.endEditing(true)
    prepareFlightGeometry()

    // Show the flying bee exactly over the resting bee, then hide the resting one.
    let beeRect = scrollView.convert(beeImageView.bounds, from: beeImageView)
    flyingBee.frame = beeRect
    flyingBee.layer.position = flightHome
    flyingBee.layer.transform = CATransform3DIdentity
    flyingBee.alpha = 1
    flyingBee.isHidden = false
    scrollView.bringSubviewToFront(flyingBee)  // fly over the (dimmed) form, not behind it
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

    isFlying = true
    runEntry()
  }

  private func prepareFlightGeometry() {
    scrollView.layoutIfNeeded()
    let beeRect = scrollView.convert(beeImageView.bounds, from: beeImageView)
    flightHome = CGPoint(x: beeRect.midX, y: beeRect.midY)
    let width = scrollView.bounds.width
    lemniscateHalfWidth = min(width * 0.22, 100)
    lemniscateHalfHeight = lemniscateHalfWidth / 1.25  // matches BeeLemniscateView's aspect ratio
    lemniscateCenter = CGPoint(x: scrollView.bounds.midX, y: flightHome.y - 18)
    // Baseline perceptual speed: pick the speed from one loop and reuse it for entry and looping.
    // The exit ramps up from this speed (see beginExit).
    let loopDuration = 1.67  // seconds per figure-8 loop; lower is faster
    let loopLength = flightKeyframes(loopCubics()).length
    flightSpeed = max(1, loopLength / loopDuration)
  }

  private func loopCubics() -> [Cubic] {
    let c = lemniscateCenter
    let hw = lemniscateHalfWidth
    let hh = lemniscateHalfHeight
    // Bottom-first traversal so the crossing tangent points down-right, letting the entry
    // descend into the figure-8. Same shape as BeeLemniscateView, traced the other way.
    return [
      Cubic(p0: c, p1: CGPoint(x: c.x + hw, y: c.y + hh), p2: CGPoint(x: c.x + hw, y: c.y - hh), p3: c),
      Cubic(p0: c, p1: CGPoint(x: c.x - hw, y: c.y + hh), p2: CGPoint(x: c.x - hw, y: c.y - hh), p3: c),
    ]
  }

  private func runEntry() {
    let c = lemniscateCenter
    let hw = lemniscateHalfWidth
    let hh = lemniscateHalfHeight
    // Launch straight up (control point directly above the start) to above the figure-8,
    // then curve down into the crossing heading down-right to match the loop's start tangent.
    let entry = Cubic(
      p0: flightHome,
      p1: CGPoint(x: flightHome.x, y: c.y - hh - 30),
      p2: CGPoint(x: c.x - 0.6 * hw, y: c.y - 0.6 * hh),
      p3: c,
    )
    runPhase(cubics: [entry], key: "entry") { [weak self] in
      guard let self, self.isFlying else { return }
      self.runLoop()
    }
  }

  private func runLoop() {
    guard isFlying else { return }
    // Loop indefinitely until sign-in finishes; beginExit() interrupts us from wherever we are.
    runPhase(cubics: loopCubics(), key: "loop") { [weak self] in
      guard let self, self.isFlying else { return }
      self.runLoop()
    }
  }

  /// Breaks the bee out of its current flight (entry or loop) and sends it off the top-right
  /// corner from wherever it is, lifting it onto the window so it keeps flying over the gallery
  /// while the sign-in screen cross-dissolves away beneath it.
  private func beginExit() {
    guard isFlying else { return }
    isFlying = false

    // Freeze the bee at its current in-flight position and heading.
    let current = flyingBee.layer.presentation()?.position ?? flyingBee.layer.position
    let currentTransform = flyingBee.layer.presentation()?.transform ?? flyingBee.layer.transform
    let currentRotation = atan2(currentTransform.m12, currentTransform.m11)
    flyingBee.layer.removeAllAnimations()
    flyingBee.layer.position = current
    flyingBee.layer.transform = CATransform3DMakeRotation(currentRotation, 0, 0, 1)

    // Turn from the current heading toward the top-right corner along an arc of at least
    // `minCornerRadius`, so the lemniscate→exit hand-off is never a sharp corner, then run off.
    let heading = currentRotation - .pi / 2  // bee image points up; travel angle = rotation - 90°
    let width = scrollView.bounds.width
    let corner = CGPoint(x: width + 120, y: -160)
    let minCornerRadius: CGFloat = 70
    let exitPoints = exitPathPoints(from: current, headingAngle: heading, toward: corner, minRadius: minCornerRadius)

    // Lift the bee onto the window (if available) so it outlives the sign-in screen.
    let reparented = reparentFlyingBeeToWindow(position: current, rotation: currentRotation)
    let exitPath = reparented ? pointsInWindow(exitPoints) : exitPoints

    let bee = flyingBee  // hold the bee independently of self, which is torn down on dismissal.

    // Accelerating exit: front-load the path sampling so the bee leaves at the loop's speed (no
    // jolt at the hand-off) and speeds up as it flies off. `pace` maps even time steps onto
    // increasingly long arc-length steps; setting durationScale = pace'(0) makes the initial speed
    // exactly the loop speed, ramping to (1 + accel) / pace'(0) times that by the corner.
    let accel: CGFloat = 0.5
    let pace: (CGFloat) -> CGFloat = { (1 - accel) * $0 + accel * $0 * $0 }
    let durationScale = Double(1 - accel)
    let duration = Double(flightKeyframes(densePoints: exitPath).length / flightSpeed) * durationScale

    // Commit the bee's exit to the render server FIRST, so it keeps flying smoothly at the loop's
    // speed even while completeSignIn builds the gallery (which briefly blocks the main thread).
    // Doing it the other way round freezes the bee at the hand-off point for that beat.
    UIView.animate(withDuration: duration * 0.55, delay: duration * 0.35, options: .curveEaseIn) { bee.alpha = 0 }
    runPhase(densePoints: exitPath, key: "exit", pace: pace, durationScale: durationScale) {
      bee.isHidden = true
      bee.removeFromSuperview()
    }

    // Fade the sign-in screen out over the whole exit flight so it has fully vanished, revealing
    // the gallery, just as the bee reaches the corner.
    coordinator?.completeSignIn(revealDuration: duration)
  }

  /// Builds the exit path as a dense polyline (in the same coordinate space as the inputs): a
  /// circular-arc turn of radius `minRadius`, tangent to `headingAngle` at `start`, that rotates to
  /// face `target`, followed by a straight run out past it. Bounding the arc radius keeps the
  /// lemniscate→exit transition from ever becoming a sharp corner.
  private func exitPathPoints(from start: CGPoint, headingAngle: CGFloat, toward target: CGPoint, minRadius: CGFloat)
    -> [CGPoint]
  {
    let aim = atan2(target.y - start.y, target.x - start.x)
    var turn = aim - headingAngle
    while turn > .pi { turn -= 2 * .pi }
    while turn < -(.pi) { turn += 2 * .pi }

    var points: [CGPoint] = [start]

    if abs(turn) > 0.001 && minRadius > 0 {
      // Centre is perpendicular to the heading, on the inside of the turn.
      let centerAngle = headingAngle + (turn >= 0 ? 1 : -1) * .pi / 2
      let center = CGPoint(x: start.x + minRadius * cos(centerAngle), y: start.y + minRadius * sin(centerAngle))
      let startAngle = atan2(start.y - center.y, start.x - center.x)
      let arcSteps = max(1, Int(abs(turn) / (.pi / 60)))  // ~3° per step
      for i in 1...arcSteps {
        let a = startAngle + turn * CGFloat(i) / CGFloat(arcSteps)
        points.append(CGPoint(x: center.x + minRadius * cos(a), y: center.y + minRadius * sin(a)))
      }
    }

    // From the arc's end the bee faces `aim`; run straight out past the target to leave the screen.
    let arcEnd = points.last ?? start
    let runLength = hypot(target.x - arcEnd.x, target.y - arcEnd.y) + 200
    points.append(CGPoint(x: arcEnd.x + cos(aim) * runLength, y: arcEnd.y + sin(aim) * runLength))
    return points
  }

  /// Reparents the flying bee from the scroll view onto the key window, preserving its on-screen
  /// position and rotation. Returns false (leaving the bee in place) if there is no window.
  private func reparentFlyingBeeToWindow(position: CGPoint, rotation: CGFloat) -> Bool {
    guard let window = scrollView.window else { return false }
    window.addSubview(flyingBee)
    flyingBee.layer.position = scrollView.convert(position, to: window)
    flyingBee.layer.transform = CATransform3DMakeRotation(rotation, 0, 0, 1)
    return true
  }

  /// Converts points expressed in scroll-view coordinates into the window's coordinate space.
  private func pointsInWindow(_ points: [CGPoint]) -> [CGPoint] {
    guard let window = scrollView.window else { return points }
    return points.map { scrollView.convert($0, to: window) }
  }

  private func abortFlightAndReturnHome() {
    guard isFlying else { return }
    isFlying = false

    let current = flyingBee.layer.presentation()?.position ?? flyingBee.layer.position
    let currentTransform = flyingBee.layer.presentation()?.transform ?? flyingBee.layer.transform
    let currentRotation = atan2(currentTransform.m12, currentTransform.m11)

    flyingBee.layer.removeAllAnimations()
    flyingBee.layer.position = current
    flyingBee.layer.transform = CATransform3DMakeRotation(currentRotation, 0, 0, 1)

    let dx = flightHome.x - current.x
    let dy = flightHome.y - current.y
    let home = Cubic(
      p0: current,
      p1: CGPoint(x: current.x + dx * 0.33, y: current.y + dy * 0.33),
      p2: CGPoint(x: current.x + dx * 0.66, y: current.y + dy * 0.66),
      p3: flightHome,
    )
    // Settle gradually back to upright as it glides home.
    let rotations = (0...flightStations).map { i in currentRotation * (1 - CGFloat(i) / CGFloat(flightStations)) }
    runPhase(cubics: [home], key: "return", rotationsOverride: rotations) { [weak self] in
      self?.restoreFormAndShowFailure()
    }
  }

  private func restoreFormAndShowFailure() {
    flyingBee.isHidden = true
    flyingBee.layer.removeAllAnimations()
    flyingBee.layer.transform = CATransform3DIdentity
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

  /// Animates the flying bee along the given cubic path(s) at the shared flight speed, with the
  /// bee's head leading the direction of travel (unless `rotationsOverride` is supplied).
  private func runPhase(
    cubics: [Cubic],
    key: String,
    rotationsOverride: [CGFloat]? = nil,
    pace: (CGFloat) -> CGFloat = { $0 },
    durationScale: Double = 1.0,
    completion: @escaping () -> Void,
  ) {
    let keyframes = flightKeyframes(cubics, pace: pace)
    animateFlight(
      positions: keyframes.positions,
      rotations: rotationsOverride ?? keyframes.rotations,
      length: keyframes.length,
      durationScale: durationScale,
      key: key,
      completion: completion,
    )
  }

  /// Like `runPhase(cubics:…)` but drives the bee along a dense polyline (used for the arc exit).
  private func runPhase(
    densePoints: [CGPoint],
    key: String,
    pace: (CGFloat) -> CGFloat = { $0 },
    durationScale: Double = 1.0,
    completion: @escaping () -> Void,
  ) {
    let keyframes = flightKeyframes(densePoints: densePoints, pace: pace)
    animateFlight(
      positions: keyframes.positions,
      rotations: keyframes.rotations,
      length: keyframes.length,
      durationScale: durationScale,
      key: key,
      completion: completion,
    )
  }

  private func animateFlight(
    positions: [CGPoint],
    rotations: [CGFloat],
    length: CGFloat,
    durationScale: Double,
    key: String,
    completion: @escaping () -> Void,
  ) {
    let duration = max(0.12, Double(length / flightSpeed) * durationScale)

    // Set the model state to the path's end so removing the animation leaves no jump.
    flyingBee.layer.position = positions.last ?? flightHome
    flyingBee.layer.transform = CATransform3DMakeRotation(rotations.last ?? 0, 0, 0, 1)

    let positionAnim = CAKeyframeAnimation(keyPath: "position")
    positionAnim.values = positions.map { NSValue(cgPoint: $0) }
    positionAnim.calculationMode = .linear

    let rotationAnim = CAKeyframeAnimation(keyPath: "transform.rotation.z")
    rotationAnim.values = rotations.map { NSNumber(value: Double($0)) }
    rotationAnim.calculationMode = .linear

    let group = CAAnimationGroup()
    group.animations = [positionAnim, rotationAnim]
    group.duration = duration
    group.timingFunction = CAMediaTimingFunction(name: .linear)

    CATransaction.begin()
    CATransaction.setCompletionBlock(completion)
    flyingBee.layer.add(group, forKey: key)
    CATransaction.commit()
  }

  /// Resamples cubic Bézier segments along arc length and computes a head-leading rotation at each
  /// station. With the default identity `pace` the stations are equally spaced (constant speed);
  /// a non-linear `pace` (mapping [0,1] → [0,1]) front- or back-loads them to vary speed over the
  /// path. Returns the keyframe positions, rotations and total length.
  private func flightKeyframes(_ cubics: [Cubic], pace: (CGFloat) -> CGFloat = { $0 }) -> (
    positions: [CGPoint], rotations: [CGFloat], length: CGFloat
  ) {
    var dense: [CGPoint] = []
    let perCubic = 80
    for (i, c) in cubics.enumerated() {
      let startStep = (i == 0) ? 0 : 1
      for s in startStep...perCubic { dense.append(point(on: c, CGFloat(s) / CGFloat(perCubic))) }
    }
    return flightKeyframes(densePoints: dense, pace: pace)
  }

  /// Resamples an already-dense polyline at equal (or `pace`-warped) arc-length stations and
  /// computes a head-leading rotation at each. Used for paths that aren't Bézier cubics, such as
  /// the arc-based exit.
  private func flightKeyframes(densePoints dense: [CGPoint], pace: (CGFloat) -> CGFloat = { $0 }) -> (
    positions: [CGPoint], rotations: [CGFloat], length: CGFloat
  ) {
    var cumulative: [CGFloat] = [0]
    cumulative.reserveCapacity(dense.count)
    for i in 1..<dense.count {
      cumulative.append(cumulative[i - 1] + hypot(dense[i].x - dense[i - 1].x, dense[i].y - dense[i - 1].y))
    }
    let total = cumulative.last ?? 0

    var positions: [CGPoint] = []
    positions.reserveCapacity(flightStations + 1)
    var j = 0
    for s in 0...flightStations {
      let target = total * pace(CGFloat(s) / CGFloat(flightStations))
      while j < dense.count - 1 && cumulative[j + 1] < target { j += 1 }
      if j >= dense.count - 1 {
        positions.append(dense.last ?? flightHome)
      } else {
        let segment = cumulative[j + 1] - cumulative[j]
        let f = segment > 0 ? (target - cumulative[j]) / segment : 0
        let a = dense[j]
        let b = dense[j + 1]
        positions.append(CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f))
      }
    }

    // Head-leading: the bee image points up, so rotation = travel angle + 90 degrees.
    var rotations: [CGFloat] = []
    rotations.reserveCapacity(flightStations + 1)
    for i in 0...flightStations {
      let a = positions[max(0, i - 1)]
      let b = positions[min(flightStations, i + 1)]
      rotations.append(atan2(b.y - a.y, b.x - a.x) + .pi / 2)
    }
    // Unwrap so the bee never spins the long way round between stations.
    for i in 1...flightStations {
      var d = rotations[i] - rotations[i - 1]
      while d > .pi {
        rotations[i] -= 2 * .pi
        d = rotations[i] - rotations[i - 1]
      }
      while d < -(.pi) {
        rotations[i] += 2 * .pi
        d = rotations[i] - rotations[i - 1]
      }
    }

    return (positions, rotations, total)
  }

  private func point(on c: Cubic, _ t: CGFloat) -> CGPoint {
    let u = 1 - t
    let a = u * u * u
    let b = 3 * u * u * t
    let d = 3 * u * t * t
    let e = t * t * t
    return CGPoint(
      x: a * c.p0.x + b * c.p1.x + d * c.p2.x + e * c.p3.x,
      y: a * c.p0.y + b * c.p1.y + d * c.p2.y + e * c.p3.y,
    )
  }
}
