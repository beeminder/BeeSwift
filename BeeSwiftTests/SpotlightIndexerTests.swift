//
//  SpotlightIndexerTests.swift
//  BeeSwiftTests
//
//  Copyright 2024 APB. All rights reserved.
//

import AppIntents
import CoreData
import OSLog
import SwiftyJSON
import XCTest

@testable import BeeKit
@testable import BeeSwift

// MARK: - Diagnostic Logging
// This logging helps diagnose flaky SIGSEGV crashes. If a test crashes, check logs for:
// - "POTENTIAL DATA RACE": overlapping mock method calls from different threads
// - Task lifecycle: cancel called before task work completed
// - Notification timing: notification posted before listener registered
private let testLogger = Logger(subsystem: "com.beeminder.BeeSwiftTests", category: "SpotlightIndexerTests")

final class MockSearchableIndex: SearchableIndexing, @unchecked Sendable {
  var indexedEntities: [[GoalEntity]] = []
  var deleteAllSearchableItemsCalled = false
  var deletedIdentifiers: [String] = []
  var onIndex: (() -> Void)?
  var onDeleteAll: (() -> Void)?
  var onDeleteIdentifiers: (() -> Void)?

  // Track concurrent access to detect data races
  private var activeMethodCalls = 0
  private let accessQueue = DispatchQueue(label: "MockSearchableIndex.access")

  private func trackEntry(_ method: String) {
    accessQueue.sync {
      activeMethodCalls += 1
      if activeMethodCalls > 1 {
        testLogger.error(
          "POTENTIAL DATA RACE: \(method) entered while another method active (count=\(self.activeMethodCalls))"
        )
      }
      testLogger.debug("\(method): enter (thread=\(Thread.current), active=\(self.activeMethodCalls))")
    }
  }

  private func trackExit(_ method: String) {
    accessQueue.sync {
      testLogger.debug("\(method): exit (thread=\(Thread.current), active=\(self.activeMethodCalls))")
      activeMethodCalls -= 1
    }
  }

  func indexAppEntities<T: IndexedEntity>(_ entities: [T], priority: Int) async throws {
    trackEntry("indexAppEntities")
    if let goalEntities = entities as? [GoalEntity] { indexedEntities.append(goalEntities) }
    onIndex?()
    trackExit("indexAppEntities")
  }

  func deleteAllSearchableItems() async throws {
    trackEntry("deleteAllSearchableItems")
    deleteAllSearchableItemsCalled = true
    onDeleteAll?()
    trackExit("deleteAllSearchableItems")
  }

