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
    
    fileprivate func remoteNotificationsOnKey() -> String {
        if CurrentUserManager.sharedManager.signedIn() {
            return "\(CurrentUserManager.sharedManager.username!)-remoteNotificationsOn"
        }
        return "remoteNotificationsOn"
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
        var deviceTokenString = deviceToken.description.trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
        deviceTokenString = deviceTokenString.replacingOccurrences(of: " ", with: "", options: [], range: nil)
        
        BSHTTPSessionManager.sharedManager.signedPOST("/api/private/device_tokens", parameters: ["device_token" : deviceTokenString], success: { (dataTask, responseObject) -> Void in
            //foo
        }) { (dataTask, error) -> Void in
            //bar
        }
    }
    
    func didFailToRegisterForRemoteNotificationsWithError(_ error: Error) {
        let alert = UIAlertController(title: "Sorry!", message: "There was a problem turning on notifications. Please email support@beeminder.com.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Email support", style: .default, handler: { (alertAction) -> Void in
            UIApplication.shared.openURL(URL(string: "mailto:support@beeminder.com?subject=iOS%20notifications%20error")!)
        }))
        alert.addAction(UIAlertAction(title: "Skip", style: .cancel, handler: { (alertAction) -> Void in
            // do nothing, just cancel
        }))
        UIApplication.shared.windows.first?.rootViewController?.present(alert, animated: true, completion: nil)
        self.turnNotificationsOff()
    }
    
    func didRegisterUserNotificationSettings(_ notificationSettings: UIUserNotificationSettings) {
        if notificationSettings.types != UIUserNotificationType() { return }
        
        let alert = UIAlertController(title: "Sorry!", message: "It looks like Beeminder isn't allowed to send you notifications. Please open settings and make sure that you've allowed Beeminder to send you notifications, or email support@beeminder.com if have and you're still seeing this message.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default, handler: { (alertAction) -> Void in
            UIApplication.shared.openURL(URL(string: UIApplicationOpenSettingsURLString)!)
        }))
        alert.addAction(UIAlertAction(title: "Email support", style: .default, handler: { (alertAction) -> Void in
            UIApplication.shared.openURL(URL(string: "mailto:support@beeminder.com?subject=iOS%20notifications%20problem")!)
        }))
        alert.addAction(UIAlertAction(title: "Skip", style: .cancel, handler: { (alertAction) -> Void in
            // do nothing, just cancel
        }))
        UIApplication.shared.windows.first?.rootViewController?.present(alert, animated: true, completion: nil)
        self.turnNotificationsOff()
    }

}
