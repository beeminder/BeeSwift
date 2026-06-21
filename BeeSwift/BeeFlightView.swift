//
//  BeeFlightView.swift
//  BeeSwift
//
//  A self-contained, window-mounted overlay that flies a bee from a home point through a figure-8
//  loop and then off the top-right corner, trailing a short "train" of orange dashes.
//

import UIKit

/// Owns the flying bee, its trail, and the display link, and removes itself once the animation
/// finishes. Because it is mounted on the window (not on the sign-in screen) and tears itself down,
/// it keeps flying after the view controller that started it is dismissed mid-exit — the "outlives
/// its owner" requirement holds by construction, not by lifecycle juggling.
final class BeeFlightView: UIView {
  private let beeSize: CGFloat
  private let flyingBee = UIImageView()
  private let trailContainer = UIView()

  // MARK: Flight geometry

  private struct Cubic { let p0, p1, p2, p3: CGPoint }

  private let flightStations = 120
  private(set) var isFlying = false
  private var flightHome: CGPoint = .zero
  private var lemniscateCenter: CGPoint = .zero
  private var lemniscateHalfWidth: CGFloat = 0
  private var lemniscateHalfHeight: CGFloat = 0
  private var flightSpeed: CGFloat = 1  // points per second, shared by every phase

  // MARK: Trail state

  // Orange "train" trailing the bee: dashes are dropped at the bee's passing positions and then
  // stay put, fading out with age, so the most recent few are visible behind it.
  private var trailLink: CADisplayLink?
  private var trailPath: [(point: CGPoint, length: CGFloat)] = []  // bee-centre flight path history
  private var trailTotalLength: CGFloat = 0
  private var trailNextStation: CGFloat = 0
  private let trailDashCount = 5
  private let trailDashSpacing: CGFloat = 22
  private let trailGap: CGFloat = 38  // how far behind the bee the trail starts, so its tail clears it

  init(beeImage: UIImage?, beeSize: CGFloat) {
    self.beeSize = beeSize
    super.init(frame: .zero)
    isUserInteractionEnabled = false

    trailContainer.isUserInteractionEnabled = false
    addSubview(trailContainer)  // the trail sits behind the bee

    flyingBee.image = beeImage
    flyingBee.contentMode = .scaleAspectFit
    flyingBee.isHidden = true
    addSubview(flyingBee)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func layoutSubviews() {
    super.layoutSubviews()
    trailContainer.frame = bounds  // share our coordinate space so dashes can be placed absolutely
  }

  deinit { trailLink?.invalidate() }

  // MARK: - Public API

  /// Launches the bee from `home` (in this view's coordinates) and loops the figure-8 indefinitely
  /// until `flyAway` or `abortHome` is called.
  func start(home: CGPoint) {
    guard !isFlying else { return }
    layoutIfNeeded()
    flightHome = home
    prepareFlightGeometry()

    flyingBee.bounds = CGRect(x: 0, y: 0, width: beeSize, height: beeSize)
    flyingBee.layer.position = home
    flyingBee.layer.transform = CATransform3DIdentity
    flyingBee.alpha = 1
    flyingBee.isHidden = false

    isFlying = true
    startTrail()
    runEntry()
  }

  /// Sends the bee off the top-right corner from wherever it is, accelerating as it goes. `reveal`
  /// is called with the flight duration so the caller can cross-fade its screen away in step. The
  /// view removes itself once the bee has left and the last trail dash has faded.
  func flyAway(reveal: (TimeInterval) -> Void) {
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
    let corner = CGPoint(x: bounds.width + 120, y: -160)
    let minCornerRadius: CGFloat = 70
    let exitPath = exitPathPoints(from: current, headingAngle: heading, toward: corner, minRadius: minCornerRadius)

    let bee = flyingBee

    // Accelerating exit: front-load the path sampling so the bee leaves at the loop's speed (no
    // jolt at the hand-off) and speeds up as it flies off. `pace` maps even time steps onto
    // increasingly long arc-length steps; setting durationScale = pace'(0) makes the initial speed
    // exactly the loop speed, ramping to (1 + accel) / pace'(0) times that by the corner.
    let accel: CGFloat = 0.5
    let pace: (CGFloat) -> CGFloat = { Self.pace($0, accel: accel) }
    let paceInverse: (CGFloat) -> CGFloat = { Self.paceInverse($0, accel: accel) }
    let durationScale = Double(1 - accel)
    let duration = Double(flightKeyframes(densePoints: exitPath).length / flightSpeed) * durationScale

    // Commit the bee's exit to the render server FIRST, so it keeps flying smoothly at the loop's
    // speed even while the caller's reveal briefly blocks the main thread (building the gallery).
    UIView.animate(withDuration: duration * 0.55, delay: duration * 0.35, options: .curveEaseIn) { bee.alpha = 0 }

    // The display-link trail would freeze during the exit (the reveal blocks the main thread), so
    // stop it and pre-bake the exit's dashes into Core Animation alongside the bee instead.
    stopTrail()
    bakeExitTrail(along: exitPath, duration: duration, paceInverse: paceInverse)

    runPhase(densePoints: exitPath, key: "exit", pace: pace, durationScale: durationScale) { bee.isHidden = true }
    // Remove ourselves once the bee has flown off and the last dash has faded.
    removeSelf(after: duration + trailDashLifetime + 0.1)

    reveal(duration)
  }

  /// Glides the bee back to its launch point and calls `completion` when it lands (the caller can
  /// restore whatever it hid). The view removes itself once the trail has faded.
  func abortHome(completion: @escaping () -> Void) {
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
      guard let self else { return }
      self.stopTrail()
      self.flyingBee.isHidden = true
      self.flyingBee.layer.removeAllAnimations()
      self.flyingBee.layer.transform = CATransform3DIdentity
      self.removeSelf(after: self.trailDashLifetime + 0.1)
      completion()
    }
  }

