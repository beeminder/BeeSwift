//
//  SettingsViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/27/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation

class SettingsViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {
    
    private var dataEntryReminderLabel = BSLabel()
    private var dataEntryReminderSwitch = UISwitch()
    private var timePickerView = UIPickerView()
    private var timePickerContainerView = UIView()
    private var animatingTimePickerView = false
    private var timePickerViewVisible = false
    private var emergencyRemindersSwitch = UISwitch()

    override func viewDidLoad() {
        self.title = "Settings"
        self.view.backgroundColor = UIColor.whiteColor()
        
        self.dataEntryReminderSwitch.addTarget(self, action: "dataEntryReminderSwitchChanged", forControlEvents: .ValueChanged)
        self.view.addSubview(self.dataEntryReminderSwitch)
        self.dataEntryReminderSwitch.on = LocalNotificationsManager.sharedManager.on()
        self.dataEntryReminderSwitch.snp_makeConstraints { (make) -> Void in
            let topLayoutGuide = self.topLayoutGuide as! UIView
            make.left.equalTo(20)
            make.top.equalTo(topLayoutGuide.snp_bottom).offset(20)
        }
        
        self.dataEntryReminderLabel.font = UIFont(name: "Avenir", size: 16)
        self.dataEntryReminderLabel.text = "Data entry reminder: off"
        self.dataEntryReminderLabel.userInteractionEnabled = true
        let tapGR = UITapGestureRecognizer()
        tapGR.addTarget(self, action: "dataEntryReminderLabelTapped")
        self.dataEntryReminderLabel.addGestureRecognizer(tapGR)
        self.view.addSubview(self.dataEntryReminderLabel)
        self.dataEntryReminderLabel.snp_makeConstraints { (make) -> Void in
            make.centerY.equalTo(self.dataEntryReminderSwitch)
            make.left.equalTo(self.dataEntryReminderSwitch.snp_right).offset(20)
        }
        
        self.timePickerContainerView.clipsToBounds = true
        self.view.addSubview(self.timePickerContainerView)
        self.timePickerContainerView.alpha = 0
        self.timePickerContainerView.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(self.dataEntryReminderLabel.snp_bottom)
            make.width.equalTo(self.view)
            make.height.equalTo(0)
        }
        
        self.timePickerView.delegate = self
        self.timePickerView.dataSource = self
        self.timePickerContainerView.addSubview(self.timePickerView)
        self.timePickerView.snp_makeConstraints { (make) -> Void in
            make.center.equalTo(self.timePickerContainerView)
        }
        
        self.view.addSubview(self.emergencyRemindersSwitch)
        self.emergencyRemindersSwitch.addTarget(self, action: "emergencyRemindersSwitchChanged", forControlEvents: .ValueChanged)
        self.emergencyRemindersSwitch.on = RemoteNotificationsManager.sharedManager.on()
        self.emergencyRemindersSwitch.snp_makeConstraints { (make) -> Void in
            make.centerX.equalTo(self.dataEntryReminderSwitch)
            make.top.equalTo(self.timePickerContainerView.snp_bottom).offset(20)
        }
        
        let emergencyRemindersLabel = BSLabel()
        self.view.addSubview(emergencyRemindersLabel)
        emergencyRemindersLabel.text = "Goal emergency notifications"
        emergencyRemindersLabel.font = self.dataEntryReminderLabel.font!
        emergencyRemindersLabel.snp_makeConstraints { (make) -> Void in
            make.centerY.equalTo(self.emergencyRemindersSwitch)
            make.left.equalTo(self.dataEntryReminderLabel)
        }
        
        var signOutButton = BSButton()
        
        signOutButton.addTarget(self, action: "signOutButtonPressed", forControlEvents: UIControlEvents.TouchUpInside)
        self.view.addSubview(signOutButton)
        signOutButton.setTitle("Sign Out", forState: UIControlState.Normal)
        signOutButton.snp_makeConstraints { (make) -> Void in
            make.bottom.equalTo(-30)
            make.width.equalTo(self.view).multipliedBy(0.75)
            make.centerX.equalTo(self.view)
            make.height.equalTo(44)
        }
        
