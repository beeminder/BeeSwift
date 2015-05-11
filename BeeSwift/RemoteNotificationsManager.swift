//
//  RemoteNotificationsManager.swift
//  BeeSwift
//
//  Created by Andy Brett on 5/8/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation
import AFNetworking

class RemoteNotificationsManager {
    
    class var sharedManager :RemoteNotificationsManager {
        struct Manager {
            static let sharedManager = RemoteNotificationsManager()
        }
        return Manager.sharedManager
    }
    
    func turnNotificationsOn() {
        UIApplication.sharedApplication().registerForRemoteNotifications()
        
        
    }
    
    func turnNotificationsOff() {
        
    }
    
    func handleDeviceToken(deviceToken: NSData) {
        var deviceTokenString = NSString(data: deviceToken, encoding: NSUTF8StringEncoding)!.stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "<>"))
        deviceTokenString = deviceTokenString.stringByReplacingOccurrencesOfString(" ", withString: "", options: nil, range: nil)
        
        BSHTTPSessionManager.sharedManager.signedPOST("/api/private/device_tokens", parameters: ["device_token" : deviceTokenString], success: { (dataTask, responseObject) -> Void in
            //foo
        }) { (dataTask, error) -> Void in
            //bar
        }
    }
    
    func handleRegistrationFailure(error: NSError) {
        
    }

}