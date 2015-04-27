//
//  DataSyncManager.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/19/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation
import AFNetworking
import SwiftyJSON
import MagicalRecord

class DataSyncManager {

    var isFetching = false
    private let lastSyncedKey = "lastSynced"
    var accessToken :String?

    class var sharedManager :DataSyncManager {
        struct Manager {
            static let sharedManager = DataSyncManager()
        }
        return Manager.sharedManager
    }
    
    var lastSynced :NSDate? {
        return NSUserDefaults.standardUserDefaults().objectForKey(lastSyncedKey) as! NSDate?
    }
    
    func setLastSynced(date: NSDate) {
        NSUserDefaults.standardUserDefaults().setObject(date, forKey: lastSyncedKey)
        NSUserDefaults.standardUserDefaults().synchronize()
    }
    
    func fetchData(success: (()->Void)!, error: (()->Void)!) {
        if self.isFetching || self.accessToken == nil {
            return
        }
        
        self.isFetching = true
        
        let manager = AFHTTPRequestOperationManager()
        manager.responseSerializer = AFJSONResponseSerializer()
        
        manager.GET("https://www.beeminder.com/api/v1/users/me.json?access_token=\(self.accessToken!)&associations=true&datapoints_count=5&diff_since=0", parameters: nil, success: { (operation: AFHTTPRequestOperation!, responseObject: AnyObject!) -> Void in
                self.handleResponse(JSON(responseObject))
                if (success != nil) { success() }
                self.isFetching = false
                self.setLastSynced(NSDate())
            }) { (operation: AFHTTPRequestOperation!, responseObject: AnyObject!) -> Void in
                if (error != nil) { error() }
                self.isFetching = false                
        }
    }
    
    func handleResponse(json: JSON) {
        for (key: String, valueJSON: JSON) in json {
            if key == "goals" {
                for (index: String, goalJSON: JSON) in valueJSON {
                    Goal.crupdateWithJSON(goalJSON)
                }
            }
        }
    }
    
    
}