        self.setTimePickerViewValues()
        self.updateDataEntryReminderLabel()
    }
    
    func setTimePickerViewValues() {
        if self.use24HourTime() {
            self.timePickerView.selectRow(LocalNotificationsManager.sharedManager.reminderTimeHour().integerValue, inComponent: 0, animated: false)
            self.timePickerView.selectRow(LocalNotificationsManager.sharedManager.reminderTimeMinute().integerValue, inComponent: 1, animated: false)
        }
        else {
            let hour = LocalNotificationsManager.sharedManager.reminderTimeHour().integerValue
            let minute = LocalNotificationsManager.sharedManager.reminderTimeMinute().integerValue
            if hour > 12 {
                self.timePickerView.selectRow(1, inComponent: 2, animated: false)
                self.timePickerView.selectRow(hour - 12, inComponent: 0, animated: false)
            }
            else {
                self.timePickerView.selectRow(hour, inComponent: 0, animated: false)
            }
            self.timePickerView.selectRow(minute, inComponent: 1, animated: false)
        }
    }
    
    func pickerContainerViewHeight() -> CGFloat {
        return UIPickerView().frame.size.height
    }
    
    func dataEntryReminderLabelTapped() {
        if self.timePickerViewVisible {
            self.hideTimePickerView()
        } else {
            self.showTimePickerView()
        }
        self.updateDataEntryReminderLabel()
    }
    
    func hideTimePickerView() {
        if self.timePickerViewVisible {
            self.toggleTimePickerView()
        }
    }
    
    func showTimePickerView() {
        if !self.timePickerViewVisible {
            self.dataEntryReminderSwitch.on = true
            LocalNotificationsManager.sharedManager.turnNotificationsOn()
            self.toggleTimePickerView()
        }
    }
    
    func toggleTimePickerView() {
        if self.animatingTimePickerView {
            return
        }
        self.animatingTimePickerView = true
        
        UIView.animateWithDuration(0.25, delay: 0.0, options: UIViewAnimationOptions.CurveEaseOut, animations: { () -> Void in
            self.timePickerContainerView.alpha = self.timePickerViewVisible ? 0 : 1
            self.timePickerContainerView.snp_updateConstraints({ (make) -> Void in
                make.height.equalTo(self.timePickerViewVisible ? 0 : self.pickerContainerViewHeight())
            })
            self.view.layoutIfNeeded()
        }) { (flag) -> Void in
            self.animatingTimePickerView = false
            self.timePickerViewVisible = !self.timePickerViewVisible
        }
    }
    
    func updateDataEntryReminderLabel() {
        if LocalNotificationsManager.sharedManager.on() {
            self.dataEntryReminderLabel.text = "Data entry reminder: \(LocalNotificationsManager.sharedManager.humanizedReminderTime())"
        }
        else {
            self.dataEntryReminderLabel.text = "Data entry reminder: off"
        }
    }
    
    func signOutButtonPressed() {
        CurrentUserManager.sharedManager.signOut()
        self.navigationController?.popViewControllerAnimated(true)
    }
    
    func dataEntryReminderSwitchChanged() {
        if self.dataEntryReminderSwitch.on {
            self.showTimePickerView()
            LocalNotificationsManager.sharedManager.turnNotificationsOn()
        }
        else {
            self.hideTimePickerView()
            LocalNotificationsManager.sharedManager.turnNotificationsOff()
        }
        self.updateDataEntryReminderLabel()
    }
    
    func emergencyRemindersSwitchChanged() {
        if self.emergencyRemindersSwitch.on {
            RemoteNotificationsManager.sharedManager.turnNotificationsOn()
        }
        else {
            RemoteNotificationsManager.sharedManager.turnNotificationsOff()
        }
    }
    
    func use24HourTime() -> Bool {
        let formatString: NSString = NSDateFormatter.dateFormatFromTemplate("j", options: 0, locale: NSLocale.currentLocale())!
        return !formatString.containsString("a")
    }
    
    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return self.use24HourTime() ? 2 : 3
    }
    
    func pickerView(pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusingView view: UIView!) -> UIView {
        let view = UIView()
        let label = BSLabel()
        view.addSubview(label)
        label.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(0)
            make.bottom.equalTo(0)
            make.left.equalTo(10)
            make.right.equalTo(-10)
        }
        label.font = UIFont(name: "Avenir", size: 17)
        
        var text = ""
        var alignment = NSTextAlignment.Center
        
        if (component == 2) {
            text = row == 0 ? "AM" : "PM"
            alignment = .Left
        }
        else if (component == 1) {
            text = row < 10 ? "0\(row)" : "\(row)"
            if self.use24HourTime() {
                alignment = .Left
            } else {
                alignment = .Center
            }
        }
        else {
            if (!self.use24HourTime() && row == 0) {
                text = "12"
            }
            else {
                text = "\(row)"
            }
            alignment = .Right
        }
        
        label.text = text
        label.textAlignment = alignment
        
        return view
    }
    
    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if component == 0 {
            return Bool(self.use24HourTime()) ? 24 : 12
        }
        else if component == 1 {
            return 60
        }
        return 2
    }
    
    func reminderHourFromTimePicker() -> NSNumber {
        if self.use24HourTime() || self.timePickerView.selectedRowInComponent(2) == 0 {
            return self.timePickerView.selectedRowInComponent(0)
        }
        return self.timePickerView.selectedRowInComponent(0) + 12
    }
    
    func reminderMinuteFromTimePicker() -> NSNumber {
        return self.timePickerView.selectedRowInComponent(1)
    }
    
    func pickerView(pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        LocalNotificationsManager.sharedManager.setReminder(self.reminderHourFromTimePicker(), minute: self.reminderMinuteFromTimePicker())
        self.updateDataEntryReminderLabel()
    }
}