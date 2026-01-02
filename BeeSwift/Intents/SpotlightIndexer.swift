// Part of BeeSwift. Copyright Beeminder

import BeeKit
import CoreSpotlight
import Foundation
import OSLog

class SpotlightIndexer {
  private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "SpotlightIndexer")
  private let container: BeeminderPersistentContainer
  private let currentUserManager: CurrentUserManager

  init(container: BeeminderPersistentContainer, currentUserManager: CurrentUserManager) {
    self.container = container
    self.currentUserManager = currentUserManager
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
          try await CSSearchableIndex.default().indexAppEntities(entities)
          self.logger.info("Indexed \(entities.count) goals in Spotlight")
        } catch { self.logger.error("Failed to index goals: \(error)") }
      }
    }
  }

  func clearIndex() async {
    do {
      try await CSSearchableIndex.default().deleteAllSearchableItems()
      logger.info("Cleared Spotlight index")
    } catch { logger.error("Failed to clear Spotlight index: \(error)") }
  }
}
