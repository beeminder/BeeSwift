//
//  SettingsViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/27/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation

class SettingsViewController: UIViewController {
    
    var dataEntryReminderLabel = BSLabel()
    var dataEntryReminderSwitch = UISwitch()

    override func viewDidLoad() {
        self.title = "Settings"
        self.view.backgroundColor = UIColor.whiteColor()
        
        self.dataEntryReminderSwitch.addTarget(self, action: "dataEntryReminderSwitchChanged", forControlEvents: UIControlEvents.ValueChanged)
        self.view.addSubview(self.dataEntryReminderSwitch)
        self.dataEntryReminderSwitch.snp_makeConstraints { (make) -> Void in
            let topLayoutGuide = self.topLayoutGuide as! UIView
            make.left.equalTo(20)
            make.top.equalTo(topLayoutGuide.snp_bottom).offset(20)
        }
        
        self.dataEntryReminderLabel.font = UIFont(name: "Avenir", size: 16)
        self.dataEntryReminderLabel.text = "Data entry reminder: off"
        self.view.addSubview(self.dataEntryReminderLabel)
        self.dataEntryReminderLabel.snp_makeConstraints { (make) -> Void in
            make.centerY.equalTo(self.dataEntryReminderSwitch)
            make.left.equalTo(self.dataEntryReminderSwitch.snp_right).offset(20)
        }
        
        var signOutButton = BSButton()
        
        signOutButton.addTarget(self, action: "signOutButtonPressed", forControlEvents: UIControlEvents.TouchUpInside)
        self.view.addSubview(signOutButton)
        signOutButton.setTitle("Sign Out", forState: UIControlState.Normal)
        signOutButton.snp_makeConstraints { (make) -> Void in
            make.bottom.equalTo(-30)
            make.width.equalTo(self.view).multipliedBy(0.75)
            make.centerX.equalTo(self.view)
        }
    }
    
    func signOutButtonPressed() {
        CurrentUserManager.sharedManager.signOut()
        self.navigationController?.popViewControllerAnimated(true)
    }
    
    func dataEntryReminderSwitchChanged() {
        if self.dataEntryReminderSwitch.on {
            LocalNotificationsManager.sharedManager.turnLocalNotificationsOn()
        }
        else {
            LocalNotificationsManager.sharedManager.turnLocalNotificationsOff()
        }
    }
}