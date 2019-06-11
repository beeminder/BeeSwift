//
//  AppDelegate.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/19/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import UIKit
import CoreData
import MagicalRecord
import TwitterKit
import IQKeyboardManager
import HealthKit
import Sentry
import AlamofireNetworkActivityIndicator

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        MagicalRecord.setupAutoMigratingCoreDataStack()

        UINavigationBar.appearance().titleTextAttributes = [NSAttributedStringKey.font : UIFont(name: "Avenir", size: 20)!]
        UIBarButtonItem.appearance().setTitleTextAttributes([NSAttributedStringKey.font : UIFont(name: "Avenir", size: 18)!], for: UIControlState())
        Twitter.sharedInstance().start(withConsumerKey: Config.twitterConsumerKey, consumerSecret: Config.twitterConsumerSecret)
        IQKeyboardManager.shared().isEnableAutoToolbar = false

        GIDSignIn.sharedInstance().clientID = Config.googleClientId
        GIDSignIn.sharedInstance().delegate = OAuthSignInManager.sharedManager

        if HKHealthStore.isHealthDataAvailable() {
            HealthStoreManager.sharedManager.setupHealthkit()
        }

        // Create a Sentry client and start crash handler
        do {
            Client.shared = try Client(dsn: Config.sentryClientDSN)
            try Client.shared?.startCrashHandler()
        } catch let error {
            print("\(error)")
            // Wrong DSN or KSCrash not installed
        }

        NotificationCenter.default.addObserver(self, selector: #selector(self.handleSignOut), name: NSNotification.Name(rawValue: CurrentUserManager.signedOutNotificationName), object: nil)
        
        NetworkActivityIndicatorManager.shared.isEnabled = true
        
        if UserDefaults.standard.object(forKey: Constants.healthSyncRemindersPreferenceKey) == nil {
            UserDefaults.standard.set(true, forKey: Constants.healthSyncRemindersPreferenceKey)
        }

        return true
    }

    @objc func handleSignOut() {
        self.updateTodayWidget()
        self.updateBadgeCount()
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) {
        DataSyncManager.sharedManager.fetchData(success: { () -> Void in
            //
        }, error: { () -> Void in
            //
        })
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
        
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: "didBecomeActive")))
        DataSyncManager.sharedManager.fetchData(success: { () -> Void in
            self.updateBadgeCount()
            self.updateTodayWidget()
        }, error: { () -> Void in
            //nil
        })
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        DataSyncManager.sharedManager.fetchData(success: { () -> Void in
            completionHandler(.newData)
        }, error: { () -> Void in
            completionHandler(.failed)
        })
    }

    @available(iOS 9.0, *)
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any]) -> Bool {
        if url.scheme == Config.facebookUrlScheme {
            return FBSDKApplicationDelegate.sharedInstance().application(app, open: url, sourceApplication: options[UIApplicationOpenURLOptionsKey.sourceApplication] as? String, annotation: options[UIApplicationOpenURLOptionsKey.annotation])
        }
        else if url.scheme == Config.googleReversedClientId {
            return GIDSignIn.sharedInstance().handle(url, sourceApplication: options[UIApplicationOpenURLOptionsKey.sourceApplication] as? String, annotation: options[UIApplicationOpenURLOptionsKey.annotation])
        }
        else if url.scheme == "beeminder" {
            if let query = url.query {
                let slugKeyIndex = query.components(separatedBy: "=").index(of: "slug")
                let slug = query.components(separatedBy: "=")[(slugKeyIndex?.advanced(by: 1))!]

                NotificationCenter.default.post(name: Notification.Name(rawValue: "openGoal"), object: nil, userInfo: ["slug": slug])
            }
        } else if url.scheme == Config.twitterUrlScheme {
            return Twitter.sharedInstance().application(app, open: url, options: options)
        }
        DataSyncManager.sharedManager.fetchData(success: nil, error: nil)
        return true
    }

    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        if url.scheme == Config.facebookUrlScheme {
            return FBSDKApplicationDelegate.sharedInstance().application(application, open: url, sourceApplication: sourceApplication, annotation: annotation)
        }
        else if url.scheme == Config.googleReversedClientId {
            return GIDSignIn.sharedInstance().handle(url, sourceApplication: sourceApplication, annotation: annotation)
        }
        else if url.scheme == "beeminder" {
            if let query = url.query {
                let slugKeyIndex = query.components(separatedBy: "=").index(of: "slug")
                let slug = query.components(separatedBy: "=")[(slugKeyIndex?.advanced(by: 1))!]

                NotificationCenter.default.post(name: Notification.Name(rawValue: "openGoal"), object: nil, userInfo: ["slug": slug])
            }
        }
        DataSyncManager.sharedManager.fetchData(success: nil, error: nil)
        return true
    }

    func application(_ application: UIApplication, didRegister notificationSettings: UIUserNotificationSettings) {
        RemoteNotificationsManager.sharedManager.didRegisterUserNotificationSettings(notificationSettings)
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        RemoteNotificationsManager.sharedManager.didRegisterForRemoteNotificationsWithDeviceToken(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        RemoteNotificationsManager.sharedManager.didFailToRegisterForRemoteNotificationsWithError(error)
    }

    func updateBadgeCount() {
        let allGoals = Goal.mr_findAll(with: NSPredicate(format: "serverDeleted = false")) as! [Goal]
        UIApplication.shared.applicationIconBadgeNumber = allGoals.filter({ (goal: Goal) -> Bool in
            return goal.relativeLane.intValue < -1
        }).count
    }

    func updateTodayWidget() {
        let sharedDefaults = UserDefaults(suiteName: "group.beeminder.beeminder")

        sharedDefaults?.set(self.todayGoalDictionaries(), forKey: "todayGoalDictionaries")
        sharedDefaults?.set(CurrentUserManager.sharedManager.accessToken, forKey: "accessToken")
        sharedDefaults?.synchronize()
    }

    func todayGoalDictionaries() -> Array<NSDictionary> {
        guard let goals = Goal.mr_findAllSorted(by: "losedate", ascending: true, with: NSPredicate(format: "serverDeleted = false")) as? [Goal] else { return [] }

        if goals.count < 3 {
            return goals.map { (goal: Goal) -> NSDictionary in
                var shortSlug = goal.slug
                if shortSlug.count > 20 {
                    shortSlug = String(shortSlug[..<shortSlug.index(shortSlug.endIndex, offsetBy: -1)])
                }
                return [ "thumbUrl": goal.cacheBustingThumbUrl, "limSum": "\(shortSlug): \(goal.limsum)", "slug": goal.slug, "hideDataEntry": goal.hideDataEntry()]
            }
        }

        return goals[0..<3].map { (goal: Goal) -> NSDictionary in
            var shortSlug = goal.slug
            if shortSlug.count > 20 {
                shortSlug = String(shortSlug[..<shortSlug.index(shortSlug.endIndex, offsetBy: -1)])
            }
            return [ "thumbUrl": goal.cacheBustingThumbUrl, "limSum": "\(shortSlug): \(goal.limsum)", "slug": goal.slug, "hideDataEntry": goal.hideDataEntry()]
        }
    }
}
