//
//  SpotlightIndexerTests.swift
//  BeeSwiftTests
//
//  Copyright 2024 APB. All rights reserved.
//

import AppIntents
import CoreData
import XCTest

@testable import BeeKit
@testable import BeeSwift

class MockSearchableIndex: SearchableIndexing {
  var indexedEntityCounts: [Int] = []
  var deleteAllSearchableItemsCalled = false

  func indexAppEntities<T: IndexedEntity>(_ entities: [T], priority: Int) async throws {
    indexedEntityCounts.append(entities.count)
  }

  func deleteAllSearchableItems() async throws { deleteAllSearchableItemsCalled = true }
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

    XCTAssertTrue(mockSearchableIndex.indexedEntityCounts.isEmpty, "Should not index when no user")
  }

  func testClearIndexCallsDeleteAll() async {
    let indexer = SpotlightIndexer(
      container: container,
      currentUserManager: currentUserManager,
      searchableIndex: mockSearchableIndex
    )

    await indexer.clearIndex()

    XCTAssertTrue(mockSearchableIndex.deleteAllSearchableItemsCalled, "Should call deleteAllSearchableItems")
  }
}
