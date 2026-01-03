// Part of BeeSwift. Copyright Beeminder

import AppIntents
import AsyncAlgorithms
import BeeKit
import CoreSpotlight
import Foundation
import OSLog

protocol SearchableIndexing: Sendable {
  func indexAppEntities<T: IndexedEntity>(_ entities: [T], priority: Int) async throws
  func deleteAllSearchableItems() async throws
  func deleteSearchableItems(withIdentifiers identifiers: [String]) async throws
}

extension CSSearchableIndex: SearchableIndexing {}

actor SpotlightIndexer {
  private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "SpotlightIndexer")
  private let container: BeeminderPersistentContainer
  private let currentUserManager: CurrentUserManager
  private let searchableIndex: SearchableIndexing
  private var indexedIds: Set<String> = []

  init(
    container: BeeminderPersistentContainer,
    currentUserManager: CurrentUserManager,
    searchableIndex: SearchableIndexing = CSSearchableIndex.default()
  ) {
    self.container = container
    self.currentUserManager = currentUserManager
    self.searchableIndex = searchableIndex
  }

  func listenForNotifications() async {
    let goalsUpdated = NotificationCenter.default.notifications(named: GoalManager.NotificationName.goalsUpdated).map {
      _ in IndexAction.reindex
    }
    let signedOut = NotificationCenter.default.notifications(named: CurrentUserManager.NotificationName.signedOut).map {
      _ in IndexAction.clear
    }

    for await action in merge(goalsUpdated, signedOut) {
      switch action {
      case .reindex: await reindexAllGoals()
      case .clear: await clearIndex()
      }
    }
  }

  func reindexAllGoals() async {
    let context = container.viewContext
    let entities = await context.perform {
      guard let user = self.currentUserManager.user(context: context) else {
        self.logger.info("No user, skipping spotlight indexing")
        return [GoalEntity]()
      }
      return user.goals.map { GoalEntity(from: $0) }
    }

    let currentIds = Set(entities.map { $0.id })

    do {
      if indexedIds.isEmpty {
        // First run: clear any stale items
        try await searchableIndex.deleteAllSearchableItems()
      } else {
        // Incremental: only delete removed goals
        let deletedIds = indexedIds.subtracting(currentIds)
        if !deletedIds.isEmpty {
          try await searchableIndex.deleteSearchableItems(withIdentifiers: Array(deletedIds))
          logger.info("Removed \(deletedIds.count) deleted goals from Spotlight")
        }
      }

      if !entities.isEmpty {
        try await searchableIndex.indexAppEntities(entities, priority: 0)
        logger.info("Indexed \(entities.count) goals in Spotlight")
      }

      indexedIds = currentIds
    } catch { logger.error("Failed to index goals: \(error)") }
  }

  func clearIndex() async {
    do {
      try await searchableIndex.deleteAllSearchableItems()
      indexedIds = []
      logger.info("Cleared Spotlight index")
    } catch { logger.error("Failed to clear Spotlight index: \(error)") }
  }
}

private enum IndexAction {
  case reindex
  case clear
}
