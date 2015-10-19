//
//  SettingsViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/27/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation

class SettingsViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {
    
    private var numberOfTodayGoalsLabel = BSLabel()
    private var numberOfTodayGoalsStepper = UIStepper()
    private var timePickerView = UIPickerView()
    private var timePickerContainerView = UIView()
    private var animatingTimePickerView = false
    private var timePickerViewVisible = false
    private var emergencyRemindersSwitch = UISwitch()

    override func viewDidLoad() {
        self.title = "Settings"
        self.view.backgroundColor = UIColor.whiteColor()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "userDefaultsDidChange", name: NSUserDefaultsDidChangeNotification, object: nil)
        
        self.view.addSubview(self.numberOfTodayGoalsLabel)
        var numberOfTodayGoals = NSUserDefaults.standardUserDefaults().objectForKey("numberOfTodayGoals")?.integerValue
        if numberOfTodayGoals == nil {
            numberOfTodayGoals = 3
            NSUserDefaults.standardUserDefaults().setObject(3, forKey: "numberOfTodayGoals")
            NSUserDefaults.standardUserDefaults().synchronize()
        }
        
        self.numberOfTodayGoalsLabel.text = "Number of Goals in Today view: \(numberOfTodayGoals!)"
        self.numberOfTodayGoalsLabel.adjustsFontSizeToFitWidth = true
        self.numberOfTodayGoalsLabel.minimumScaleFactor = 0.8
        self.numberOfTodayGoalsLabel.snp_makeConstraints { (make) -> Void in
            make.left.equalTo(20)
            make.width.lessThanOrEqualTo(self.view).multipliedBy(0.7).offset(-20)
            make.top.equalTo(self.snp_topLayoutGuideBottom).offset(20)
        }
        
        self.view.addSubview(self.numberOfTodayGoalsStepper)
        self.numberOfTodayGoalsStepper.tintColor = UIColor.darkGrayColor()
        self.numberOfTodayGoalsStepper.maximumValue = 3
        self.numberOfTodayGoalsStepper.snp_makeConstraints { (make) -> Void in
            make.centerY.equalTo(self.numberOfTodayGoalsLabel)
            make.left.equalTo(self.numberOfTodayGoalsLabel.snp_right).offset(10)
        }
        self.numberOfTodayGoalsStepper.addTarget(self, action: "numberOfTodayGoalsStepperValueChanged", forControlEvents: .ValueChanged)
        self.numberOfTodayGoalsStepper.value = Double(numberOfTodayGoals!)
        
        self.timePickerContainerView.clipsToBounds = true
        self.view.addSubview(self.timePickerContainerView)
        self.timePickerContainerView.alpha = 0
        self.timePickerContainerView.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(self.numberOfTodayGoalsLabel.snp_bottom)
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
        self.updateEmergencyRemindersSwitch()
        self.emergencyRemindersSwitch.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(self.numberOfTodayGoalsStepper.snp_bottom).offset(20)
            make.right.equalTo(self.numberOfTodayGoalsStepper)
        }
        
        let emergencyRemindersLabel = BSLabel()
        self.view.addSubview(emergencyRemindersLabel)
        emergencyRemindersLabel.text = "Goal emergency notifications"
        emergencyRemindersLabel.font = self.numberOfTodayGoalsLabel.font!
        emergencyRemindersLabel.snp_makeConstraints { (make) -> Void in
            make.centerY.equalTo(self.emergencyRemindersSwitch)
            make.left.equalTo(self.numberOfTodayGoalsLabel)
        }
        
        let signOutButton = BSButton()
        
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
    }
    
    func userDefaultsDidChange() {
        self.updateEmergencyRemindersSwitch()
        self.numberOfTodayGoalsLabel.text = "Number of Goals in Today view: \(Int(self.numberOfTodayGoalsStepper.value))"
    }
    
    func updateEmergencyRemindersSwitch() {
        self.emergencyRemindersSwitch.on = RemoteNotificationsManager.sharedManager.on()
    }
    
    func numberOfTodayGoalsStepperValueChanged() {
        NSUserDefaults.standardUserDefaults().setObject(Int(self.numberOfTodayGoalsStepper.value), forKey: "numberOfTodayGoals")
        NSUserDefaults.standardUserDefaults().synchronize()
    }
    
    func setTimePickerViewValues() {
        if self.use24HourTime() {

        }
        else {

        }
    }
    
    func pickerContainerViewHeight() -> CGFloat {
        return UIPickerView().frame.size.height
    }
    
    func toggleTimePickerView() {
        if self.animatingTimePickerView {
            return
        }
        self.animatingTimePickerView = true
        
        UIView.animateWithDuration(0.25, delay: 0.0, options: UIViewAnimationOptions.CurveEaseOut, animations: { () -> Void in
            self.timePickerContainerView.alpha = self.timePickerViewVisible ? 0 : 1
            self.timePickerContainerView.snp_updateConstraints(closure: { (make) -> Void in
                make.height.equalTo(self.timePickerViewVisible ? 0 : self.pickerContainerViewHeight())
            })
            self.view.layoutIfNeeded()
        }) { (flag) -> Void in
            self.animatingTimePickerView = false
            self.timePickerViewVisible = !self.timePickerViewVisible
        }
    }
    
    func signOutButtonPressed() {
        CurrentUserManager.sharedManager.signOut()
        self.navigationController?.popViewControllerAnimated(true)
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
    
    func pickerView(pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusingView view: UIView?) -> UIView {
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
}