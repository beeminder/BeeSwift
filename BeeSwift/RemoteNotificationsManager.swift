//
//  RemoteNotificationsManager.swift
//  BeeSwift
//
//  Created by Andy Brett on 5/8/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation
import AFNetworking

class RemoteNotificationsManager :NSObject {
    
    static let sharedManager = RemoteNotificationsManager()
    
    required override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(RemoteNotificationsManager.handleUserSignoutNotification), name: NSNotification.Name(rawValue: CurrentUserManager.willSignOutNotificationName), object: nil)
    }
    
    fileprivate func remoteNotificationsOnKey() -> String {
        if CurrentUserManager.sharedManager.signedIn() {
            return "\(CurrentUserManager.sharedManager.username!)-remoteNotificationsOn"
        }
        return "remoteNotificationsOn"
    }
    
    @objc func handleUserSignoutNotification() {
        turnNotificationsOff()
    }
    
    func on() -> Bool {
        return UserDefaults.standard.object(forKey: self.remoteNotificationsOnKey()) != nil
    }
    
    func turnNotificationsOn() {
        UIApplication.shared.registerUserNotificationSettings(UIUserNotificationSettings(types: [UIUserNotificationType.alert, UIUserNotificationType.sound, UIUserNotificationType.badge], categories: nil))
        UIApplication.shared.registerForRemoteNotifications()
    }
    
    func turnNotificationsOff() {
        UserDefaults.standard.removeObject(forKey: self.remoteNotificationsOnKey())
        UserDefaults.standard.synchronize()
    }
    
    func didRegisterForRemoteNotificationsWithDeviceToken(_ deviceToken: Data) {
        UserDefaults.standard.set(true, forKey: self.remoteNotificationsOnKey())
        UserDefaults.standard.synchronize()
        let token = deviceToken.reduce("", {$0 + String(format: "%02X", $1)})
        
        BSHTTPSessionManager.sharedManager.signedPOST("/api/private/device_tokens", parameters: ["device_token" : token], success: { (dataTask, responseObject) -> Void in
            //foo
        }) { (dataTask, error) -> Void in
            //bar
        }
    }
    
    func didFailToRegisterForRemoteNotificationsWithError(_ error: Error) {
        // nothing to do
    }
    
    func didRegisterUserNotificationSettings(_ notificationSettings: UIUserNotificationSettings) {
        // nothing to do
    }

}
