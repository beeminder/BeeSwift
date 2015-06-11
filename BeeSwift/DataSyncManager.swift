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

class DataSyncManager :NSObject {

    var isFetching = false
    private let lastSyncedKey = "lastSynced"

    static let sharedManager = DataSyncManager()

    required override init() {
        super.init()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleUserSignoutNotification", name: CurrentUserManager.signedOutNotificationName, object: nil)
    }
    
    func handleUserSignoutNotification() {
        self.setLastSynced(nil)
    }
    
    var lastSynced :NSDate? {
        return NSUserDefaults.standardUserDefaults().objectForKey(lastSyncedKey) as! NSDate?
    }
    
    func setLastSynced(date: NSDate?) {
        if date == nil {
            NSUserDefaults.standardUserDefaults().removeObjectForKey(lastSyncedKey)
        }
        else {
            NSUserDefaults.standardUserDefaults().setObject(date, forKey: lastSyncedKey)
        }
        NSUserDefaults.standardUserDefaults().synchronize()
    }
    
    func fetchData(success: (()->Void)!, error: (()->Void)!) {
        if self.isFetching || !CurrentUserManager.sharedManager.signedIn() {
            return
        }
        
        self.isFetching = true
        
        BSHTTPSessionManager.sharedManager.GET("/api/v1/users/me.json", parameters: ["associations": true, "datapoints_count": 5, "diff_since": 0], success: { (dataTask, responseObject) -> Void in
            self.handleResponse(JSON(responseObject), completion: success)
            self.isFetching = false
            self.setLastSynced(NSDate())
        }) { (dataTask, responseError) -> Void in
            if (error != nil) { error() }
            self.isFetching = false
        }
    }
    
    func handleResponse(json: JSON, completion: (()->Void)!) {
        CurrentUserManager.sharedManager.setDeatbeat(json["deadbeat"].boolValue)
        var goals = json["goals"].array!
        for goalJSON in goals {
            Goal.crupdateWithJSON(goalJSON)
        }
        var deletedGoals = json["deleted_goals"].array!
        for goalJSON in deletedGoals {
            if let goal = Goal.MR_findFirstByAttribute("id", withValue: goalJSON["id"].string!) as! Goal? {
                for datapoint in goal.datapoints {
                    datapoint.MR_deleteEntity()
                }
                goal.serverDeleted = true
            }
        }
        NSManagedObjectContext.MR_defaultContext().MR_saveToPersistentStoreWithCompletion { (success: Bool, error: NSError!) -> Void in
            if completion != nil && error == nil { completion() }
        }
    }
    
    
}