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

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        UINavigationBar.appearance().titleTextAttributes = [NSAttributedStringKey.font :
            UIFont.beeminder.defaultFontPlain.withSize(20)]
        UIBarButtonItem.appearance().setTitleTextAttributes([NSAttributedStringKey.font : UIFont.beeminder.defaultFontPlain.withSize(18)], for: UIControlState())
        IQKeyboardManager.shared().isEnableAutoToolbar = false

        if HKHealthStore.isHealthDataAvailable() {
            HealthStoreManager.sharedManager.setupHealthkit()
        }

        // start crash handler
        SentrySDK.start { options in
            options.dsn = Config.sentryClientDSN
            options.debug = true
        }
        
        NetworkActivityIndicatorManager.shared.isEnabled = true
        
        if UserDefaults.standard.object(forKey: Constants.healthSyncRemindersPreferenceKey) == nil {
            UserDefaults.standard.set(true, forKey: Constants.healthSyncRemindersPreferenceKey)
        }
        
        UNUserNotificationCenter.current().delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateBadgeCount), name: NSNotification.Name(rawValue: CurrentUserManager.goalsFetchedNotificationName), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateBadgeCount), name: NSNotification.Name(rawValue: CurrentUserManager.signedOutNotificationName), object: nil)

        application.setMinimumBackgroundFetchInterval(15 * 60)
        
        return true
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
        NotificationCenter.default.post(name: Notification.Name.UIApplicationWillEnterForeground, object: nil)
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
    
    

    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any]) -> Bool {
        guard url.scheme == "beeminder", let slug = url.getSlug() else { return false }
        
        self.fetchGoalsIfNeededThenViewMatchingGoalWith(slug: slug)
        return true
    }

    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        guard url.scheme == "beeminder", let slug = url.getSlug() else { return false }
        
        self.fetchGoalsIfNeededThenViewMatchingGoalWith(slug: slug)
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
        switch notification.request.identifier {
        case JSONGoal.unlockNotificationIdentifier:
            // about to present a notification, a reminder to unlock the device
            // yet the app is active, thus we can abandon the notification
            completionHandler([])
        default:
            completionHandler([.alert, .sound, .badge])
        }
    }
    
    // processing user's response to a notification
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else {
            completionHandler()
            return
        }
        
        guard let slug = response.notification.request.getSlug() else {
            completionHandler()
            return
        }
        
        print("found slug: \(slug)")
        
        self.fetchGoalsIfNeededThenViewMatchingGoalWith(slug: slug)
        
        completionHandler()
    }
    
    // MARK: opening goals
    
    private func fetchGoalsIfNeededThenViewMatchingGoalWith(slug: String) {
        if CurrentUserManager.sharedManager.goals.isEmpty || CurrentUserManager.sharedManager.goalsFetchedAt.timeIntervalSinceNow < -3600 {
            // apparently no data or stale data
            
            CurrentUserManager.sharedManager.fetchGoals(success: { goals in
                CurrentUserManager.sharedManager.goals = goals
                self.openGoalWith(slug)
            }, error: nil)
            
        } else {
            self.openGoalWith(slug)
        }
    }
    
    /// given a goal we shall navigate to it
    private func openGoal(goal: JSONGoal) {
        guard let navigationController = window?.rootViewController as? UINavigationController else { return }
        
        let alreadyShowingGoal = { () -> Bool in
            guard let topVC = navigationController.topViewController as? GoalViewController else { return false }
            return topVC.goal.slug == goal.slug
        }()
        
        if !alreadyShowingGoal {
            let goalVC: GoalViewController = {
                let goalVC = GoalViewController()
                goalVC.goal = goal
                return goalVC
            }()
            navigationController.popToRootViewController(animated: true)
            navigationController.pushViewController(goalVC, animated: true)
        }
    }
    
    /// for viewing, open goal with slug
    /// - Parameter slug: slug of the goal to open
    private func openGoalWith(_ slug: String) {
        guard let goal = CurrentUserManager.sharedManager.goals.last(where: { $0.slug == slug }) else {
            print("no goal matching slug: \(slug)")
            
            guard let navigationController = window?.rootViewController as? UINavigationController else { return }
            navigationController.popToRootViewController(animated: true)
            
            return
        }
        self.openGoal(goal: goal)
    }

}

// MARK: - private extensions for extracting slugs

private extension UNNotificationRequest {
    func getSlug() -> String? {
        return self.content.body.getSlug()
    }
}

private extension Dictionary where Key == AnyHashable, Value == Any {
    func getSlug() -> String? {
        guard let alert = self.getNotificiationAlert() else { return nil }
        
        return alert.getSlug()
    }
    
    func getNotificiationAlert() -> String? {
        guard let aps = self["aps"] as? [String:Any] else { return nil }
        
        return aps["alert"] as? String
    }
}

private extension String {
    
    static let beemergencyEepPrefix = "Eep! "
    static let beemergencyTodayPrefix = "Beemergency today for "
    
    /// returns the slug found in notifications
    ///
    /// - note:
    /// following format expected/supported:
    /// - "Beemergency today for _slug-of-goal_"
    /// - "Eep! _slug-of-goal_ needs _quantity_ _unit_ by _deadline_"
    /// - "_slug-of-goal_ needs _quantity_ _unit_ by _deadline_"
    func getSlug() -> String? {
        let slugStart: String.Index = {
            if self.starts(with: String.beemergencyTodayPrefix) {
                return String.beemergencyTodayPrefix.endIndex
            } else if self.starts(with: String.beemergencyEepPrefix) {
                return String.beemergencyEepPrefix.endIndex
            } else {
                return self.startIndex
            }
        }()
        
        return self
            .suffix(from: slugStart)
            .split(separator: " ")
            .first?
            .trimmingCharacters(in: .whitespaces)
    }
}

private extension URL {
    /// obtains the slug, if found, from an URL
    ///
    /// - Note: currently supports URL "_beeminder://?slug=myslughere_"
    func getSlug() -> String? {
        guard
            self.scheme == "beeminder",
            let elements = self.query?.components(separatedBy: "="),
            let slugKeyIndex = elements.index(of: "slug")
            else { return nil }
        
        let slug = elements[(slugKeyIndex.advanced(by: 1))]
        
        return slug
    }
}
