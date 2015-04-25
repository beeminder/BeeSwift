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

    class var sharedManager :DataSyncManager {
        struct Manager {
            static let sharedManager = DataSyncManager()
        }
        return Manager.sharedManager
    }
    
    func fetchData(success: (()->Void)!, error: (()->Void)!) {
        if self.isFetching {
            return
        }
        
        self.isFetching = true
        
        let manager = AFHTTPRequestOperationManager()
        manager.responseSerializer = AFJSONResponseSerializer()
        
        manager.GET("https://www.beeminder.com/api/v1/users/me.json?auth_token=pHMqRztj3FbqiXZyr2rP&associations=true&datapoints_count=5&diff_since=0", parameters: nil, success: { (operation: AFHTTPRequestOperation!, responseObject: AnyObject!) -> Void in
                self.handleResponse(JSON(responseObject))
                if (success != nil) { success() }
                self.isFetching = false
            }) { (operation: AFHTTPRequestOperation!, responseObject: AnyObject!) -> Void in
                if (error != nil) { error() }
                self.isFetching = false                
        }
    }
    
    func handleResponse(json: JSON) {
        println(json["goals"])

        for (key: String, valueJSON: JSON) in json {
            if key == "goals" {
                for (index: String, goalJSON: JSON) in valueJSON {
                    println(goalJSON["slug"])
                    Goal.crupdateWithJSON(goalJSON)
                }
            }
        }
    }
    
    
}