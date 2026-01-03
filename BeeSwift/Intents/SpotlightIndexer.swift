// Part of BeeSwift. Copyright Beeminder

import AppIntents
import BeeKit
import CoreSpotlight
import Foundation
import OSLog

protocol SearchableIndexing {
  func indexAppEntities<T: IndexedEntity>(_ entities: [T], priority: Int) async throws
  func deleteAllSearchableItems() async throws
}

extension CSSearchableIndex: SearchableIndexing {}

class SpotlightIndexer {
  private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "SpotlightIndexer")
  private let container: BeeminderPersistentContainer
  private let currentUserManager: CurrentUserManager
  private let searchableIndex: SearchableIndexing

  init(
    container: BeeminderPersistentContainer,
    currentUserManager: CurrentUserManager,
    searchableIndex: SearchableIndexing = CSSearchableIndex.default()
  ) {
    self.container = container
    self.currentUserManager = currentUserManager
    self.searchableIndex = searchableIndex
  }

  func startListening() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(onGoalsUpdated),
      name: GoalManager.NotificationName.goalsUpdated,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(onSignedOut),
      name: CurrentUserManager.NotificationName.signedOut,
      object: nil
    )
  }

  @objc private func onGoalsUpdated() { Task { await reindexAllGoals() } }

  @objc private func onSignedOut() { Task { await clearIndex() } }

  func reindexAllGoals() async {
    let context = container.viewContext
    await context.perform {
      guard let user = self.currentUserManager.user(context: context) else {
        self.logger.info("No user, skipping spotlight indexing")
        return
      }
      let entities = user.goals.map { GoalEntity(from: $0) }
      Task {
        do {
          try await self.searchableIndex.indexAppEntities(entities, priority: 0)
          self.logger.info("Indexed \(entities.count) goals in Spotlight")
        } catch { self.logger.error("Failed to index goals: \(error)") }
      }
    }
  }

  private func clearIndex() async {
    do {
      try await searchableIndex.deleteAllSearchableItems()
      logger.info("Cleared Spotlight index")
    } catch { logger.error("Failed to clear Spotlight index: \(error)") }
  }
}
