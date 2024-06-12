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
import OSLog

import BeeKit

class HealthKitConfigViewController: UIViewController {
    private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "HealthKitConfigViewController")
    
    var tableView = UITableView()
    var goals : [BeeGoal] = []
    let cellReuseIdentifier = "healthKitConfigTableViewCell"
    let margin = 12
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .systemBackground
        self.title = "Health app integration"
        let backItem = UIBarButtonItem(title: "Back", style: .plain, target: nil, action: nil)
        self.navigationItem.backBarButtonItem = backItem
        
        self.view.addSubview(self.tableView)
        self.tableView.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(self.margin)
            make.right.equalTo(-self.margin)
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.topMargin).offset(self.margin)
            make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottomMargin)
        }
        
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.refreshControl = {
            let refresh = UIRefreshControl()
            refresh.addTarget(self, action: #selector(fetchGoals), for: .valueChanged)
            return refresh
        }()
        self.tableView.tableFooterView = UIView()
        self.tableView.backgroundColor = UIColor.clear
        self.tableView.register(HealthKitConfigTableViewCell.self, forCellReuseIdentifier: self.cellReuseIdentifier)
        self.goals = ServiceLocator.goalManager.staleGoals() ?? []
        self.sortGoals()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleMetricRemovedNotification(notification:)), name: NSNotification.Name(rawValue: CurrentUserManager.healthKitMetricRemovedNotificationName), object: nil)
    }
    
    func sortGoals() {
        self.goals.sort { $0.slug < $1.slug }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.fetchGoals()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @objc func fetchGoals() {
        Task { @MainActor in
            self.tableView.refreshControl?.endRefreshing()

            MBProgressHUD.showAdded(to: self.view, animated: true)
            do {
                let goals = try await ServiceLocator.goalManager.fetchGoals()
                MBProgressHUD.hide(for: self.view, animated: true)
                self.goals = goals
                self.sortGoals()
            } catch {
                logger.error("Error fetching goals: \(error)")

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
    
    @objc func handleMetricRemovedNotification(notification: Notification) {
        self.fetchGoals()
    }
}

extension HealthKitConfigViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3 // manual, auto but apple (editable), auto
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 { // first section, modifiable
            return self.manualSourced.count
        } else if section == 1 {
            return self.autoSourcedModifiable.count
        } else {
            return self.autoSourcedUnmodifiable.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: self.cellReuseIdentifier) as! HealthKitConfigTableViewCell
        
        let goal = self.goalAt(indexPath)
        
        cell.goal = goal
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "Manual Goals"
        } else if section == 1 {
            return "Connected to Apple Health"
        } else {
            return "Other Autodata Goals"
        }
    }
    
    private func goalAt(_ indexPath: IndexPath) -> BeeGoal {
        if indexPath.section == 0 {
            return self.manualSourced[indexPath.row]
        } else if indexPath.section == 1 {
            return self.autoSourcedModifiable[indexPath.row]
        } else {
            return self.autoSourcedUnmodifiable[indexPath.row]
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let goal = self.goalAt(indexPath)
        
        if goal.autodata.count == 0 {
            let chooseHKMetricViewController = ChooseHKMetricViewController()
            chooseHKMetricViewController.goal = goal
            self.navigationController?.pushViewController(chooseHKMetricViewController, animated: true)
        } else if goal.autodata == "apple" {
            let controller = RemoveHKMetricViewController()
            controller.goal = goal
            self.navigationController?.pushViewController(controller, animated: true)
        } else {
            let alert: UIAlertController = {
                let alert = UIAlertController(title: "Autodata Goal", message: "At the moment we don't have a way for you to swap data sources here yourself for autodata goals", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                return alert
            }()
            self.present(alert, animated: true, completion: nil)
        }
    }
}

extension HealthKitConfigViewController {
    var autoSourced: [BeeGoal] {
        return self.goals.filter { $0.isDataProvidedAutomatically }
    }
    
    var manualSourced: [BeeGoal] {
        return self.goals.filter { !$0.isDataProvidedAutomatically }
    }
    
    var autoSourcedModifiable: [BeeGoal] {
        return self.autoSourced.filter { goal -> Bool in
            return "Apple".localizedCaseInsensitiveCompare(goal.autodata) == ComparisonResult.orderedSame
        }
    }
    
    var autoSourcedUnmodifiable: [BeeGoal] {
        return self.autoSourced.filter { goal -> Bool in
            return "Apple".localizedCaseInsensitiveCompare(goal.autodata) != ComparisonResult.orderedSame
        }
    }
}
