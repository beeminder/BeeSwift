//
//  BeeFlightViewTests.swift
//  BeeSwiftTests
//
//  Tests for the pure geometry/timing math behind the sign-in bee flight, plus end-to-end smoke
//  tests that drive a real BeeFlightView through its phases and confirm it tears itself down.
//

import UIKit
import XCTest

@testable import BeeSwift

@MainActor final class BeeFlightViewTests: XCTestCase {

  // MARK: - Exit acceleration curve (pace / paceInverse)

  func testPaceHitsEndpoints() {
    for accel in [CGFloat(0), 0.25, 0.5, 0.9] {
      XCTAssertEqual(BeeFlightView.pace(0, accel: accel), 0, accuracy: 1e-9)
      XCTAssertEqual(BeeFlightView.pace(1, accel: accel), 1, accuracy: 1e-9)
    }
  }

  func testPaceInverseRoundTripsToIdentity() {
    let accel: CGFloat = 0.5
    for i in 0...20 {
      let u = CGFloat(i) / 20
      let roundTrip = BeeFlightView.paceInverse(BeeFlightView.pace(u, accel: accel), accel: accel)
      XCTAssertEqual(roundTrip, u, accuracy: 1e-6, "paceInverse∘pace should be identity at u=\(u)")
    }
  }

  func testPaceInverseClampsOutOfRangeInput() {
    let accel: CGFloat = 0.5
    XCTAssertEqual(BeeFlightView.paceInverse(-0.5, accel: accel), 0, accuracy: 1e-9)
    XCTAssertEqual(BeeFlightView.paceInverse(1.5, accel: accel), 1, accuracy: 1e-9)
  }

  /// The smooth loop→exit hand-off depends on the bee leaving the loop at exactly the loop speed,
  /// i.e. the exit's initial speed (∝ pace'(0)) equals the loop speed. The exit scales its duration
  /// by `1 - accel`, which only matches if `pace'(0) == 1 - accel`. Verify the slope numerically.
  func testPaceLeavesAtLoopSpeed() {
    let accel: CGFloat = 0.5
    let h: CGFloat = 1e-5
    let slopeAtZero = (BeeFlightView.pace(h, accel: accel) - BeeFlightView.pace(0, accel: accel)) / h
    XCTAssertEqual(slopeAtZero, 1 - accel, accuracy: 1e-3)
  }

  /// The exit should accelerate: equal time steps cover progressively more arc length.
  func testPaceAccelerates() {
    let accel: CGFloat = 0.5
    var previousStep: CGFloat = -1
    var lastValue: CGFloat = 0
    for i in 1...10 {
      let value = BeeFlightView.pace(CGFloat(i) / 10, accel: accel)
      let step = value - lastValue
      XCTAssertGreaterThan(step, previousStep, "arc-length steps should grow (accelerate)")
      previousStep = step
      lastValue = value
    }
  }

  // MARK: - Arc-length resampling (flightKeyframes)

  func testResamplingIsEvenlySpacedAndPreservesLength() {
    let view = makeView()
    // A straight but unevenly-sampled polyline from (0,0) to (300,0).
    let dense = [0, 5, 7, 100, 250, 300].map { CGPoint(x: CGFloat($0), y: 0) }
    let result = view.flightKeyframes(densePoints: dense)

    XCTAssertEqual(result.length, 300, accuracy: 1e-6)
    XCTAssertGreaterThan(result.positions.count, 2)
    XCTAssertEqual(result.positions.first!.x, 0, accuracy: 1e-6)
    XCTAssertEqual(result.positions.last!.x, 300, accuracy: 1e-6)

    // With the identity pace, stations must be equally spaced in arc length.
    let firstStep = result.positions[1].x - result.positions[0].x
    for i in 1..<result.positions.count {
      let step = result.positions[i].x - result.positions[i - 1].x
      XCTAssertEqual(step, firstStep, accuracy: 1e-3, "uneven spacing at station \(i)")
    }
  }

  func testResamplingRotationsAreHeadLeadingAndContinuous() {
    let view = makeView()
    // A smooth quarter-circle turn of radius 100, from (100,0) round to (0,100).
    let n = 200
    let dense = (0...n).map { i -> CGPoint in
      let a = (CGFloat.pi / 2) * CGFloat(i) / CGFloat(n)
      return CGPoint(x: 100 * cos(a), y: 100 * sin(a))
    }
    let result = view.flightKeyframes(densePoints: dense)

    // No adjacent rotation should jump by more than ~pi — the unwrapping must keep the turn smooth.
    for i in 1..<result.rotations.count {
      let delta = abs(result.rotations[i] - result.rotations[i - 1])
      XCTAssertLessThan(delta, .pi, "rotation jump too large at station \(i)")
    }
    // A quarter turn rotates the heading (and so the head-leading rotation) by ~90°.
    let totalTurn = abs(result.rotations.last! - result.rotations.first!)
    XCTAssertEqual(totalTurn, .pi / 2, accuracy: 0.2)
  }

  func testPaceWarpFrontLoadsStations() {
    let view = makeView()
    let dense = [CGPoint(x: 0, y: 0), CGPoint(x: 300, y: 0)]
    let warped = view.flightKeyframes(densePoints: dense, pace: { BeeFlightView.pace($0, accel: 0.9) })
    let even = view.flightKeyframes(densePoints: dense)

    // pace is convex (pace(u) < u for u in (0,1)), so an early station sits nearer the start than
    // the evenly-spaced one.
    let idx = warped.positions.count / 4
    XCTAssertLessThan(warped.positions[idx].x, even.positions[idx].x)
  }

  // MARK: - Exit path geometry (exitPathPoints)

