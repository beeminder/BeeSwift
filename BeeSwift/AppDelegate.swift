//
//  AppDelegate.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/19/15.
//  Copyright 2015 APB. All rights reserved.
//

import CoreSpotlight
import HealthKit
import OSLog
import UIKit

import IQKeyboardManagerSwift
import AlamofireNetworkActivityIndicator

import BeeKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let logger = Logger(subsystem: "com.beeminder.beeminder", category: "AppDelegate")
    let backgroundUpdates = BackgroundUpdates()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        logger.notice("application:didFinishLaunchingWithOptions")

        resetStateIfUITesting()
        removeAllLocalNotifications()

        UINavigationBar.appearance().titleTextAttributes = [NSAttributedString.Key.font :
            UIFont.beeminder.defaultFontPlain.withSize(20)]
        UIBarButtonItem.appearance().setTitleTextAttributes([NSAttributedString.Key.font : UIFont.beeminder.defaultFontPlain.withSize(18)], for: UIControl.State())

        IQKeyboardManager.shared.isEnabled = true
        
        if HKHealthStore.isHealthDataAvailable() {
                // We must register queries for all our healthkit metrics before this method completes
                // in order to successfully be delivered background updates.
            ServiceLocator.healthStoreManager.silentlyInstallObservers(context: ServiceLocator.persistentContainer.viewContext)
        }
        
        NetworkActivityIndicatorManager.shared.isEnabled = true
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleGoalsUpdated), name: GoalManager.NotificationName.goalsUpdated, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleUserSignedOut), name: CurrentUserManager.NotificationName.signedOut, object: nil)

        backgroundUpdates.startUpdatingRegularlyInBackground()
        
        return true
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) {
        logger.notice("application:didReceiveRemoteNotification")

        refreshGoalsAndLogErrors()
    }

    func applicationWillResignActive(_ application: UIApplication) {
        logger.notice("applicationWillResignActive")
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        logger.notice("applicationDidEnterBackground")
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        logger.notice("applicationWillEnterForeground")
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        logger.notice("applicationDidBecomeActive")
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        refreshGoalsAndLogErrors()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        logger.notice("applicationWillTerminate")
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any]) -> Bool {
        logger.notice("application:open:options")
        if url.scheme == "beeminder" {
            if let query = url.query {
                let slugKeyIndex = query.components(separatedBy: "=").firstIndex(of: "slug")
                let slug = query.components(separatedBy: "=")[(slugKeyIndex?.advanced(by: 1))!]

                NotificationCenter.default.post(name: GalleryViewController.NotificationName.openGoal, object: nil, userInfo: ["slug": slug])
            }
        }
        return true
    }

    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        logger.notice("application:open:sourceApplication:annotation")
        if url.scheme == "beeminder" {
            if let query = url.query {
                let slugKeyIndex = query.components(separatedBy: "=").firstIndex(of: "slug")
                let slug = query.components(separatedBy: "=")[(slugKeyIndex?.advanced(by: 1))!]

                NotificationCenter.default.post(name: GalleryViewController.NotificationName.openGoal, object: nil, userInfo: ["slug": slug])
            }
        }
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        logger.notice("application:didRegisterForRemoteNotificationsWithDeviceToken")
        Task { @MainActor in
            let token = deviceToken.reduce("", {$0 + String(format: "%02X", $1)})

            do {
                let _ = try await ServiceLocator.signedRequestManager.signedPOST(url: "/api/private/device_tokens", parameters: ["device_token" : token])
            } catch {
                logger.error("Error sending device push token: \(error)")
            }
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        logger.notice("application:didFailToRegisterForRemoteNotificationsWithError")
    }

    @objc private func handleGoalsUpdated() {
        assert(Thread.isMainThread, "\(#function) must be run on the main thread")

        let context = ServiceLocator.persistentContainer.viewContext
        guard let goals = ServiceLocator.goalManager.staleGoals(context: context) else { return }
        let beemergencyCount = goals.count(where: { $0.safeBuf < 1})
        logger.notice("Updating Beemergency badge count to \(beemergencyCount, privacy: .public)")

        UNUserNotificationCenter.current().setBadgeCount(beemergencyCount)
    }
    
    @objc private func handleUserSignedOut() {
        assert(Thread.isMainThread, "\(#function) must be run on the main thread")

        logger.notice("User signed out; updating Beemergency badge count to 0")

        UNUserNotificationCenter.current().setBadgeCount(0)
    }

    private func refreshGoalsAndLogErrors() {
        Task { @MainActor in
            do {
                let _ = try await ServiceLocator.healthStoreManager.updateAllGoalsWithRecentData(days: 7)
            } catch {
                logger.error("Error updating from healthkit: \(error)")
            }
            do {
                try await ServiceLocator.goalManager.refreshGoals()
            } catch {
                logger.error("Error refreshing goals: \(error)")
            }
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.list, .banner, .sound, .badge])
    }
    
    private func resetStateIfUITesting() {
        if ProcessInfo.processInfo.arguments.contains("UI-Testing") {
            UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        }
    }
    
    private func removeAllLocalNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