  func deleteSearchableItems(withIdentifiers identifiers: [String]) async throws {
    trackEntry("deleteSearchableItems")
    deletedIdentifiers.append(contentsOf: identifiers)
    onDeleteIdentifiers?()
    trackExit("deleteSearchableItems")
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
    testLogger.debug("tearDown: starting - setting references to nil")
    container = nil
    currentUserManager = nil
    mockSearchableIndex = nil
    testLogger.debug("tearDown: references cleared - calling super.tearDown()")
    super.tearDown()
    testLogger.debug("tearDown: complete")
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

  func testReindexOnObjectsDidChangeNotification() async throws {
    let user = createTestUser()
    _ = createTestGoal(owner: user, slug: "initial-goal", title: "Initial Goal")
    try container.viewContext.save()

    let indexed = expectation(description: "Goals indexed")
    mockSearchableIndex.onIndex = {
      testLogger.debug("onIndex callback fired - expectation will be fulfilled")
      indexed.fulfill()
    }

    let indexer = SpotlightIndexer(
      container: container,
      currentUserManager: currentUserManager,
      searchableIndex: mockSearchableIndex
    )
    testLogger.debug("Creating listener task")
    let listenerTask = Task {
      testLogger.debug("Listener task started - calling listenForNotifications()")
      await indexer.listenForNotifications()
      testLogger.debug("Listener task: listenForNotifications() returned")
    }

    // Post the notification on main thread
    testLogger.debug("About to post NSManagedObjectContextObjectsDidChange notification")
    await MainActor.run {
      NotificationCenter.default.post(name: .NSManagedObjectContextObjectsDidChange, object: container.viewContext)
    }
    testLogger.debug("Notification posted")

    testLogger.debug("Awaiting expectation fulfillment")
    await fulfillment(of: [indexed], timeout: 1.0)
    testLogger.debug("Expectation fulfilled - cancelling task")
    listenerTask.cancel()
    testLogger.debug("Task cancelled - proceeding to assertions (task may still be running!)")

    XCTAssertEqual(mockSearchableIndex.indexedEntities.count, 1, "Should have indexed once")
    XCTAssertEqual(mockSearchableIndex.indexedEntities.first?.first?.slug, "initial-goal")
    testLogger.debug("Assertions complete")
  }

  func testClearIndexOnSignedOutNotification() async throws {
    let cleared = expectation(description: "Index cleared")
    mockSearchableIndex.onDeleteAll = {
      testLogger.debug("onDeleteAll callback fired - expectation will be fulfilled")
      cleared.fulfill()
    }

    let indexer = SpotlightIndexer(
      container: container,
      currentUserManager: currentUserManager,
      searchableIndex: mockSearchableIndex
    )
    testLogger.debug("Creating listener task")
    let listenerTask = Task {
      testLogger.debug("Listener task started - calling listenForNotifications()")
      await indexer.listenForNotifications()
      testLogger.debug("Listener task: listenForNotifications() returned")
    }

    // Post the notification on main thread
    testLogger.debug("About to post signedOut notification")
    await MainActor.run {
      NotificationCenter.default.post(name: CurrentUserManager.NotificationName.signedOut, object: nil)
    }
    testLogger.debug("Notification posted")

    testLogger.debug("Awaiting expectation fulfillment")
    await fulfillment(of: [cleared], timeout: 1.0)
    testLogger.debug("Expectation fulfilled - cancelling task")
    listenerTask.cancel()
    testLogger.debug("Task cancelled - proceeding to assertions (task may still be running!)")

    XCTAssertTrue(mockSearchableIndex.deleteAllSearchableItemsCalled, "Should clear index on sign out")
    testLogger.debug("Assertions complete")
  }

  // MARK: - Incremental Indexing Tests

  func testFirstIndexDeletesAllThenIndexes() async throws {
    let user = createTestUser()
    _ = createTestGoal(owner: user, slug: "goal-one", title: "First Goal")
    try container.viewContext.save()

    let indexer = SpotlightIndexer(
      container: container,
      currentUserManager: currentUserManager,
      searchableIndex: mockSearchableIndex
    )

    await indexer.reindexAllGoals()

    XCTAssertTrue(mockSearchableIndex.deleteAllSearchableItemsCalled, "First run should delete all")
    XCTAssertEqual(mockSearchableIndex.indexedEntities.count, 1)
  }

  func testSecondIndexIsIncremental() async throws {
    let user = createTestUser()
    _ = createTestGoal(owner: user, slug: "goal-one", title: "First Goal")
    try container.viewContext.save()

    let indexer = SpotlightIndexer(
      container: container,
      currentUserManager: currentUserManager,
      searchableIndex: mockSearchableIndex
    )

    // First indexing
    await indexer.reindexAllGoals()
    XCTAssertTrue(mockSearchableIndex.deleteAllSearchableItemsCalled)

    // Reset tracking
    mockSearchableIndex.deleteAllSearchableItemsCalled = false

    // Second indexing (same goals)
    await indexer.reindexAllGoals()

    XCTAssertFalse(mockSearchableIndex.deleteAllSearchableItemsCalled, "Second run should not delete all")
    XCTAssertEqual(mockSearchableIndex.indexedEntities.count, 2, "Should have indexed twice")
  }

  func testDeletedGoalIsRemovedFromIndex() async throws {
    let user = createTestUser()
    let goal1 = createTestGoal(owner: user, slug: "goal-one", title: "First Goal")
    _ = createTestGoal(owner: user, slug: "goal-two", title: "Second Goal")
    try container.viewContext.save()

    let indexer = SpotlightIndexer(
      container: container,
      currentUserManager: currentUserManager,
      searchableIndex: mockSearchableIndex
    )

    // First indexing with 2 goals
    await indexer.reindexAllGoals()
    XCTAssertEqual(mockSearchableIndex.indexedEntities.first?.count, 2)

    // Delete one goal
    container.viewContext.delete(goal1)
    try container.viewContext.save()
    // Refresh all objects to ensure the User's goals relationship reflects the deletion.
    // In production, this happens automatically via NSManagedObjectContextObjectsDidChange
    // notifications, but in tests we call reindexAllGoals() directly.
    container.viewContext.refreshAllObjects()

    // Second indexing
    await indexer.reindexAllGoals()

    XCTAssertEqual(mockSearchableIndex.deletedIdentifiers, ["goal-one-id"], "Should delete removed goal")
    XCTAssertEqual(mockSearchableIndex.indexedEntities.last?.count, 1, "Should index remaining goal")
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
