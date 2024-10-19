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
    
    private var lastFetched : Date?
    fileprivate var goals : [Goal] = []
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
            make.left.equalTo(self.view.safeAreaLayoutGuide.snp.left)
            make.right.equalTo(self.view.safeAreaLayoutGuide.snp.right)
            
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top)
            make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottom)
        }
        self.tableView.isHidden = true
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.refreshControl = {
            let refresh = UIRefreshControl()
            refresh.addTarget(self, action: #selector(fetchGoals), for: .valueChanged)
            return refresh
        }()
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
        self.fetchGoals()
        self.updateHiddenElements()
    }
    
    @objc func fetchGoals() {
        Task { @MainActor in
            self.tableView.refreshControl?.endRefreshing()

            MBProgressHUD.showAdded(to: self.view, animated: true)
            do {
                try await ServiceLocator.goalManager.refreshGoals()
                self.goals = ServiceLocator.goalManager.staleGoals(context: ServiceLocator.persistentContainer.viewContext)?.sorted(by: { $0.slug < $1.slug }) ?? []
                self.lastFetched = Date()
                MBProgressHUD.hide(for: self.view, animated: true)
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

private extension ConfigureNotificationsViewController {
    var goalsUsingDefaultNotifications: [Goal] {
        self.goals.filter { $0.useDefaults }
    }
    
    var goalsUsingNonDefaultNotifications: [Goal] {
        self.goals.filter { !$0.useDefaults }
    }

}

extension ConfigureNotificationsViewController : UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        guard lastFetched != nil else { return 0 }
        return 3
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 1
        case 1:
            return self.goalsUsingDefaultNotifications.count
        default:
            return self.goalsUsingNonDefaultNotifications.count
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            guard !goals.isEmpty else { return nil }
            return "Defaults"
        case 1:
            guard !goalsUsingDefaultNotifications.isEmpty else { return nil }
            return "Using Defaults"
        default:
            guard !goalsUsingNonDefaultNotifications.isEmpty else { return nil }
            return "Customized"
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: self.cellReuseIdentifier) as? SettingsTableViewCell else {
            return UITableViewCell()
        }
        
        switch indexPath.section {
        case 0:
            cell.title = "Default notification settings"
            return cell
        case 1:
            let goal = self.goalsUsingDefaultNotifications[indexPath.row]
            cell.title = goal.slug
            return cell
        default:
            let goal = self.goalsUsingNonDefaultNotifications[indexPath.row]
            cell.title = goal.slug
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let editNotificationsVC: UIViewController
        
        switch indexPath.section {
        case 0:
            editNotificationsVC = EditDefaultNotificationsViewController()
        case 1:
            let goal = self.goalsUsingDefaultNotifications[indexPath.row]
            editNotificationsVC = EditGoalNotificationsViewController(goal: goal)
        default:
            let goal = self.goalsUsingNonDefaultNotifications[indexPath.row]
            editNotificationsVC = EditGoalNotificationsViewController(goal: goal)
        }
        
        self.navigationController?.pushViewController(editNotificationsVC, animated: true)
        self.tableView.deselectRow(at: indexPath, animated: true)
    }
}

