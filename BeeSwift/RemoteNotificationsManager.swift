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
    
    func handleRegistrationFailure(error: NSError) {
        let alert = UIAlertController(title: "Sorry!", message: "Couldn't turn on push notifications. ", preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: "Go to settings", style: UIAlertActionStyle.Default, handler: { (alertAction) -> Void in
            UIApplication.sharedApplication().openURL(NSURL(string: UIApplicationOpenSettingsURLString)!)
        }))
        UIApplication.sharedApplication().windows.first?.rootViewController?.presentViewController(alert, animated: true, completion: nil)
        self.turnNotificationsOff()
    }

}