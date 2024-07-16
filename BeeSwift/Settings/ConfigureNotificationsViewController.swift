//
//  ConfigureNotificationsViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 12/20/17.
//  Copyright © 2017 APB. All rights reserved.
//

import UIKit
import SwiftyJSON
import OSLog

import BeeKit

class ConfigureNotificationsViewController: UIViewController {
    private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "ConfigureNotificationsViewController")
    
    fileprivate var goals : [GoalProtocol] = []
    fileprivate var cellReuseIdentifier = "configureNotificationsTableViewCell"
    fileprivate var tableView = UITableView()
    fileprivate let settingsButton = BSButton()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Notifications"
        self.view.backgroundColor = .systemBackground
        
        self.view.addSubview(self.settingsButton)
        self.settingsButton.isHidden = true
        self.settingsButton.setTitle("Open Settings to Enable Notifications", for: .normal)
        self.settingsButton.titleLabel?.textAlignment = .center
        self.settingsButton.titleLabel?.numberOfLines = 0
        self.settingsButton.snp.makeConstraints { (make) in
            make.center.equalTo(self.view)
            make.leftMargin.rightMargin.equalTo(20)
            make.height.equalTo(84)
        }
        self.settingsButton.addTarget(self, action: #selector(self.settingsButtonTapped), for: .touchUpInside)
    
        self.view.addSubview(self.tableView)
        self.tableView.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(0)
            make.right.equalTo(0)
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.topMargin).offset(10)
            make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottomMargin)

        }
        self.tableView.isHidden = true
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.tableFooterView = UIView()
        self.tableView.register(SettingsTableViewCell.self, forCellReuseIdentifier: self.cellReuseIdentifier)
        self.fetchGoals()
        self.updateHiddenElements()
        NotificationCenter.default.addObserver(self, selector: #selector(self.foregroundEntered), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    @objc func settingsButtonTapped() {
        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
    }
    
    func sortGoals() {
        self.goals.sort { (goal1, goal2) -> Bool in
            return goal1.slug > goal2.slug
        }
    }
    
    func updateHiddenElements() {
        UNUserNotificationCenter.current().getNotificationSettings { (settings) in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .authorized {
                    self.settingsButton.isHidden = true
                    self.tableView.isHidden = false
                } else {
                    self.settingsButton.isHidden = false
                    self.tableView.isHidden = true
                }
            }
        }
    }
    
    @objc func foregroundEntered() {
        self.updateHiddenElements()
    }
    
    func fetchGoals() {
        Task { @MainActor in
            do {
                let goals = try await ServiceLocator.goalManager.fetchGoals()
                self.goals = goals
                self.sortGoals()
            } catch {
                logger.error("Failure fetching goals: \(error)")

                MBProgressHUD.hide(for: self.view, animated: true)
                if UIApplication.shared.applicationState == .active {
                    let alert = UIAlertController(title: "Error fetching goals", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                }
            }
            self.tableView.reloadData()
        }
    }
}

extension ConfigureNotificationsViewController : UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 1 { return self.goals.count }
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: self.cellReuseIdentifier) as! SettingsTableViewCell?
        if (indexPath as NSIndexPath).section == 0 {
            cell?.title = "Default notification settings"
            return cell!
        }
        let goal = self.goals[(indexPath as NSIndexPath).row]
        cell?.title = goal.slug
        return cell!
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if (indexPath as NSIndexPath).section == 0 {        self.navigationController?.pushViewController(EditDefaultNotificationsViewController(), animated: true)
        } else {
            let goal = self.goals[(indexPath as NSIndexPath).row]
            self.navigationController?.pushViewController(EditGoalNotificationsViewController(goal: goal), animated: true)
        }
        self.tableView.deselectRow(at: indexPath, animated: true)
    }
}
