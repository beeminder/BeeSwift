// Part of BeeSwift. Copyright Beeminder

import BeeKit
import OSLog
import UIKit

class SessionStartup {
  private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "SessionStartup")
  private let healthStoreManager: HealthStoreManager
  private var hasRun = false

  init(healthStoreManager: HealthStoreManager) {
    self.healthStoreManager = healthStoreManager
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleSignOut),
      name: CurrentUserManager.NotificationName.signedOut,
      object: nil,
    )
  }

  func run() {
    guard !hasRun else { return }
    hasRun = true

    requestNotificationAuthorization()
    setupHealthKit()
  }

  @objc private func handleSignOut() { hasRun = false }

  private func requestNotificationAuthorization() {
    UNUserNotificationCenter.current().requestAuthorization(options: UNAuthorizationOptions([.alert, .badge, .sound])) {
      [weak self] (success, error) in
      self?.logger.info("Requested notification authorization on session start; successful? \(success)")
      guard success else { return }
      DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
    }
  }

  private func setupHealthKit() {
    Task { @MainActor in
      logger.notice("setupHealthKit: Starting HealthKit setup")
      do {
        try await healthStoreManager.ensureGoalsUpdateRegularly()
        logger.notice("setupHealthKit: HealthKit setup completed successfully")
      } catch { logger.error("setupHealthKit: Failed to setup HealthKit: \(error)") }
    }
  }
}
