//
//  AppDelegate.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/19/15.
//  Copyright 2015 APB. All rights reserved.
//

import AlamofireNetworkActivityIndicator
import BeeKit
import CoreSpotlight
import HealthKit
import IQKeyboardManagerSwift
import OSLog
import UIKit

@UIApplicationMain class AppDelegate: UIResponder, UIApplicationDelegate {
  let logger = Logger(subsystem: "com.beeminder.beeminder", category: "AppDelegate")
  let backgroundUpdates = BackgroundUpdates()

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    logger.notice("application:didFinishLaunchingWithOptions")

    resetStateIfUITesting()
    removeAllLocalNotifications()

    UINavigationBar.appearance().titleTextAttributes = [
      NSAttributedString.Key.font: UIFont.beeminder.defaultFontPlain.withSize(20)
    ]
    UIBarButtonItem.appearance().setTitleTextAttributes(
      [NSAttributedString.Key.font: UIFont.beeminder.defaultFontPlain.withSize(18)],
      for: UIControl.State()
    )

    IQKeyboardManager.shared.isEnabled = true
    if HKHealthStore.isHealthDataAvailable() {
      // We must register queries for all our healthkit metrics before this method completes
      // in order to successfully be delivered background updates.
      ServiceLocator.healthStoreManager.silentlyInstallObservers(
        context: ServiceLocator.persistentContainer.viewContext
      )
    }
    NetworkActivityIndicatorManager.shared.isEnabled = true
    UNUserNotificationCenter.current().delegate = self

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(self.handleGoalsUpdated),
      name: GoalManager.NotificationName.goalsUpdated,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(self.handleUserSignedOut),
      name: CurrentUserManager.NotificationName.signedOut,
      object: nil
    )

    backgroundUpdates.startUpdatingRegularlyInBackground()
    return true
  }

  func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
    logger.notice("application:didReceiveRemoteNotification")

    // Refresh goals when receiving remote notification
    Task { @MainActor in await ServiceLocator.refreshManager.refreshGoalsAndHealthKitData() }
  }

  func applicationWillTerminate(_ application: UIApplication) { logger.notice("applicationWillTerminate") }
  func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    logger.notice("application:didRegisterForRemoteNotificationsWithDeviceToken")
    Task { @MainActor in
      let token = deviceToken.reduce("", { $0 + String(format: "%02X", $1) })

      var parameters = ["device_token": token]
      if isDevelopmentBuild() {
        parameters["server"] = "development"
        logger.notice("Registering device token for development APNS server")
      }

      do {
        let _ = try await ServiceLocator.signedRequestManager.signedPOST(
          url: "/api/private/device_tokens",
          parameters: parameters
        )
      } catch { logger.error("Error sending device push token: \(error)") }
    }
  }

  func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    logger.notice("application:didFailToRegisterForRemoteNotificationsWithError")
  }

  @objc private func handleGoalsUpdated() {
    assert(Thread.isMainThread, "\(#function) must be run on the main thread")

    let context = ServiceLocator.persistentContainer.viewContext
    guard let goals = ServiceLocator.goalManager.staleGoals(context: context) else { return }
    let beemergencyCount = goals.count(where: { $0.safeBuf < 1 })
    logger.notice("Updating Beemergency badge count to \(beemergencyCount, privacy: .public)")

    UNUserNotificationCenter.current().setBadgeCount(beemergencyCount)
  }
  @objc private func handleUserSignedOut() {
    assert(Thread.isMainThread, "\(#function) must be run on the main thread")

    logger.notice("User signed out; updating Beemergency badge count to 0")

    UNUserNotificationCenter.current().setBadgeCount(0)
  }
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    logger.notice("\(#function)")
    guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else {
      completionHandler()
      return
    }

    let userInfo = response.notification.request.content.userInfo
    guard let slug = userInfo["slug"] as? String else {
      logger.error("could not find a goal name under key slug in the notification's userInfo: \(userInfo)")
      completionHandler()
      return
    }

    logger.info("found slug: \(slug)")
    NotificationCenter.default.post(
      name: GalleryViewController.NotificationName.openGoal,
      object: nil,
      userInfo: ["slug": slug]
    )

    completionHandler()
  }
  private func resetStateIfUITesting() {
    if ProcessInfo.processInfo.arguments.contains("UI-Testing") {
      UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
    }
  }
  private func removeAllLocalNotifications() {
    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
  }
  private func isDevelopmentBuild() -> Bool {
    // Simulator builds are always development builds
    if ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil { return true }

    // Check for a mobile provision
    guard let resourcePath = Bundle.main.resourcePath else { return false }
    let provisionPath = (resourcePath as NSString).appendingPathComponent("embedded.mobileprovision")
    return FileManager.default.fileExists(atPath: provisionPath)
  }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async
    -> UNNotificationPresentationOptions
  { [.list, .banner, .sound, .badge] }
}
