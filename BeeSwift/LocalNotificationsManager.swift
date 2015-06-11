//
//  LocalNotificationsManager.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/29/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation

class LocalNotificationsManager :NSObject {
    
    private var defaultHour = 21
    private var defaultMinute = 0
    
    static let sharedManager = LocalNotificationsManager()
    
    required override init() {
        super.init()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleUserSignoutNotification", name: CurrentUserManager.signedOutNotificationName, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleUserSigninNotification", name: CurrentUserManager.signedInNotificationName, object: nil)
    }
    
    private func hourKey() -> String {
        if CurrentUserManager.sharedManager.signedIn() {
            return "\(CurrentUserManager.sharedManager.username!)-hour"
        }
        return "hour"
    }
    
    private func minuteKey() -> String {
        if CurrentUserManager.sharedManager.signedIn() {
            return "\(CurrentUserManager.sharedManager.username!)-minute"
        }
        return "minute"
    }
    
    private func notificationsOnKey() -> String {
        if CurrentUserManager.sharedManager.signedIn() {
            return "\(CurrentUserManager.sharedManager.username!)-notificationsOn"
        }
        return "notificationsOn"
    }
    
    func handleUserSignoutNotification() {
        self.turnNotificationsOff()
    }
    
    func handleUserSigninNotification() {
        if self.on() {
            self.scheduleNotifications()
        }
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
        return NSUserDefaults.standardUserDefaults().objectForKey(self.notificationsOnKey()) != nil
    }
    
    func turnNotificationsOff() {
        NSUserDefaults.standardUserDefaults().removeObjectForKey(self.notificationsOnKey())
        NSUserDefaults.standardUserDefaults().synchronize()
        UIApplication.sharedApplication().cancelAllLocalNotifications()
    }
    
    func turnNotificationsOn() {
        NSUserDefaults.standardUserDefaults().setBool(true, forKey: self.notificationsOnKey())
        NSUserDefaults.standardUserDefaults().synchronize()
        UIApplication.sharedApplication().cancelAllLocalNotifications()
        UIApplication.sharedApplication().registerUserNotificationSettings(UIUserNotificationSettings(forTypes: .Sound | .Alert | .Badge, categories: nil))
        self.scheduleNotifications()
    }
    
    func setReminder(hour: NSNumber, minute: NSNumber) {
        NSUserDefaults.standardUserDefaults().setObject(hour, forKey: self.hourKey())
        NSUserDefaults.standardUserDefaults().setObject(minute, forKey: self.minuteKey())
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
        let storedHour: AnyObject? = NSUserDefaults.standardUserDefaults().objectForKey(self.hourKey())
        if storedHour != nil {
            return storedHour as! NSNumber
        }
        return self.defaultHour
    }
    
    func reminderTimeMinute() -> NSNumber {
        let storedMinute: AnyObject? = NSUserDefaults.standardUserDefaults().objectForKey(self.minuteKey())
        if storedMinute != nil {
            return storedMinute as! NSNumber
        }
        return self.defaultMinute
    }

}