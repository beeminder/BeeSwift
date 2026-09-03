//
//  BeeFlightView.swift
//  BeeSwift
//

import UIKit

/// An overlay that flies a bee from a home point through a figure-8 loop and then either off the
/// top-right corner or back home, trailing orange dashes. Removes itself once the flight is over,
/// so it can be mounted on the window and outlive the screen that started it.
final class BeeFlightView: UIView {
  private let beeSize: CGFloat
  private let flyingBee = UIImageView()
  private let trailContainer = UIView()

  // MARK: Flight geometry

  private struct Cubic { let p0, p1, p2, p3: CGPoint }

  private let flightStations = 120
  /// Seconds per figure-8 loop, which sets the flight speed for every phase. Set before `start`.
  var loopDuration: TimeInterval = 1.67
  private(set) var isFlying = false
  private var flightHome: CGPoint = .zero
  private var lemniscateCenter: CGPoint = .zero
  private var lemniscateHalfWidth: CGFloat = 0
  private var lemniscateHalfHeight: CGFloat = 0
  private var flightSpeed: CGFloat = 1  // points per second, shared by every phase

  // MARK: Trail state

  // Dashes are dropped along the bee's path and stay put, fading with age.
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

  /// Launches the bee from `home` (in this view's coordinates) and loops until `flyAway` or
  /// `abortHome` is called.
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
  /// is called synchronously with the exit duration so the caller can fade its screen out in step.
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

    let heading = currentRotation - .pi / 2  // bee image points up; travel angle = rotation - 90°
    let corner = CGPoint(x: bounds.width + 120, y: -160)
    let minCornerRadius: CGFloat = 70
    let exitPath = exitPathPoints(from: current, headingAngle: heading, toward: corner, minRadius: minCornerRadius)

    let bee = flyingBee

    // Scaling the duration by pace'(0) = 1 - accel makes the bee leave at exactly the loop speed.
    let accel: CGFloat = 0.5
    let pace: (CGFloat) -> CGFloat = { Self.pace($0, accel: accel) }
    let paceInverse: (CGFloat) -> CGFloat = { Self.paceInverse($0, accel: accel) }
    let durationScale = Double(1 - accel)
    let duration = Double(flightKeyframes(densePoints: exitPath).length / flightSpeed) * durationScale

    UIView.animate(withDuration: duration * 0.55, delay: duration * 0.35, options: .curveEaseIn) { bee.alpha = 0 }

    // The caller's reveal may block the main thread, which would freeze the display-link trail, so
    // the exit's dashes are pre-baked into Core Animation instead.
    stopTrail()
    bakeExitTrail(along: exitPath, duration: duration, paceInverse: paceInverse)

    runPhase(densePoints: exitPath, key: "exit", pace: pace, durationScale: durationScale) { bee.isHidden = true }
    removeSelf(after: duration + trailDashLifetime + 0.1)

