//
//  AppDelegate.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/19/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import UIKit
import IQKeyboardManagerSwift
import HealthKit
import AlamofireNetworkActivityIndicator
import BeeKit
import OSLog

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let logger = Logger(subsystem: "com.beeminder.beeminder", category: "AppDelegate")
    let backgroundUpdates = BackgroundUpdates()

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        logger.notice("application:didFinishLaunchingWithOptions")

        resetStateIfUITesting()
        removeAllLocalNotifications()

        UINavigationBar.appearance().titleTextAttributes = [NSAttributedString.Key.font :
            UIFont.beeminder.defaultFontPlain.withSize(20)]
        UIBarButtonItem.appearance().setTitleTextAttributes([NSAttributedString.Key.font : UIFont.beeminder.defaultFontPlain.withSize(18)], for: UIControl.State())
        IQKeyboardManager.shared.enableAutoToolbar = false

        if HKHealthStore.isHealthDataAvailable() {
            // We must register queries for all our healthkit metrics before this method completes
            // in order to successfully be delivered background updates. This means we cannot wait
            // for a round trip to the server to fetch latest goals, so use a potentially stale
            // list from last time we did a successful update.
            if let goals = ServiceLocator.goalManager.staleGoals() {
                ServiceLocator.healthStoreManager.silentlyInstallObservers(goals: goals)
            }
        }
        
        NetworkActivityIndicatorManager.shared.isEnabled = true
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateBadgeCount), name: NSNotification.Name(rawValue: GoalManager.goalsUpdatedNotificationName), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateBadgeCount), name: NSNotification.Name(rawValue: CurrentUserManager.signedOutNotificationName), object: nil)

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

                NotificationCenter.default.post(name: Notification.Name(rawValue: "openGoal"), object: nil, userInfo: ["slug": slug])
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

                NotificationCenter.default.post(name: Notification.Name(rawValue: "openGoal"), object: nil, userInfo: ["slug": slug])
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
    
    @objc func updateBadgeCount() {
        logger.notice("Updating badge count")

        guard let goals = ServiceLocator.goalManager.staleGoals() else { return }
        let beemergencyCount = goals.filter({ (goal: Goal) -> Bool in
            return goal.relativeLane.intValue < -1
        }).count
        logger.notice("Beemergency count is \(beemergencyCount, privacy: .public)")

        UIApplication.shared.applicationIconBadgeNumber = beemergencyCount
    }

    private func refreshGoalsAndLogErrors() {
        Task { @MainActor in
            do {
                let _ = try await ServiceLocator.goalManager.fetchGoals()
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
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        if let intent = userActivity.interaction?.intent as? AddDataIntent {
            guard let goalSlug = intent.goal else { return false }
            NotificationCenter.default.post(name: Notification.Name(rawValue: "openGoal"), object: nil, userInfo: ["slug": goalSlug])
        } else if let goalSlug = userActivity.userInfo?["slug"] {
            NotificationCenter.default.post(name: Notification.Name(rawValue: "openGoal"), object: nil, userInfo: ["slug": goalSlug])
        }
        return true
    }
}
