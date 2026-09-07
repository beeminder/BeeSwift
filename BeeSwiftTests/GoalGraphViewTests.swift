//
//  GoalGraphViewTests.swift
//  BeeSwiftTests
//

import CoreData
import SwiftyJSON
import XCTest

@testable import BeeKit
@testable import BeeSwift

@MainActor final class GoalGraphViewTests: XCTestCase {
  var container: BeeminderPersistentContainer!

  override func setUp() {
    super.setUp()
    container = BeeminderPersistentContainer.createMemoryBackedForTests()
  }

  func testDeadbeatOwnerSeesPlaceholderInsteadOfGraph() {
    let user = createTestUser(deadbeat: true)
    let goal = createTestGoal(owner: user)

    let graphView = GoalGraphView()
    graphView.goal = goal

    XCTAssertTrue(graphView.isShowingPlaceholder)
  }

  func testPayingOwnerSeesGraph() {
    let user = createTestUser(deadbeat: false)
    let goal = createTestGoal(owner: user)

    let graphView = GoalGraphView()
    graphView.goal = goal

    XCTAssertFalse(graphView.isShowingPlaceholder)
  }

  func testPlaceholderClearsOnceOwnerIsNoLongerDeadbeat() {
    let user = createTestUser(deadbeat: true)
    let goal = createTestGoal(owner: user)

    let graphView = GoalGraphView()
    graphView.goal = goal
    XCTAssertTrue(graphView.isShowingPlaceholder)

    user.deadbeat = false
    graphView.goal = goal

    XCTAssertFalse(graphView.isShowingPlaceholder)
  }

  // MARK: - Helpers

  private func createTestUser(deadbeat: Bool) -> User {
    return User(
      context: container.viewContext,
      username: "test-user",
      deadbeat: deadbeat,
      timezone: "Etc/UTC",
      updatedAt: Date(timeIntervalSince1970: 0),
      defaultAlertStart: 0,
      defaultDeadline: 0,
      defaultLeadTime: 0,
    )
  }

  /// A goal with no svg_url, so that the non-deadbeat path does not start a network fetch.
  private func createTestGoal(owner: User) -> Goal {
    let json = JSON(
      parseJSON: """
        {
            "id": "737aaa34f0118a330852e4bd",
            "title": "Goal for Testing Purposes",
            "slug": "test-goal",
            "initday": 1668963600,
            "deadline": 0,
            "leadtime": 0,
            "alertstart": 34200,
            "queued": false,
            "yaxis": "cumulative total test-goal",
            "won": false,
            "safebuf": 1,
            "use_defaults": true,
            "pledge": 0,
            "hhmmformat": false,
            "todayta": false,
            "urgencykey": "FROx;PPRx;DL4102469999;P1000000000;test-goal"
        }
        """
    )
    return Goal(context: container.viewContext, owner: owner, json: json)
  }
}
