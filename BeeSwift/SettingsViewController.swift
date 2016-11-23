//
//  SettingsViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/27/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation
import MBProgressHUD

class SettingsViewController: UIViewController {
    
    fileprivate var numberOfTodayGoalsLabel = BSLabel()
    fileprivate var numberOfTodayGoalsStepper = UIStepper()
    fileprivate var emergencyRemindersSwitch = UISwitch()
    fileprivate var tableView = UITableView()
    fileprivate var frontburnerGoals : [Goal] = []
    fileprivate var backburnerGoals  : [Goal] = []
    fileprivate var cellReuseIdentifier = "goalNotificationSettingsTableViewCell"

    override func viewDidLoad() {
        self.title = "Settings"
        self.view.backgroundColor = UIColor.white
        
        NotificationCenter.default.addObserver(self, selector: #selector(SettingsViewController.userDefaultsDidChange), name: UserDefaults.didChangeNotification, object: nil)
        
        self.view.addSubview(self.numberOfTodayGoalsLabel)
        var numberOfTodayGoals :Int? = (UserDefaults.standard.object(forKey: "numberOfTodayGoals") as? NSNumber)?.intValue
            
        if numberOfTodayGoals == nil {
            numberOfTodayGoals = 3
            UserDefaults.standard.set(3, forKey: "numberOfTodayGoals")
            UserDefaults.standard.synchronize()
        }
        
        self.numberOfTodayGoalsLabel.text = "Goals in Today view: \(numberOfTodayGoals!)"
        self.numberOfTodayGoalsLabel.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(15)
            make.width.lessThanOrEqualTo(self.view).multipliedBy(0.7).offset(-20)
            make.top.equalTo(self.topLayoutGuide.snp.bottom).offset(10)
        }
        
        self.view.addSubview(self.numberOfTodayGoalsStepper)
        self.numberOfTodayGoalsStepper.tintColor = UIColor.darkGray
        self.numberOfTodayGoalsStepper.maximumValue = 3
        self.numberOfTodayGoalsStepper.snp.makeConstraints { (make) -> Void in
            make.centerY.equalTo(self.numberOfTodayGoalsLabel)
            make.right.equalTo(-15)
        }
        self.numberOfTodayGoalsStepper.addTarget(self, action: #selector(SettingsViewController.numberOfTodayGoalsStepperValueChanged), for: .valueChanged)
        self.numberOfTodayGoalsStepper.value = Double(numberOfTodayGoals!)
        
        self.view.addSubview(self.emergencyRemindersSwitch)
        self.emergencyRemindersSwitch.addTarget(self, action: #selector(SettingsViewController.emergencyRemindersSwitchChanged), for: .valueChanged)
        self.updateEmergencyRemindersSwitch()
        self.emergencyRemindersSwitch.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(self.numberOfTodayGoalsStepper.snp.bottom).offset(20)
            make.right.equalTo(self.numberOfTodayGoalsStepper)
        }
        
        let emergencyRemindersLabel = BSLabel()
        self.view.addSubview(emergencyRemindersLabel)
        emergencyRemindersLabel.text = "Goal emergency notifications"
        emergencyRemindersLabel.font = self.numberOfTodayGoalsLabel.font!
        emergencyRemindersLabel.snp.makeConstraints { (make) -> Void in
            make.centerY.equalTo(self.emergencyRemindersSwitch)
            make.left.equalTo(self.numberOfTodayGoalsLabel)
        }
        
        let signOutButton = BSButton()
        
        signOutButton.addTarget(self, action: #selector(SettingsViewController.signOutButtonPressed), for: UIControlEvents.touchUpInside)
        self.view.addSubview(signOutButton)
        signOutButton.setTitle("Sign Out", for: .normal)
        signOutButton.snp.makeConstraints { (make) -> Void in
            make.bottom.equalTo(-30)
            make.width.equalTo(self.view).multipliedBy(0.75)
            make.centerX.equalTo(self.view)
            make.height.equalTo(Constants.defaultTextFieldHeight)
        }
        
        let resetButton = BSButton()
        resetButton.addTarget(self, action: #selector(SettingsViewController.resetButtonPressed), for: .touchUpInside)
        self.view.addSubview(resetButton)
        resetButton.setTitle("Reset data", for: .normal)
        resetButton.snp.makeConstraints { (make) -> Void in
            make.bottom.equalTo(signOutButton.snp.top).offset(-10)
            make.left.equalTo(signOutButton)
            make.right.equalTo(signOutButton)
            make.height.equalTo(Constants.defaultTextFieldHeight)
            make.centerX.equalTo(self.view)
        }
        
        self.view.addSubview(self.tableView)
        self.tableView.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(0)
            make.right.equalTo(0)
            make.top.equalTo(emergencyRemindersSwitch.snp.bottom).offset(5)
            make.bottom.equalTo(resetButton.snp.top)
        }
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.tableFooterView = UIView()
        self.tableView.backgroundColor = UIColor.clear
        self.tableView.register(GoalNotificationSettingsTableViewCell.self, forCellReuseIdentifier: self.cellReuseIdentifier)
        self.loadGoalsFromDatabase()
    }
    
    func userDefaultsDidChange() {
        self.updateEmergencyRemindersSwitch()
        self.numberOfTodayGoalsLabel.text = "Goals in Today view: \(Int(self.numberOfTodayGoalsStepper.value))"
    }
    
    func updateEmergencyRemindersSwitch() {
        self.emergencyRemindersSwitch.isOn = RemoteNotificationsManager.sharedManager.on()
        self.tableView.isHidden = !self.emergencyRemindersSwitch.isOn        
    }
    
    func numberOfTodayGoalsStepperValueChanged() {
        UserDefaults.standard.set(Int(self.numberOfTodayGoalsStepper.value), forKey: "numberOfTodayGoals")
        UserDefaults.standard.synchronize()
    }
    
    func resetButtonPressed() {
        CurrentUserManager.sharedManager.reset()
        self.navigationController?.popViewController(animated: true)
    }
    
    func signOutButtonPressed() {
        CurrentUserManager.sharedManager.signOut()
        self.navigationController?.popViewController(animated: true)
    }
    
    func emergencyRemindersSwitchChanged() {
        self.tableView.isHidden = !self.emergencyRemindersSwitch.isOn
        if self.emergencyRemindersSwitch.isOn {
            RemoteNotificationsManager.sharedManager.turnNotificationsOn()
        }
        else {
            RemoteNotificationsManager.sharedManager.turnNotificationsOff()
        }
    }
    
    func loadGoalsFromDatabase() {
        self.frontburnerGoals = Goal.mr_findAll(with: NSPredicate(format: "burner = %@ and serverDeleted = false", "frontburner")) as! [Goal]
        self.frontburnerGoals = self.frontburnerGoals.sorted { ($0.losedate.intValue < $1.losedate.intValue) }
        self.backburnerGoals  = Goal.mr_findAll(with: NSPredicate(format: "burner = %@ and serverDeleted = false", "backburner")) as! [Goal]
        self.backburnerGoals = self.backburnerGoals.sorted { ($0.losedate.intValue < $1.losedate.intValue) }
    }
}

extension SettingsViewController : UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 1 { return self.frontburnerGoals.count }
        if section == 2 { return self.backburnerGoals.count  }
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: self.cellReuseIdentifier) as! GoalNotificationSettingsTableViewCell!
        if (indexPath as NSIndexPath).section == 0 {
            cell?.title = "Default notification settings"
            return cell!
        }
        let goal = (indexPath as NSIndexPath).section == 1 ? self.frontburnerGoals[(indexPath as NSIndexPath).row] : self.backburnerGoals[(indexPath as NSIndexPath).row]
        cell?.title = goal.slug
        return cell!
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if (indexPath as NSIndexPath).section == 0 {
            self.navigationController?.pushViewController(EditDefaultNotificationsViewController(), animated: true)
        } else {
            let goal = (indexPath as NSIndexPath).section == 1 ? self.frontburnerGoals[(indexPath as NSIndexPath).row] : self.backburnerGoals[(indexPath as NSIndexPath).row]
            self.navigationController?.pushViewController(EditGoalNotificationsViewController(goal: goal), animated: true)
        }
    }
}
