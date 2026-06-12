// Part of BeeSwift. Copyright Beeminder

import BeeKit
import OSLog
import UIKit

/// Runs the side effects that should happen once each time an authenticated
/// session becomes active — i.e. when the app launches already signed in, or the
/// user signs in during the session.
///
/// These are *session-start* tasks: they need a signed-in user and may prompt or
/// make authenticated calls (requesting notification permission, registering for
/// remote notifications, ensuring HealthKit goals update in the background). They
/// are distinct from *app-start* tasks (e.g. `silentlyInstallObservers`), which
/// run once per process and never prompt.
///
/// `run()` is guarded so the work happens at most once per session; signing out
/// resets it so the next sign-in runs it again.
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

  /// Run the session-start tasks unless they have already run for this session.
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
