//
//  SettingsViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/27/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation

class SettingsViewController: UIViewController {
    
    private var numberOfTodayGoalsLabel = BSLabel()
    private var numberOfTodayGoalsStepper = UIStepper()
    private var emergencyRemindersSwitch = UISwitch()
    private var tableView = UITableView()
    private var frontburnerGoals : [Goal] = []
    private var backburnerGoals  : [Goal] = []
    private var cellReuseIdentifier = "goalNotificationSettingsTableViewCell"

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
        
        self.numberOfTodayGoalsLabel.text = "Goals in Today view: \(numberOfTodayGoals!)"
        self.numberOfTodayGoalsLabel.snp_makeConstraints { (make) -> Void in
            make.left.equalTo(15)
            make.width.lessThanOrEqualTo(self.view).multipliedBy(0.7).offset(-20)
            make.top.equalTo(self.snp_topLayoutGuideBottom).offset(20)
        }
        
        self.view.addSubview(self.numberOfTodayGoalsStepper)
        self.numberOfTodayGoalsStepper.tintColor = UIColor.darkGrayColor()
        self.numberOfTodayGoalsStepper.maximumValue = 3
        self.numberOfTodayGoalsStepper.snp_makeConstraints { (make) -> Void in
            make.centerY.equalTo(self.numberOfTodayGoalsLabel)
            make.right.equalTo(-15)
        }
        self.numberOfTodayGoalsStepper.addTarget(self, action: "numberOfTodayGoalsStepperValueChanged", forControlEvents: .ValueChanged)
        self.numberOfTodayGoalsStepper.value = Double(numberOfTodayGoals!)
        
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
        
        self.view.addSubview(self.tableView)
        self.tableView.snp_makeConstraints { (make) -> Void in
            make.left.equalTo(0)
            make.right.equalTo(0)
            make.top.equalTo(emergencyRemindersSwitch.snp_bottom).offset(5)
            make.bottom.equalTo(signOutButton.snp_top)
        }
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.tableFooterView = UIView()
        self.tableView.backgroundColor = UIColor.clearColor()
        self.tableView.registerClass(GoalNotificationSettingsTableViewCell.self, forCellReuseIdentifier: self.cellReuseIdentifier)
        self.loadGoalsFromDatabase()
    }
    
    func userDefaultsDidChange() {
        self.updateEmergencyRemindersSwitch()
        self.numberOfTodayGoalsLabel.text = "Goals in Today view: \(Int(self.numberOfTodayGoalsStepper.value))"
    }
    
    func updateEmergencyRemindersSwitch() {
        self.emergencyRemindersSwitch.on = RemoteNotificationsManager.sharedManager.on()
        self.tableView.hidden = !self.emergencyRemindersSwitch.on        
    }
    
    func numberOfTodayGoalsStepperValueChanged() {
        NSUserDefaults.standardUserDefaults().setObject(Int(self.numberOfTodayGoalsStepper.value), forKey: "numberOfTodayGoals")
        NSUserDefaults.standardUserDefaults().synchronize()
    }
    
    func signOutButtonPressed() {
        CurrentUserManager.sharedManager.signOut()
        self.navigationController?.popViewControllerAnimated(true)
    }
    
    func emergencyRemindersSwitchChanged() {
        self.tableView.hidden = !self.emergencyRemindersSwitch.on
        if self.emergencyRemindersSwitch.on {
            RemoteNotificationsManager.sharedManager.turnNotificationsOn()
        }
        else {
            RemoteNotificationsManager.sharedManager.turnNotificationsOff()
        }
    }
    
    func loadGoalsFromDatabase() {
        self.frontburnerGoals = Goal.MR_findAllWithPredicate(NSPredicate(format: "burner = %@ and serverDeleted = false", "frontburner")) as! [Goal]
        self.frontburnerGoals = self.frontburnerGoals.sort { ($0.losedate.integerValue < $1.losedate.integerValue) }
        self.backburnerGoals  = Goal.MR_findAllWithPredicate(NSPredicate(format: "burner = %@ and serverDeleted = false", "backburner")) as! [Goal]
        self.backburnerGoals = self.backburnerGoals.sort { ($0.losedate.integerValue < $1.losedate.integerValue) }
    }
}

extension SettingsViewController : UITableViewDataSource, UITableViewDelegate {
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 1 { return self.frontburnerGoals.count }
        if section == 2 { return self.backburnerGoals.count  }
        return 1
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(self.cellReuseIdentifier) as! GoalNotificationSettingsTableViewCell!
        if indexPath.section == 0 {
            cell.title = "Default notification settings"
            return cell
        }
        let goal = indexPath.section == 1 ? self.frontburnerGoals[indexPath.row] : self.backburnerGoals[indexPath.row]
        cell.title = goal.slug
        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if indexPath.section == 0 {
            self.navigationController?.pushViewController(EditDefaultNotificationsViewController(), animated: true)
        } else {
            let goal = indexPath.section == 1 ? self.frontburnerGoals[indexPath.row] : self.backburnerGoals[indexPath.row]
            self.navigationController?.pushViewController(EditGoalNotificationsViewController(goal: goal), animated: true)
        }
    }
}