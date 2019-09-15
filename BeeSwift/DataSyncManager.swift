//
//  DataSyncManager.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/19/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

//import Foundation
//import SwiftyJSON
//import MagicalRecord
//
//class DataSyncManager :NSObject {
//    fileprivate let lastSyncedKey = "lastSynced"
//
//    static let sharedManager = DataSyncManager()
//
//    required override init() {
//        super.init()
//        NotificationCenter.default.addObserver(self, selector: #selector(DataSyncManager.handleUserSignoutNotification), name: NSNotification.Name(rawValue: CurrentUserManager.signedOutNotificationName), object: nil)
//    }
//    
//    @objc func handleUserSignoutNotification() {
//        self.setLastSynced(nil)
//    }
//    
//    var lastSynced :Date? {
//        return UserDefaults.standard.object(forKey: lastSyncedKey) as! Date?
//    }
//    
//    func setLastSynced(_ date: Date?) {
//        if date == nil {
//            UserDefaults.standard.removeObject(forKey: lastSyncedKey)
//        }
//        else {
//            UserDefaults.standard.set(date, forKey: lastSyncedKey)
//        }
//        UserDefaults.standard.synchronize()
//    }
//    
//    func handleFetchDataSuccess(responseJSON: Any?) {
//        
//    }
//    
//    func fetchData(success: (()->Void)?, error: (()->Void)?) {
//        if !CurrentUserManager.sharedManager.signedIn() {
//            return
//        }
//        
//        let parameters = ["associations": true, "datapoints_count": 5, "diff_since": self.lastSynced == nil ? 0 : self.lastSynced!.timeIntervalSince1970] as [String : Any]
//        RequestManager.get(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!).json", parameters: parameters, success: { (responseJSON) in
//            success?()
//            self.handleResponse(JSON(responseJSON!), completion: nil)
//            self.setLastSynced(Date())
//        }) { (responseError) in
//            error?()
//            NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: "dataSyncManagerError")))
//        }
//    }
//    
//    func handleResponse(_ json: JSON, completion: (()->Void)?) {
////        CurrentUserManager.sharedManager.setDeadbeat(json["deadbeat"].boolValue)
////        let goals = json["goals"].array!
////        for goalJSON in goals {
////            Goal.crupdateWithJSON(goalJSON)
////        }
////        guard let deletedGoals = json["deleted_goals"].array else { return }
////        var deletedAGoal = false
////        for goalJSON in deletedGoals {
////            if let goal = Goal.mr_findFirst(byAttribute: "id", withValue: goalJSON["id"].string!) as Goal? {
////                for datapoint in goal.datapoints {
////                    (datapoint as AnyObject).mr_deleteEntity()
////                }
////                goal.serverDeleted = true
////                deletedAGoal = true
////            }
////        }
////        if deletedAGoal { CurrentUserManager.sharedManager.reset() }
////        NSManagedObjectContext.mr_default().mr_saveToPersistentStore { (success, error) -> Void in
////            if error == nil {
////                completion?()
////                NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: "dataSyncManagerSuccess")))
////            } else {
////                NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: "dataSyncManagerError")))
////            }
////        }
//    }
//    
//    
//}
