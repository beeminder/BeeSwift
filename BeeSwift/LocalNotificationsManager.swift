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
    private var notificationsOnKey = "notificationsOn"
    
    private var defaultHour = 21
    private var defaultMinute = 0
    
    class var sharedManager :LocalNotificationsManager {
        struct Manager {
            static let sharedManager = LocalNotificationsManager()
        }
        return Manager.sharedManager
    }
    
    func humanizedReminderTime() -> String {
        let components = NSDateComponents()
        components.hour = LocalNotificationsManager.sharedManager.reminderTimeHour().integerValue
        components.minute = LocalNotificationsManager.sharedManager.reminderTimeMinute().integerValue

        let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)
        let date = calendar?.dateFromComponents(components)
        
        return NSDateFormatter.localizedStringFromDate(date!, dateStyle: NSDateFormatterStyle.NoStyle, timeStyle: NSDateFormatterStyle.ShortStyle)
    }
    
    func on() -> Bool {
        if NSUserDefaults.standardUserDefaults().objectForKey(notificationsOnKey) == nil {
            return Bool(false)
        }
        return Bool(true)
    }
    
    func turnLocalNotificationsOff() {
        NSUserDefaults.standardUserDefaults().removeObjectForKey(notificationsOnKey)
        NSUserDefaults.standardUserDefaults().synchronize()
        UIApplication.sharedApplication().cancelAllLocalNotifications()
    }
    
    func turnLocalNotificationsOn() {
        NSUserDefaults.standardUserDefaults().setBool(true, forKey: notificationsOnKey)
        NSUserDefaults.standardUserDefaults().synchronize()
        UIApplication.sharedApplication().cancelAllLocalNotifications()
        UIApplication.sharedApplication().registerUserNotificationSettings(UIUserNotificationSettings(forTypes: UIUserNotificationType.Sound | UIUserNotificationType.Alert | UIUserNotificationType.Badge, categories: nil))
    }
    
    func setReminder(hour: NSNumber, minute: NSNumber) {
        UIApplication.sharedApplication().cancelAllLocalNotifications()
        var notification = UILocalNotification()
        notification.alertBody = "Don't forget to enter your Beeminder data for today!"
        notification.repeatInterval = NSCalendarUnit.DayCalendarUnit
        
    }
    
    func reminderTimeHour() -> NSNumber {
        let storedHour: AnyObject? = NSUserDefaults.standardUserDefaults().objectForKey(hourKey)
        if storedHour != nil {
            return storedHour as! NSNumber
        }
        return self.defaultHour
    }
    
    func reminderTimeMinute() -> NSNumber {
        let storedMinute: AnyObject? = NSUserDefaults.standardUserDefaults().objectForKey(minuteKey)
        if storedMinute != nil {
            return storedMinute as! NSNumber
        }
        return self.defaultMinute
    }

}