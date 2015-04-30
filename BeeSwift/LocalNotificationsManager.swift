//
//  LocalNotificationsManager.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/29/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation

class LocalNotificationsManager {
    
    private var hourKey = "hour"
    private var minuteKey = "minute"
    
    class var sharedManager :LocalNotificationsManager {
        struct Manager {
            static let sharedManager = LocalNotificationsManager()
        }
        return Manager.sharedManager
    }
    
    func turnLocalNotificationsOff() {
        UIApplication.sharedApplication().cancelAllLocalNotifications()
    }
    
    func turnLocalNotificationsOn() {
        UIApplication.sharedApplication().cancelAllLocalNotifications()
    }
    
    func reminderTimeHour() -> NSNumber? {
        return NSUserDefaults.standardUserDefaults().objectForKey(hourKey) as? NSNumber
    }
    
    func setReminderTimeHour() {
        UIApplication.sharedApplication().cancelAllLocalNotifications()
    }
    
    func reminderTimeMinute() -> NSNumber? {
        return NSUserDefaults.standardUserDefaults().objectForKey(minuteKey) as? NSNumber
    }

}