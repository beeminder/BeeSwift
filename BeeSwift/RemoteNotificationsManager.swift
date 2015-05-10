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
        var deviceTokenString = deviceToken.description.stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "<>"))
        deviceTokenString = deviceTokenString.stringByReplacingOccurrencesOfString(" ", withString: "", options: nil, range: nil)
        
        let manager = AFHTTPRequestOperationManager()
        manager.responseSerializer = AFJSONResponseSerializer()
        manager.POST("https://www.beeminder.com/api/v1/", parameters: ["device_token": "foo"], success: { (request, responseObject) -> Void in
            //foo
        }) { (request, error) -> Void in
            //bar
        }
    }
    
    func handleRegistrationFailure(error: NSError) {
        
    }
    
//    func hmacSha1SignatureForBaseString(baseString: NSString, andKey key: NSString) {
//        cKey :const char = key.cStringUsingEncoding(NSASCIIStringEncoding)
//        cData :const char = baseString.cStringUsingEncoding(NSASCIIStringEncoding)
//        
//        var foo :NSString
//    }
    
//    + (NSString *)hmacSha1SignatureForBaseString:(NSString *)baseString andKey:(NSString *)key
//    {
//    const char *cKey  = [key cStringUsingEncoding:NSASCIIStringEncoding];
//    const char *cData = [baseString cStringUsingEncoding:NSASCIIStringEncoding];
//    unsigned char cHMAC[CC_SHA1_DIGEST_LENGTH];
//    
//    CCHmac(kCCHmacAlgSHA1, cKey, strlen(cKey), cData, strlen(cData), cHMAC);
//    
//    NSData *HMAC = [[NSData alloc] initWithBytes:cHMAC length:sizeof(cHMAC)];
//    return [NSString base64StringFromData:HMAC length:HMAC.length];
//    }

}