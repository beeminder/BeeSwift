//
//  CurrentUserManager.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/26/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation
import MagicalRecord
import AFNetworking

class CurrentUserManager {
    
    private let accessTokenKey = "accessToken"

    class var sharedManager :CurrentUserManager {
        struct Manager {
            static let sharedManager = CurrentUserManager()
        }
        return Manager.sharedManager
    }
    
    var accessToken :String? {
        return NSUserDefaults.standardUserDefaults().objectForKey(accessTokenKey) as! String?
    }
    
    func setAccessToken(accessToken: String) {
        NSUserDefaults.standardUserDefaults().setObject(accessToken, forKey: accessTokenKey)
        NSUserDefaults.standardUserDefaults().synchronize()
    }
    
    func signInWithEmail(email: String, password: String, success: (()->Void)!, error: ((message: String)->Void)!) {
        
        let manager = AFHTTPRequestOperationManager()
        manager.responseSerializer = AFJSONResponseSerializer()
        
        manager.POST("https://www.beeminder.com/api/private/sign_in", parameters: ["user": ["login": email, "password": password], "beemios_secret": "foo"], success: { (operation: AFHTTPRequestOperation!, responseObject: AnyObject!) -> Void in
            println(responseObject)
            NSUserDefaults.standardUserDefaults().setObject(responseObject["access_token"], forKey: self.accessTokenKey)
            NSUserDefaults.standardUserDefaults().synchronize()
            success()
            }) { (operation: AFHTTPRequestOperation!, responseError: NSError!) -> Void in
                error(message: responseError.description)
        }
    }
    
    func signOut() {
        DataSyncManager.sharedManager.setLastSynced(nil)
        LocalNotificationsManager.sharedManager.turnLocalNotificationsOff()
        NSUserDefaults.standardUserDefaults().removeObjectForKey(accessTokenKey)
        NSUserDefaults.standardUserDefaults().synchronize()
        for goal in Goal.MR_findAll() {
            goal.MR_deleteEntity()
        }
        NSManagedObjectContext.MR_defaultContext().save(nil)
    }

}