  /// Removes the view (and everything it hosts) after `delay`, keeping it alive until then so its
  /// in-flight dashes finish fading.
  private func removeSelf(after delay: TimeInterval) {
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [self] in removeFromSuperview() }
  }

  // MARK: - Exit acceleration curve

  /// Maps an even time fraction onto an arc-length fraction for the accelerating exit. Because
  /// `pace'(0) = 1 - accel`, scaling the exit's duration by `1 - accel` makes the bee leave the loop
  /// at exactly the loop speed (no jolt at the hand-off) and ramp up to `(1 + accel)/(1 - accel)×`
  /// that by the corner. `pace(0) = 0` and `pace(1) = 1`, so the path is covered exactly once.
  static func pace(_ u: CGFloat, accel: CGFloat) -> CGFloat { (1 - accel) * u + accel * u * u }

  /// The analytic inverse of `pace` (lives alongside it so the two can't drift apart): given a
  /// fraction of arc length, the fraction of time at which the bee reaches it. Used to time each
  /// exit trail dash to the moment the bee is `trailGap` ahead of it. Input is clamped to [0, 1].
  static func paceInverse(_ fraction: CGFloat, accel: CGFloat) -> CGFloat {
    let y = max(0, min(1, fraction))
    guard accel > 0.0001 else { return y }
    return (-(1 - accel) + sqrt((1 - accel) * (1 - accel) + 4 * accel * y)) / (2 * accel)
  }

  // MARK: - Flight geometry

  private func prepareFlightGeometry() {
    let width = bounds.width
    lemniscateHalfWidth = min(width * 0.22, 100)
    lemniscateHalfHeight = lemniscateHalfWidth / 1.25  // matches BeeLemniscateView's aspect ratio
    lemniscateCenter = CGPoint(x: bounds.midX, y: flightHome.y - 18)
    // Baseline perceptual speed: pick the speed from one loop and reuse it for entry and looping.
    // The exit ramps up from this speed (see flyAway).
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
    // Loop indefinitely until sign-in finishes; flyAway() interrupts us from wherever we are.
    runPhase(cubics: loopCubics(), key: "loop") { [weak self] in
      guard let self, self.isFlying else { return }
      self.runLoop()
    }
  }

  /// Builds the exit path as a dense polyline (in the same coordinate space as the inputs): a
  /// circular-arc turn of radius `minRadius`, tangent to `headingAngle` at `start`, that rotates to
  /// face `target`, followed by a straight run out past it. Bounding the arc radius keeps the
  /// lemniscate→exit transition from ever becoming a sharp corner.
  func exitPathPoints(from start: CGPoint, headingAngle: CGFloat, toward target: CGPoint, minRadius: CGFloat)
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
  func flightKeyframes(densePoints dense: [CGPoint], pace: (CGFloat) -> CGFloat = { $0 }) -> (
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

  // MARK: - Bee trail

  /// Starts the orange dash "train". A display link samples the bee's live (presentation) position
  /// each frame and drops a stationary dash every `trailDashSpacing` points of travel; each dash
  /// then fades out over the time the bee takes to lay down `trailDashCount` dashes, so roughly that
  /// many are visible at once — brightest nearest the bee. The dashes never move: the trail follows
  /// the bee purely by new dashes appearing ahead and old ones fading behind.
  private func startTrail() {
    stopTrail()
    trailPath.removeAll()
    trailTotalLength = 0
    trailNextStation = 0
    let proxy = TrailDisplayLinkProxy(target: self)
    let link = CADisplayLink(target: proxy, selector: #selector(TrailDisplayLinkProxy.tick))
    link.add(to: .main, forMode: .common)
    trailLink = link
  }

  private func stopTrail() {
    trailLink?.invalidate()
    trailLink = nil
  }

  fileprivate func trailTick() {
    guard let presentation = flyingBee.layer.presentation(), !flyingBee.isHidden else { return }
    let position = presentation.position

    // Record the bee centre's actual flight path, tracking cumulative arc length along it.
    if let last = trailPath.last {
      let step = hypot(position.x - last.point.x, position.y - last.point.y)
      // The presentation layer can report a stale position (typically the origin) on the very first
      // frame, before the flight animation is committed. Re-anchor on any implausibly large jump so
      // we never lay a line of dashes from the corner to the bee's starting point.
      if step > max(60, flightSpeed * 0.25) {
        trailPath = [(position, last.length)]
        return
      }
      guard step > 0.01 else { return }  // skip frames where the bee hasn't moved
      trailTotalLength += step
    }
    trailPath.append((position, trailTotalLength))

    // Lay down dash stations spaced along that path, but only once each is at least `trailGap`
    // behind the bee. Placing them on the real path (not an offset of it) keeps the trail tracing
    // the smooth route the bee flew; the gap means the bee's swinging tail never reaches the trail.
    while trailNextStation + trailGap <= trailTotalLength {
      // Stop (rather than skip the station) if the path isn't long enough to interpolate yet, e.g.
      // just after a re-anchor; the station gets laid on a later frame once history has caught up.
      guard let (point, angle) = trailPoint(atLength: trailNextStation) else { break }
      dropDash(at: point, travelAngle: angle)
      trailNextStation += trailDashSpacing
    }
    pruneTrailHistory()
  }

  /// Interpolates the recorded flight path to find the point at arc length `target` and the path's
  /// travel direction there, so a dash laid at it reads as a streak along the route.
  private func trailPoint(atLength target: CGFloat) -> (CGPoint, CGFloat)? {
    guard trailPath.count >= 2 else { return nil }
    for i in 1..<trailPath.count where trailPath[i].length >= target {
      let a = trailPath[i - 1]
      let b = trailPath[i]
      let segment = b.length - a.length
      let f = segment > 0 ? (target - a.length) / segment : 0
      let point = CGPoint(x: a.point.x + (b.point.x - a.point.x) * f, y: a.point.y + (b.point.y - a.point.y) * f)
      return (point, atan2(b.point.y - a.point.y, b.point.x - a.point.x))
    }
    return nil
  }

  /// Discards path history the trail has already passed, keeping the buffer small.
  private func pruneTrailHistory() {
    let keepFrom = trailNextStation - trailDashSpacing
    if let idx = trailPath.firstIndex(where: { $0.length >= keepFrom }), idx > 1 { trailPath.removeFirst(idx - 1) }
  }

  private func makeDashView(at point: CGPoint, travelAngle: CGFloat) -> UIView {
    let dash = UIView()
    dash.backgroundColor = .systemOrange
    dash.bounds = CGRect(x: 0, y: 0, width: 14, height: 4)
    dash.layer.cornerRadius = 2
    dash.center = point
    dash.transform = CGAffineTransform(rotationAngle: travelAngle)
    return dash
  }

  private var trailDashLifetime: TimeInterval {
    max(0.25, Double(trailDashCount) * Double(trailDashSpacing) / Double(flightSpeed))
  }

  private func dropDash(at point: CGPoint, travelAngle: CGFloat) {
    let dash = makeDashView(at: point, travelAngle: travelAngle)
    trailContainer.addSubview(dash)
    UIView.animate(withDuration: trailDashLifetime, delay: 0, options: [.curveLinear]) {
      dash.alpha = 0
    } completion: { _ in
      dash.removeFromSuperview()
    }
  }

  /// Pre-bakes the trail for the exit flight straight into Core Animation, continuing the same dash
  /// grid the live sampler laid during the loop. The caller's reveal briefly blocks the main thread
  /// (building the gallery), which freezes the display-link-driven trail; baking the exit dashes —
  /// timed to the bee's already-committed exit — keeps the trail flowing across that stall.
  private func bakeExitTrail(
    along exitPath: [CGPoint],
    duration: TimeInterval,
    paceInverse: @escaping (CGFloat) -> CGFloat,
  ) {
    guard exitPath.count >= 2, duration > 0 else { return }

    // Arc lengths along the exit path, and its total, for the pace→time mapping below.
    var exitLengths: [CGFloat] = [0]
    exitLengths.reserveCapacity(exitPath.count)
    for i in 1..<exitPath.count {
      exitLengths.append(
        exitLengths[i - 1] + hypot(exitPath[i].x - exitPath[i - 1].x, exitPath[i].y - exitPath[i - 1].y)
      )
    }
    guard let exitTotal = exitLengths.last, exitTotal > 0 else { return }

    // The bee's keyframes are warped so arcLength(u) = exitTotal · pace(u); invert pace to find the
    // time the bee reaches a given arc length, i.e. when the dash `trailGap` behind it should appear.
    let timeForArcLength: (CGFloat) -> Double = { arcLength in Double(paceInverse(arcLength / exitTotal)) * duration }

    // Build one continuous path — the recorded loop tail the bee just flew, then the exit arc and run
    // off-screen — sharing a single arc-length scale. Walking dash stations along this combined path
    // makes the loop→exit transition just another stretch of path: the ordinary interpolation covers
    // the seam, with no special-casing of where the two meet.
    let handoff = exitPath[0]
    let handoffGap = trailPath.last.map { hypot(handoff.x - $0.point.x, handoff.y - $0.point.y) } ?? 0
    let exitStartLength = trailTotalLength + handoffGap  // global arc length at the hand-off
    var points = trailPath.map { $0.point }
    var lengths = trailPath.map { $0.length }
    for i in 0..<exitPath.count {
      points.append(exitPath[i])
      lengths.append(exitStartLength + exitLengths[i])
    }

    let start = CACurrentMediaTime()
    let lifetime = trailDashLifetime

    // Commit the dashes explicitly, here and now. They carry future `beginTime`s relative to `start`,
    // and the caller blocks the main thread (the reveal) immediately after baking — so if these were
    // left in the implicit transaction they wouldn't reach the render server until that block ended,
    // by which point the earliest dashes' begin times have already passed. They'd be skipped, leaving
    // a gap in the trail just as the bee peels away. Flushing now ships them with the bee.
    CATransaction.begin()
    while trailNextStation - exitStartLength <= exitTotal - trailGap {
      if let (point, angle) = pointOnPath(points, lengths, atLength: trailNextStation) {
        let appearAt = start + timeForArcLength(trailNextStation - exitStartLength + trailGap)
        bakeDash(at: point, travelAngle: angle, beginAt: appearAt, lifetime: lifetime)
      }
      trailNextStation += trailDashSpacing
    }
    CATransaction.commit()
  }

  private func bakeDash(at point: CGPoint, travelAngle: CGFloat, beginAt: CFTimeInterval, lifetime: TimeInterval) {
    let dash = makeDashView(at: point, travelAngle: travelAngle)
    dash.alpha = 0  // model value: invisible until the animation begins, then again after it ends
    trailContainer.addSubview(dash)

    let fade = CAKeyframeAnimation(keyPath: "opacity")
    fade.values = [1.0, 0.0]
    fade.duration = lifetime
    fade.beginTime = beginAt
    dash.layer.add(fade, forKey: "trailFade")
    // No per-dash removal needed: the baked dashes are torn down wholesale with this view once the
    // exit finishes (see flyAway), which is when the last of them has finished fading.
  }

  /// Interpolates a polyline (with precomputed cumulative `lengths`) at arc length `target`,
  /// returning the point and the path's heading there.
  private func pointOnPath(_ path: [CGPoint], _ lengths: [CGFloat], atLength target: CGFloat) -> (CGPoint, CGFloat)? {
    guard path.count >= 2 else { return nil }
    for i in 1..<path.count where lengths[i] >= target {
      let segment = lengths[i] - lengths[i - 1]
      let f = segment > 0 ? (target - lengths[i - 1]) / segment : 0
      let point = CGPoint(
        x: path[i - 1].x + (path[i].x - path[i - 1].x) * f,
        y: path[i - 1].y + (path[i].y - path[i - 1].y) * f,
      )
      return (point, atan2(path[i].y - path[i - 1].y, path[i].x - path[i - 1].x))
    }
    let a = path[path.count - 2]
    let b = path[path.count - 1]
    return (b, atan2(b.y - a.y, b.x - a.x))
  }
}

/// Forwards display-link ticks to the flight view without the link retaining it. CADisplayLink holds
/// a strong reference to its target, so targeting the view directly would keep it alive until the
/// link is invalidated; the weak hop here avoids depending on that.
private final class TrailDisplayLinkProxy {
  private weak var target: BeeFlightView?
  init(target: BeeFlightView) { self.target = target }
  @objc func tick() { target?.trailTick() }
}
