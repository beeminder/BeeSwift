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
    
    private func remoteNotificationsOnKey() -> String {
        if CurrentUserManager.sharedManager.signedIn() {
            return "\(CurrentUserManager.sharedManager.username!)-remoteNotificationsOn"
        }
        return "remoteNotificationsOn"
    }
    
    func on() -> Bool {
        return NSUserDefaults.standardUserDefaults().objectForKey(self.remoteNotificationsOnKey()) != nil
    }
    
    func turnNotificationsOn() {
        UIApplication.sharedApplication().registerUserNotificationSettings(UIUserNotificationSettings(forTypes: [UIUserNotificationType.Alert, UIUserNotificationType.Sound, UIUserNotificationType.Badge], categories: nil))
        UIApplication.sharedApplication().registerForRemoteNotifications()
    }
    
    func turnNotificationsOff() {
        NSUserDefaults.standardUserDefaults().removeObjectForKey(self.remoteNotificationsOnKey())
        NSUserDefaults.standardUserDefaults().synchronize()
    }
    
    func didRegisterForRemoteNotificationsWithDeviceToken(deviceToken: NSData) {
        NSUserDefaults.standardUserDefaults().setBool(true, forKey: self.remoteNotificationsOnKey())
        NSUserDefaults.standardUserDefaults().synchronize()
        var deviceTokenString = deviceToken.description.stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "<>"))
        deviceTokenString = deviceTokenString.stringByReplacingOccurrencesOfString(" ", withString: "", options: [], range: nil)
        
        BSHTTPSessionManager.sharedManager.signedPOST("/api/private/device_tokens", parameters: ["device_token" : deviceTokenString], success: { (dataTask, responseObject) -> Void in
            //foo
        }) { (dataTask, error) -> Void in
            //bar
        }
    }
    
    func didFailToRegisterForRemoteNotificationsWithError(error: NSError) {
        let alert = UIAlertController(title: "Sorry!", message: "There was a problem turning on notifications. Please email support@beeminder.com.", preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: "Email support", style: .Default, handler: { (alertAction) -> Void in
            UIApplication.sharedApplication().openURL(NSURL(string: "mailto:support@beeminder.com?subject=iOS%20notifications%20error")!)
        }))
        alert.addAction(UIAlertAction(title: "Skip", style: .Cancel, handler: { (alertAction) -> Void in
            // do nothing, just cancel
        }))
        UIApplication.sharedApplication().windows.first?.rootViewController?.presentViewController(alert, animated: true, completion: nil)
        self.turnNotificationsOff()
    }
    
    func didRegisterUserNotificationSettings(notificationSettings: UIUserNotificationSettings) {
        if notificationSettings.types != UIUserNotificationType.None { return }
        
        let alert = UIAlertController(title: "Sorry!", message: "It looks like Beeminder isn't allowed to send you notifications. Please open settings and make sure that you've allowed Beeminder to send you notifications, or email support@beeminder.com if have and you're still seeing this message.", preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: "Open Settings", style: .Default, handler: { (alertAction) -> Void in
            UIApplication.sharedApplication().openURL(NSURL(string: UIApplicationOpenSettingsURLString)!)
        }))
        alert.addAction(UIAlertAction(title: "Email support", style: .Default, handler: { (alertAction) -> Void in
            UIApplication.sharedApplication().openURL(NSURL(string: "mailto:support@beeminder.com?subject=iOS%20notifications%20problem")!)
        }))
        alert.addAction(UIAlertAction(title: "Skip", style: .Cancel, handler: { (alertAction) -> Void in
            // do nothing, just cancel
        }))
        UIApplication.sharedApplication().windows.first?.rootViewController?.presentViewController(alert, animated: true, completion: nil)
        self.turnNotificationsOff()
    }

}