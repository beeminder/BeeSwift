//
//  HealthKitConfigViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 3/14/17.
//  Copyright © 2017 APB. All rights reserved.
//

import UIKit
import HealthKit
import UserNotifications
import SwiftyJSON

class HealthKitConfigViewController: UIViewController {
    
    var tableView = UITableView()
    var jsonGoals : [JSONGoal] = []
    let cellReuseIdentifier = "healthKitConfigTableViewCell"
    var syncRemindersSwitch = UISwitch()
    let margin = 12

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
        self.title = "Health app integration"
        let backItem = UIBarButtonItem(title: "Back", style: .plain, target: nil, action: nil)
        self.navigationItem.backBarButtonItem = backItem
        
        let syncRemindersLabel = BSLabel()
        self.view.addSubview(syncRemindersLabel)
        syncRemindersLabel.text = "Sync Health data reminders"
        syncRemindersLabel.snp.makeConstraints { (make) in
            make.left.equalTo(self.margin)
            make.right.equalTo(0)
            make.top.equalTo(self.topLayoutGuide.snp.bottom)
            make.height.equalTo(Constants.defaultTextFieldHeight)
        }
        
        self.view.addSubview(self.syncRemindersSwitch)
        self.syncRemindersSwitch.isOn = UserDefaults.standard.bool(forKey: Constants.healthSyncRemindersPreferenceKey)
        self.syncRemindersSwitch.addTarget(self, action: #selector(self.syncRemindersSwitchValueChanged), for: .valueChanged)
        self.syncRemindersSwitch.snp.makeConstraints { (make) in
            make.centerY.equalTo(syncRemindersLabel)
            make.right.equalTo(-self.margin)
        }
        
        self.view.addSubview(self.tableView)
        self.tableView.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(0)
            make.right.equalTo(0)
            make.top.equalTo(syncRemindersLabel.snp.bottom)
            make.bottom.equalTo(self.bottomLayoutGuide.snp.top)
        }
        
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.tableFooterView = UIView()
        self.tableView.backgroundColor = UIColor.clear
        self.tableView.register(HealthKitConfigTableViewCell.self, forCellReuseIdentifier: self.cellReuseIdentifier)
        self.fetchGoals()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleMetricSavedNotification(notification:)), name: NSNotification.Name(rawValue: Constants.savedMetricNotificationName), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleMetricRemovedNotification(notification:)), name: NSNotification.Name(rawValue: Constants.removedMetricNotificationName), object: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @objc func syncRemindersSwitchValueChanged() {
        UserDefaults.standard.set(self.syncRemindersSwitch.isOn, forKey: Constants.healthSyncRemindersPreferenceKey)
        if self.syncRemindersSwitch.isOn == false {
            if #available(iOS 10.0, *) {
                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            } else {
                // Fallback on earlier versions
            }
        }
    }
    
    func fetchGoals() {
        guard let username = CurrentUserManager.sharedManager.username else { return }
        MBProgressHUD.showAdded(to: self.view, animated: true)
        RequestManager.get(url: "api/v1/users/\(username)/goals.json", parameters: nil, success: { (responseJSON) in
            MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
            guard let responseGoals = JSON(responseJSON!).array else { return }
            
            var jGoals : [JSONGoal] = []
            responseGoals.forEach({ (goalJSON) in
                let g = JSONGoal(json: goalJSON)
                jGoals.append(g)
            })
            self.jsonGoals = jGoals.sorted(by: { (goal1, goal2) -> Bool in
                return goal1.slug > goal2.slug
            })
            self.tableView.reloadData()
        }) { (responseError) in
            MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
            if let errorString = responseError?.localizedDescription {
                let alert = UIAlertController(title: "Error fetching goals", message: errorString, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
            self.tableView.reloadData()
        }
    }
    
    @objc func handleMetricSavedNotification(notification : Notification) {
        let metric = notification.userInfo?["metric"]
        self.saveMetric(databaseString: metric as! String)
    }
    
    @objc func handleMetricRemovedNotification(notification : Notification) {
        self.fetchGoals()
    }
    
    func saveMetric(databaseString : String) {
        let goal = self.jsonGoals[(self.tableView.indexPathForSelectedRow?.row)!]
        goal.healthKitMetric = databaseString
        goal.autodata = "apple"
        goal.setupHealthKit()
        
        var params : [String : [String : String]] = [:]
        params = ["ii_params" : ["name" : "apple", "metric" : goal.healthKitMetric!]]
        
        RequestManager.put(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!)/goals/\(goal.slug).json", parameters: params, success: { (responseObject) -> Void in
                self.tableView.reloadData()
                self.navigationController?.popViewController(animated: true)
        }) { (error) -> Void in
            // bar
        }
    }
}

extension HealthKitConfigViewController : UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.jsonGoals.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: self.cellReuseIdentifier) as! HealthKitConfigTableViewCell!

        let goal = self.jsonGoals[(indexPath as NSIndexPath).row]
        cell!.jsonGoal = goal
        
        return cell!
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let goal = self.jsonGoals[(indexPath as NSIndexPath).row]
        
        if goal.autodata.count == 0 {
            self.navigationController?.pushViewController(ChooseHKMetricViewController(), animated: true)
        } else if goal.autodata == "apple" {
            let controller = RemoveHKMetricViewController()
            controller.goal = goal
            self.navigationController?.pushViewController(controller, animated: true)
        }
    }
}
