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
    
    func turnNotificationsOff() {
        NSUserDefaults.standardUserDefaults().removeObjectForKey(notificationsOnKey)
        NSUserDefaults.standardUserDefaults().synchronize()
        UIApplication.sharedApplication().cancelAllLocalNotifications()
    }
    
    func turnNotificationsOn() {
        NSUserDefaults.standardUserDefaults().setBool(true, forKey: notificationsOnKey)
        NSUserDefaults.standardUserDefaults().synchronize()
        UIApplication.sharedApplication().cancelAllLocalNotifications()
        UIApplication.sharedApplication().registerUserNotificationSettings(UIUserNotificationSettings(forTypes: UIUserNotificationType.Sound | UIUserNotificationType.Alert | UIUserNotificationType.Badge, categories: nil))
        self.scheduleNotifications()
    }
    
    func setReminder(hour: NSNumber, minute: NSNumber) {
        NSUserDefaults.standardUserDefaults().setObject(hour, forKey: hourKey)
        NSUserDefaults.standardUserDefaults().setObject(minute, forKey: minuteKey)
        NSUserDefaults.standardUserDefaults().synchronize()
        self.scheduleNotifications()
    }
    
    func scheduleNotifications() {
        UIApplication.sharedApplication().cancelAllLocalNotifications()
        var notification = UILocalNotification()
        notification.alertBody = "Don't forget to enter your Beeminder data for today!"
        notification.repeatInterval = .CalendarUnitDay
        notification.soundName = UILocalNotificationDefaultSoundName
        
        let calendar = NSCalendar(identifier: NSCalendarIdentifierGregorian)
        let components = calendar?.components(.CalendarUnitYear | .CalendarUnitMonth | .CalendarUnitDay, fromDate: NSDate())
        components!.hour = self.reminderTimeHour().integerValue
        components!.minute = self.reminderTimeMinute().integerValue
        let date = calendar!.dateFromComponents(components!)
        notification.fireDate = date
        
        UIApplication.sharedApplication().scheduleLocalNotification(notification)
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