  func testExitPathStartsTangentAndTurnsAtBoundedRadius() {
    let view = makeView()
    let start = CGPoint(x: 100, y: 200)
    let heading = CGFloat.pi  // travelling left
    let target = CGPoint(x: 500, y: -100)  // up and to the right — a large turn
    let radius: CGFloat = 70
    let path = view.exitPathPoints(from: start, headingAngle: heading, toward: target, minRadius: radius)

    XCTAssertGreaterThan(path.count, 3)

    // Starts exactly at `start`.
    XCTAssertEqual(path[0].x, start.x, accuracy: 1e-6)
    XCTAssertEqual(path[0].y, start.y, accuracy: 1e-6)

    // First segment is tangent to the heading: the hand-off is never a sharp corner.
    let firstDir = atan2(path[1].y - path[0].y, path[1].x - path[0].x)
    XCTAssertEqual(angleDifference(firstDir, heading), 0, accuracy: 0.05)

    // The arc bends at the requested radius. Its centre is one radius perpendicular to the heading;
    // an arc point sits exactly one radius from whichever side it actually curved toward.
    let centerLeft = CGPoint(
      x: start.x + radius * cos(heading + .pi / 2),
      y: start.y + radius * sin(heading + .pi / 2),
    )
    let centerRight = CGPoint(
      x: start.x + radius * cos(heading - .pi / 2),
      y: start.y + radius * sin(heading - .pi / 2),
    )
    let arcPoint = path[path.count / 3]
    let offLeft = abs(hypot(arcPoint.x - centerLeft.x, arcPoint.y - centerLeft.y) - radius)
    let offRight = abs(hypot(arcPoint.x - centerRight.x, arcPoint.y - centerRight.y) - radius)
    XCTAssertEqual(min(offLeft, offRight), 0, accuracy: 0.5)

    // Runs out past the target so the bee leaves the screen.
    let endFromStart = hypot(path.last!.x - start.x, path.last!.y - start.y)
    let targetFromStart = hypot(target.x - start.x, target.y - start.y)
    XCTAssertGreaterThan(endFromStart, targetFromStart)
  }

  func testExitPathRunsOffInTargetDirection() {
    let view = makeView()
    let start = CGPoint(x: 0, y: 0)
    let target = CGPoint(x: 400, y: -200)
    let path = view.exitPathPoints(from: start, headingAngle: .pi / 2, toward: target, minRadius: 70)

    // The arc finishes with the bee already facing `aim` (start → target), and the straight run-off
    // continues in that direction — so the final segment points along start → target.
    let aim = atan2(target.y - start.y, target.x - start.x)
    let n = path.count
    let finalDir = atan2(path[n - 1].y - path[n - 2].y, path[n - 1].x - path[n - 2].x)
    XCTAssertEqual(angleDifference(finalDir, aim), 0, accuracy: 0.05)
  }

  // MARK: - End-to-end smoke tests

  /// Drive a real flight all the way through the accelerating exit and confirm the view runs the
  /// entry/loop/exit (including the live and pre-baked trail paths) without crashing and removes
  /// itself from the window when done.
  func testFlyAwaySmokeRunsToCompletionAndRemovesItself() {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    let view = BeeFlightView(beeImage: nil, beeSize: 80)
    view.frame = window.bounds
    window.addSubview(view)
    window.isHidden = false

    view.start(home: CGPoint(x: 195, y: 300))
    XCTAssertTrue(view.isFlying)

    spinRunLoop(0.3)  // let the entry + loop run a few frames (exercises the live trail sampler)

    var revealedDuration: TimeInterval?
    view.flyAway { revealedDuration = $0 }
    XCTAssertNotNil(revealedDuration, "reveal should be invoked with the exit duration")
    XCTAssertFalse(view.isFlying)

    waitForRemoval(of: view, timeout: 6)
    XCTAssertNil(view.superview, "the flight view should remove itself once the exit has finished")
  }

  /// Drive the failure path: the bee glides home, the completion fires, and the view tears down.
  func testAbortHomeSmokeRunsToCompletionAndRemovesItself() {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    let view = BeeFlightView(beeImage: nil, beeSize: 80)
    view.frame = window.bounds
    window.addSubview(view)
    window.isHidden = false

    view.start(home: CGPoint(x: 195, y: 300))
    spinRunLoop(0.3)

    let landed = expectation(description: "bee glided home")
    view.abortHome { landed.fulfill() }
    XCTAssertFalse(view.isFlying)
    wait(for: [landed], timeout: 5)

    waitForRemoval(of: view, timeout: 3)
    XCTAssertNil(view.superview)
  }

  /// Starting a second flight while one is in progress must be ignored, not crash or double-start.
  func testStartingWhileFlyingIsIgnored() {
    let view = BeeFlightView(beeImage: nil, beeSize: 80)
    view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    view.start(home: CGPoint(x: 195, y: 300))
    XCTAssertTrue(view.isFlying)
    view.start(home: CGPoint(x: 10, y: 10))  // no-op
    XCTAssertTrue(view.isFlying)

    view.flyAway { _ in }  // stop the display link cleanly
  }

  // MARK: - Helpers

  private func makeView() -> BeeFlightView { BeeFlightView(beeImage: nil, beeSize: 80) }

  private func spinRunLoop(_ seconds: TimeInterval) { RunLoop.current.run(until: Date().addingTimeInterval(seconds)) }

  private func waitForRemoval(of view: UIView, timeout: TimeInterval) {
    let deadline = Date().addingTimeInterval(timeout)
    while view.superview != nil && Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.05)) }
  }

  /// Smallest unsigned angle between two headings, in [0, π].
  private func angleDifference(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
    var d = a - b
    while d > .pi { d -= 2 * .pi }
    while d < -(.pi) { d += 2 * .pi }
    return abs(d)
  }
}
