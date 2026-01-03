//
//  SpotlightIndexerTests.swift
//  BeeSwiftTests
//
//  Copyright 2024 APB. All rights reserved.
//

import AppIntents
import CoreData
import SwiftyJSON
import XCTest

@testable import BeeKit
@testable import BeeSwift

class MockSearchableIndex: SearchableIndexing {
  var indexedEntities: [[GoalEntity]] = []
  var deleteAllSearchableItemsCalled = false
  var onIndex: (() -> Void)?
  var onDeleteAll: (() -> Void)?

  func indexAppEntities<T: IndexedEntity>(_ entities: [T], priority: Int) async throws {
    if let goalEntities = entities as? [GoalEntity] { indexedEntities.append(goalEntities) }
    onIndex?()
  }

  func deleteAllSearchableItems() async throws {
    deleteAllSearchableItemsCalled = true
    onDeleteAll?()
  }
}

final class SpotlightIndexerTests: XCTestCase {
  var container: BeeminderPersistentContainer!
  var currentUserManager: CurrentUserManager!
  var mockSearchableIndex: MockSearchableIndex!

  override func setUp() {
    super.setUp()
    container = BeeminderPersistentContainer.createMemoryBackedForTests()
    currentUserManager = CurrentUserManager(requestManager: RequestManager(), container: container)
    mockSearchableIndex = MockSearchableIndex()
  }

  override func tearDown() {
    container = nil
    currentUserManager = nil
    mockSearchableIndex = nil
    super.tearDown()
  }

  func testReindexAllGoalsWithNoUser() async {
    let indexer = SpotlightIndexer(
      container: container,
      currentUserManager: currentUserManager,
      searchableIndex: mockSearchableIndex
    )

    await indexer.reindexAllGoals()

    XCTAssertTrue(mockSearchableIndex.indexedEntities.isEmpty, "Should not index when no user")
  }

  func testReindexAllGoalsWithUserAndGoals() async throws {
    let user = createTestUser()
    _ = createTestGoal(owner: user, slug: "goal-one", title: "First Goal")
    _ = createTestGoal(owner: user, slug: "goal-two", title: "Second Goal")
    try container.viewContext.save()

    let indexer = SpotlightIndexer(
      container: container,
      currentUserManager: currentUserManager,
      searchableIndex: mockSearchableIndex
    )

    await indexer.reindexAllGoals()

    XCTAssertEqual(mockSearchableIndex.indexedEntities.count, 1, "Should have indexed once")
    let indexed = mockSearchableIndex.indexedEntities.first!
    XCTAssertEqual(indexed.count, 2, "Should have indexed 2 goals")

    let slugs = Set(indexed.map { $0.slug })
    XCTAssertEqual(slugs, ["goal-one", "goal-two"])
  }

  func testReindexOnGoalsUpdatedNotification() async throws {
    let user = createTestUser()
    _ = createTestGoal(owner: user, slug: "initial-goal", title: "Initial Goal")
    try container.viewContext.save()

    let indexed = expectation(description: "Goals indexed")
    mockSearchableIndex.onIndex = { indexed.fulfill() }

    let indexer = SpotlightIndexer(
      container: container,
      currentUserManager: currentUserManager,
      searchableIndex: mockSearchableIndex
    )
    indexer.startListening()

    // Post the notification on main thread (AppDelegate observers require main thread)
    await MainActor.run {
      NotificationCenter.default.post(name: GoalManager.NotificationName.goalsUpdated, object: nil)
    }

    await fulfillment(of: [indexed], timeout: 1.0)

    XCTAssertEqual(mockSearchableIndex.indexedEntities.count, 1, "Should have indexed once")
    XCTAssertEqual(mockSearchableIndex.indexedEntities.first?.first?.slug, "initial-goal")
  }

  func testClearIndexOnSignedOutNotification() async throws {
    let cleared = expectation(description: "Index cleared")
    mockSearchableIndex.onDeleteAll = { cleared.fulfill() }

    let indexer = SpotlightIndexer(
      container: container,
      currentUserManager: currentUserManager,
      searchableIndex: mockSearchableIndex
    )
    indexer.startListening()

    // Post the notification on main thread (AppDelegate observers require main thread)
    await MainActor.run {
      NotificationCenter.default.post(name: CurrentUserManager.NotificationName.signedOut, object: nil)
    }

    await fulfillment(of: [cleared], timeout: 1.0)

    XCTAssertTrue(mockSearchableIndex.deleteAllSearchableItemsCalled, "Should clear index on sign out")
  }

  // MARK: - Helpers

  func createTestUser() -> User {
    return User(
      context: container.viewContext,
      username: "test-user",
      deadbeat: false,
      timezone: "Etc/UTC",
      updatedAt: Date(timeIntervalSince1970: 0),
      defaultAlertStart: 0,
      defaultDeadline: 0,
      defaultLeadTime: 0
    )
  }

  func createTestGoal(owner: User, slug: String, title: String) -> Goal {
    let json = JSON(
      parseJSON: """
        {
            "id": "\(slug)-id",
            "title": "\(title)",
            "slug": "\(slug)",
            "initday": 1668963600,
            "deadline": 0,
            "leadtime": 0,
            "alertstart": 34200,
            "queued": false,
            "yaxis": "cumulative total",
            "won": false,
            "safebuf": 1,
            "use_defaults": true,
            "pledge": 0,
            "hhmmformat": false,
            "todayta": false,
            "urgencykey": "FROx"
        }
        """
    )
    return Goal(context: container.viewContext, owner: owner, json: json)
  }
}
