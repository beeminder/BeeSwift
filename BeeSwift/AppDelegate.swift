//
//  AppDelegate.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/19/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import UIKit
import IQKeyboardManager
import HealthKit
import Sentry
import AlamofireNetworkActivityIndicator
import BeeKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        resetStateIfUITesting()
        removeAllLocalNotifications()

        UINavigationBar.appearance().titleTextAttributes = [NSAttributedString.Key.font :
            UIFont.beeminder.defaultFontPlain.withSize(20)]
        UIBarButtonItem.appearance().setTitleTextAttributes([NSAttributedString.Key.font : UIFont.beeminder.defaultFontPlain.withSize(18)], for: UIControl.State())
        IQKeyboardManager.shared().isEnableAutoToolbar = false

        if HKHealthStore.isHealthDataAvailable() {
            HealthStoreManager.sharedManager.setupHealthkit()
        }

        // start crash handler
        SentrySDK.start { options in
            options.dsn = Config.init().sentryClientDSN
            options.debug = true
        }
        
        NetworkActivityIndicatorManager.shared.isEnabled = true
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateBadgeCount), name: NSNotification.Name(rawValue: CurrentUserManager.goalsFetchedNotificationName), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateBadgeCount), name: NSNotification.Name(rawValue: CurrentUserManager.signedOutNotificationName), object: nil)

        application.setMinimumBackgroundFetchInterval(15 * 60)
        
        return true
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) {
        CurrentUserManager.sharedManager.fetchGoals(success: { (goals) in
            //
        }) { (error, errorMessage) in
            //
        }
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        CurrentUserManager.sharedManager.fetchGoals(success: nil, error: nil)
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    /// https://developer.apple.com/documentation/uikit/app_and_environment/scenes/preparing_your_ui_to_run_in_the_background/updating_your_app_with_background_app_refresh
    ///
    /// and for iOS 13 and over: https://developer.apple.com/documentation/backgroundtasks/bgapprefreshtask
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        CurrentUserManager.sharedManager.fetchGoals(success: { (goals) in
            completionHandler(.newData)
        }) { (error, errorMessage) in
            completionHandler(.failed)
        }
    }
    
    

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any]) -> Bool {
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
        let token = deviceToken.reduce("", {$0 + String(format: "%02X", $1)})

        SignedRequestManager.signedPOST(url: "/api/private/device_tokens", parameters: ["device_token" : token], success: { (responseObject) -> Void in
            //foo
        }) { (error, errorMessage) -> Void in
            //bar
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
//        RemoteNotificationsManager.sharedManager.didFailToRegisterForRemoteNotificationsWithError(error)
    }
    
    @objc func updateBadgeCount() {
        UIApplication.shared.applicationIconBadgeNumber = CurrentUserManager.sharedManager.goals.filter({ (goal: JSONGoal) -> Bool in
            return goal.relativeLane.intValue < -1
        }).count
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .sound, .badge])
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
        if #available(iOS 12.0, *) {
            if let intent = userActivity.interaction?.intent as? AddDataIntent {
                NotificationCenter.default.post(name: Notification.Name(rawValue: "openGoal"), object: nil, userInfo: ["slug": slug])
                
                // Early return to avoid also checking userInfo
                return true
            }
        }
        if let slug = userActivity.userInfo?["slug"] {
            NotificationCenter.default.post(name: Notification.Name(rawValue: "openGoal"), object: nil, userInfo: ["slug": slug])
        }
        return true
    }
}