    reveal(duration)
  }

  /// Glides the bee back to its launch point and calls `completion` when it lands.
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
    // Settle back to upright as it glides home.
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

  private func removeSelf(after delay: TimeInterval) {
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [self] in removeFromSuperview() }
  }

  // MARK: - Exit acceleration curve

  /// Maps a time fraction onto an arc-length fraction for the accelerating exit. Its initial slope
  /// is `1 - accel`, rising to `1 + accel` at the end.
  static func pace(_ u: CGFloat, accel: CGFloat) -> CGFloat { (1 - accel) * u + accel * u * u }

  /// The inverse of `pace`: the time fraction at which a given arc-length fraction is reached.
  /// Input is clamped to [0, 1].
  static func paceInverse(_ fraction: CGFloat, accel: CGFloat) -> CGFloat {
    let y = max(0, min(1, fraction))
    guard accel > 0.0001 else { return y }
    return (-(1 - accel) + sqrt((1 - accel) * (1 - accel) + 4 * accel * y)) / (2 * accel)
  }

  // MARK: - Flight geometry

  private func prepareFlightGeometry() {
    let width = bounds.width
    lemniscateHalfWidth = min(width * 0.22, 100)
    lemniscateHalfHeight = lemniscateHalfWidth / 1.25
    lemniscateCenter = CGPoint(x: bounds.midX, y: flightHome.y - 18)
    let loopLength = flightKeyframes(loopCubics()).length
    flightSpeed = max(1, loopLength / CGFloat(loopDuration))
  }

  private func loopCubics() -> [Cubic] {
    let c = lemniscateCenter
    let hw = lemniscateHalfWidth
    let hh = lemniscateHalfHeight
    // Traversed bottom-first so the crossing tangent points down-right, matching the entry's end.
    return [
      Cubic(p0: c, p1: CGPoint(x: c.x + hw, y: c.y + hh), p2: CGPoint(x: c.x + hw, y: c.y - hh), p3: c),
      Cubic(p0: c, p1: CGPoint(x: c.x - hw, y: c.y + hh), p2: CGPoint(x: c.x - hw, y: c.y - hh), p3: c),
    ]
  }

  private func runEntry() {
    let c = lemniscateCenter
    let hw = lemniscateHalfWidth
    let hh = lemniscateHalfHeight
    // Straight up past the figure-8, then curve down into the crossing along the loop's start tangent.
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
    runPhase(cubics: loopCubics(), key: "loop") { [weak self] in
      guard let self, self.isFlying else { return }
      self.runLoop()
    }
  }

  /// The exit path as a dense polyline: an arc of radius `minRadius`, tangent to `headingAngle` at
  /// `start`, turning to face `target`, then a straight run out past it.
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

    let arcEnd = points.last ?? start
    let runLength = hypot(target.x - arcEnd.x, target.y - arcEnd.y) + 200
    points.append(CGPoint(x: arcEnd.x + cos(aim) * runLength, y: arcEnd.y + sin(aim) * runLength))
    return points
  }

  /// Animates the bee along the given cubics at the flight speed, head leading unless
  /// `rotationsOverride` is supplied.
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

  /// Like `runPhase(cubics:…)` but along a dense polyline.
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

  /// Keyframes for a chain of cubic Béziers; see `flightKeyframes(densePoints:pace:)`.
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

  /// Resamples a polyline at arc-length stations, spaced evenly or warped by `pace` (a map of
  /// [0,1] onto [0,1]), with a head-leading rotation at each. Also returns the path's total length.
  func flightKeyframes(densePoints dense: [CGPoint], pace: (CGFloat) -> CGFloat = { $0 }) -> (
    positions: [CGPoint], rotations: [CGFloat], length: CGFloat
  ) {
    guard dense.count >= 2 else {
      let point = dense.first ?? flightHome
      return (Array(repeating: point, count: flightStations + 1), Array(repeating: 0, count: flightStations + 1), 0)
    }
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

    // The bee image points up, so rotation = travel angle + 90°.
    var rotations: [CGFloat] = []
    rotations.reserveCapacity(flightStations + 1)
    for i in 0...flightStations {
      let a = positions[max(0, i - 1)]
      let b = positions[min(flightStations, i + 1)]
      rotations.append(atan2(b.y - a.y, b.x - a.x) + .pi / 2)
    }
    // Unwrap so the bee never spins the long way round.
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

  /// Starts sampling the bee's live position each frame, dropping a dash every `trailDashSpacing`
  /// points of travel.
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

    if let last = trailPath.last {
      let step = hypot(position.x - last.point.x, position.y - last.point.y)
      // The presentation layer can report a stale position on the first frame; re-anchor on any
      // implausibly large jump rather than laying dashes across it.
      if step > max(60, flightSpeed * 0.25) {
        trailPath = [(position, last.length)]
        return
      }
      guard step > 0.01 else { return }  // skip frames where the bee hasn't moved
      trailTotalLength += step
    }
    trailPath.append((position, trailTotalLength))

    // Lay each dash once it is at least `trailGap` behind the bee, so the bee's tail never touches it.
    while trailNextStation + trailGap <= trailTotalLength {
      guard let (point, angle) = trailPoint(atLength: trailNextStation) else { break }
      dropDash(at: point, travelAngle: angle)
      trailNextStation += trailDashSpacing
    }
    pruneTrailHistory()
  }

  /// The point on the recorded flight path at arc length `target`, and the heading there.
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

  /// Discards path history the trail has already passed.
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

  /// Lays the exit's dashes up front as Core Animation fades timed to the bee's exit, continuing the
  /// dash spacing the live sampler had reached.
  private func bakeExitTrail(
    along exitPath: [CGPoint],
    duration: TimeInterval,
    paceInverse: @escaping (CGFloat) -> CGFloat,
  ) {
    guard exitPath.count >= 2, duration > 0 else { return }

    var exitLengths: [CGFloat] = [0]
    exitLengths.reserveCapacity(exitPath.count)
    for i in 1..<exitPath.count {
      exitLengths.append(
        exitLengths[i - 1] + hypot(exitPath[i].x - exitPath[i - 1].x, exitPath[i].y - exitPath[i - 1].y)
      )
    }
    guard let exitTotal = exitLengths.last, exitTotal > 0 else { return }

    // The bee's exit keyframes are warped so arcLength(u) = exitTotal · pace(u).
    let timeForArcLength: (CGFloat) -> Double = { arcLength in Double(paceInverse(arcLength / exitTotal)) * duration }

    // Append the exit to the recorded path so dash stations run straight across the seam.
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

    // Commit now: the dashes carry absolute begin times, and if the caller blocks the main thread
    // before the implicit transaction flushes, the earliest ones would be skipped.
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
  }

  /// The point on a polyline (with cumulative `lengths`) at arc length `target`, and the heading there.
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

/// Forwards display-link ticks to the flight view without the link retaining it.
private final class TrailDisplayLinkProxy {
  private weak var target: BeeFlightView?
  init(target: BeeFlightView) { self.target = target }
  @objc func tick() { target?.trailTick() }
}
