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
    fileprivate let lastSyncedKey = "lastSynced"

    static let sharedManager = DataSyncManager()

    required override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(DataSyncManager.handleUserSignoutNotification), name: NSNotification.Name(rawValue: CurrentUserManager.signedOutNotificationName), object: nil)
    }
    
    @objc func handleUserSignoutNotification() {
        self.setLastSynced(nil)
    }
    
    var lastSynced :Date? {
        return UserDefaults.standard.object(forKey: lastSyncedKey) as! Date?
    }
    
    func setLastSynced(_ date: Date?) {
        if date == nil {
            UserDefaults.standard.removeObject(forKey: lastSyncedKey)
        }
        else {
            UserDefaults.standard.set(date, forKey: lastSyncedKey)
        }
        UserDefaults.standard.synchronize()
    }
    
    func fetchData(_ success: (()->Void)!, error: (()->Void)!) {
        if self.isFetching || !CurrentUserManager.sharedManager.signedIn() {
            return
        }
        
        self.isFetching = true
        
        BSHTTPSessionManager.sharedManager.get("/api/v1/users/me.json", parameters: ["associations": true, "datapoints_count": 5, "diff_since": self.lastSynced == nil ? 0 : self.lastSynced!.timeIntervalSince1970] as AnyObject, success: { (dataTask, responseObject) -> Void in
            self.handleResponse(JSON(responseObject!), completion: success)
            self.isFetching = false
            self.setLastSynced(Date())
        }) { (dataTask, responseError) -> Void in
            if (error != nil) { error() }
            self.isFetching = false
        }
    }
    
    func handleResponse(_ json: JSON, completion: (()->Void)!) {
        CurrentUserManager.sharedManager.setDeadbeat(json["deadbeat"].boolValue)
        let goals = json["goals"].array!
        for goalJSON in goals {
            Goal.crupdateWithJSON(goalJSON)
        }
        guard let deletedGoals = json["deleted_goals"].array else { return }
        for goalJSON in deletedGoals {
            if let goal = Goal.mr_findFirst(byAttribute: "id", withValue: goalJSON["id"].string!) as Goal? {
                for datapoint in goal.datapoints {
                    (datapoint as AnyObject).mr_deleteEntity()
                }
                goal.serverDeleted = true
            }
        }
        NSManagedObjectContext.mr_default().mr_saveToPersistentStore { (success, error) -> Void in
            let delegate = UIApplication.shared.delegate as! AppDelegate
            delegate.updateBadgeCount()
            delegate.updateTodayWidget()
            if completion != nil && error == nil { completion() }
        }
    }
    
    
}
