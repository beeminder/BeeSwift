//
//  SettingsViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/27/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation
import MBProgressHUD
import HealthKit

class SettingsViewController: UIViewController {
    
    fileprivate var emergencyRemindersSwitch = UISwitch()
    fileprivate var tableView = UITableView()
    fileprivate var goals : [Goal] = []
    fileprivate var cellReuseIdentifier = "goalNotificationSettingsTableViewCell"

    override func viewDidLoad() {
        self.title = "Settings"
        self.view.backgroundColor = UIColor.white
        
        NotificationCenter.default.addObserver(self, selector: #selector(SettingsViewController.userDefaultsDidChange), name: UserDefaults.didChangeNotification, object: nil)
        
        var healthKitCell : UIView?
        
        if HKHealthStore.isHealthDataAvailable() {
            healthKitCell = UIView()
            
            self.view.addSubview(healthKitCell!)
            healthKitCell!.snp.makeConstraints({ (make) in
                make.left.equalTo(15)
                make.right.equalTo(-15)
                make.top.equalTo(self.topLayoutGuide.snp.bottom).offset(10)
                make.height.equalTo(Constants.defaultTextFieldHeight)
            })
            
            let tapGR = UITapGestureRecognizer()
            healthKitCell!.addGestureRecognizer(tapGR)
            tapGR.addTarget(self, action: #selector(self.showHealthKitConfig))
            
            let label = BSLabel()
            label.text = "Health app integration"
            healthKitCell!.addSubview(label)
            label.snp.makeConstraints({ (make) in
                make.left.equalTo(0)
                make.centerY.equalTo(0)
            })
            
            let disclosure = UITableViewCell()
            healthKitCell!.addSubview(disclosure)
            disclosure.snp.makeConstraints({ (make) in
                make.right.equalTo(0)
                make.centerY.equalTo(0)
            })
            disclosure.accessoryType = .disclosureIndicator
            disclosure.isUserInteractionEnabled = false
            
        }
        
        self.view.addSubview(self.emergencyRemindersSwitch)
        self.emergencyRemindersSwitch.addTarget(self, action: #selector(SettingsViewController.emergencyRemindersSwitchChanged), for: .valueChanged)
        self.updateEmergencyRemindersSwitch()
        
        if healthKitCell == nil {
            self.emergencyRemindersSwitch.snp.makeConstraints { (make) -> Void in
                make.top.equalTo(self.topLayoutGuide.snp.bottom).offset(10)
                make.right.equalTo(-15)
            }
        } else {
            self.emergencyRemindersSwitch.snp.makeConstraints { (make) -> Void in
                make.top.equalTo(healthKitCell!.snp.bottom).offset(10)
                make.right.equalTo(-15)
            }
        }
        
        let emergencyRemindersLabel = BSLabel()
        self.view.addSubview(emergencyRemindersLabel)
        emergencyRemindersLabel.text = "Goal emergency notifications"
        emergencyRemindersLabel.snp.makeConstraints { (make) -> Void in
            make.centerY.equalTo(self.emergencyRemindersSwitch)
            make.left.equalTo(15)
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
    
    func showHealthKitConfig() {
        self.navigationController?.pushViewController(HealthKitConfigViewController(), animated: true)
    }
    
    func userDefaultsDidChange() {
        self.updateEmergencyRemindersSwitch()
    }
    
    func updateEmergencyRemindersSwitch() {
        self.emergencyRemindersSwitch.isOn = RemoteNotificationsManager.sharedManager.on()
        self.tableView.isHidden = !self.emergencyRemindersSwitch.isOn        
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
        self.goals = Goal.mr_findAllSorted(by: "losedate", ascending: true, with: NSPredicate(format: "serverDeleted = false")) as! [Goal]
    }
}

extension SettingsViewController : UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 1 { return self.goals.count }
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: self.cellReuseIdentifier) as! GoalNotificationSettingsTableViewCell!
        if (indexPath as NSIndexPath).section == 0 {
            cell?.title = "Default notification settings"
            return cell!
        }
        let goal = self.goals[(indexPath as NSIndexPath).row]
        cell?.title = goal.slug
        return cell!
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if (indexPath as NSIndexPath).section == 0 {
            self.navigationController?.pushViewController(EditDefaultNotificationsViewController(), animated: true)
        } else {
            let goal = self.goals[(indexPath as NSIndexPath).row]
            self.navigationController?.pushViewController(EditGoalNotificationsViewController(goal: goal), animated: true)
        }
        self.tableView.deselectRow(at: indexPath, animated: true)
    }
}
