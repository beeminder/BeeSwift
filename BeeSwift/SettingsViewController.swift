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
    
    private var animatingTimePickerView = false
    private var timePickerViewVisible = false

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
        self.dataEntryReminderLabel.userInteractionEnabled = true
        let tapGR = UITapGestureRecognizer()
        tapGR.addTarget(self, action: "dataEntryReminderLabelTapped")
        self.dataEntryReminderLabel.addGestureRecognizer(tapGR)
        self.view.addSubview(self.dataEntryReminderLabel)
        self.dataEntryReminderLabel.snp_makeConstraints { (make) -> Void in
            make.centerY.equalTo(self.dataEntryReminderSwitch)
            make.left.equalTo(self.dataEntryReminderSwitch.snp_right).offset(20)
        }
        
        self.timePickerView.delegate = self
        self.timePickerView.dataSource = self
        self.view.addSubview(self.timePickerView)
        self.timePickerView.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(self.dataEntryReminderLabel.snp_bottom).offset(20)
            make.width.equalTo(self.view)
            make.height.equalTo(100)
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
    
    func dataEntryReminderLabelTapped() {
        self.toggleTimePickerView()
    }
    
    func toggleTimePickerView() {
        if self.animatingTimePickerView {
            return
        }
        self.animatingTimePickerView = true

        UIView.animateWithDuration(0.25, delay: 0.0, options: UIViewAnimationOptions.CurveEaseOut, animations: { () -> Void in
            self.timePickerView.snp_updateConstraints({ (make) -> Void in
                make.height.equalTo(self.timePickerViewVisible ? 0 : 100)
            })
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
            LocalNotificationsManager.sharedManager.turnLocalNotificationsOn()
        }
        else {
            LocalNotificationsManager.sharedManager.turnLocalNotificationsOff()
        }
        self.updateDataEntryReminderLabel()
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
            make.edges.equalTo(view)
        }
        label.font = UIFont(name: "Avenir", size: 17)
        
        var text = ""
        var alignment = NSTextAlignment.Center
        
        if (component == 2) {
            text = row == 0 ? "AM" : "PM"
            alignment = NSTextAlignment.Left
        }
        else if (component == 1) {
            text = row < 10 ? "0\(row)" : "\(row)"
            alignment = NSTextAlignment.Center
        }
        else {
            if (self.use24HourTime() || row <= 12) {
                text = "\(row)"
            }
            else {
                text = "\(row - 12)"
            }
            alignment = NSTextAlignment.Right
        }
        
        label.text = text
        label.textAlignment = alignment
        
        return view
    }

//    func pickerView(pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
//        if component == 0 {
//            return self.view.snp_width*0.4
//        }
//        return 100
//    }
    
    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if component == 0 {
            return 24
        }
        else if component == 1 {
            return 60
        }
        return 2
    }
}