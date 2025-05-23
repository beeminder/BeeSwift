//
//  SettingsViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/27/15.
//  Copyright 2015 APB. All rights reserved.
//

import Foundation
import MBProgressHUD
import HealthKit
import CoreData

import BeeKit

class SettingsViewController: UIViewController {
    
    fileprivate var tableView = UITableView()
    fileprivate let cellReuseIdentifier = "settingsTableViewCell"
    private let currentUserManager: CurrentUserManager
    private let viewContext: NSManagedObjectContext
    private let goalManager: GoalManager
    private let requestManager: RequestManager
    
    init(currentUserManager: CurrentUserManager,
         viewContext: NSManagedObjectContext,
         goalManager: GoalManager,
         requestManager: RequestManager) {
        self.currentUserManager = currentUserManager
        self.viewContext = viewContext
        self.goalManager = goalManager
        self.requestManager = requestManager
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        self.title = "Settings"
        self.view.backgroundColor = .systemBackground
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.userDefaultsDidChange), name: UserDefaults.didChangeNotification, object: nil)
        
        self.view.addSubview(self.tableView)

        self.tableView.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(0)
            make.right.equalTo(0)
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.topMargin)
            make.bottom.equalTo(self.view.snp.bottom)
        }
        
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.tableFooterView = UIView()
        self.tableView.register(SettingsTableViewCell.self, forCellReuseIdentifier: self.cellReuseIdentifier)
        self.tableView.refreshControl = {
            let refreshControl = UIRefreshControl()
            refreshControl.addTarget(self, action: #selector(self.fetchUser), for: UIControl.Event.valueChanged)
            return refreshControl
        }()

        let versionLabel = BSLabel()
        self.view.addSubview(versionLabel)
        versionLabel.snp.makeConstraints { (make) in
            make.width.equalTo(self.view)
        }
        versionLabel.textAlignment = .center
        if let info = Bundle.main.infoDictionary {
            let appVersion = info["CFBundleShortVersionString"] as? String ?? "Unknown"
            let appBuild = info[kCFBundleVersionKey as String] as? String ?? "Unknown"
            versionLabel.text = "Version: \(appVersion) (\(appBuild))"
        } else {
            versionLabel.text = "Version: Unknown"
        }

        let logsLabel = UILabel()
        self.view.addSubview(logsLabel)
        logsLabel.textAlignment = .center
        logsLabel.text = "Debug Logs »"
        logsLabel.font = UIFont(name: "Avenir-Light", size: 16)!
        logsLabel.textColor = .systemBlue
        logsLabel.isUserInteractionEnabled = true
        logsLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(showLogsTapped)))

        logsLabel.snp.makeConstraints { (make) in
            make.top.equalTo(versionLabel.snp.bottom).offset(10)
            make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottomMargin)
            make.width.equalTo(self.view)
        }

    }

    @objc func userDefaultsDidChange() {
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    func signOutButtonPressed() {
        Task { @MainActor in
            try! await currentUserManager.signOut()
            self.navigationController?.popViewController(animated: true)
        }
    }

    @objc
    func showLogsTapped() {
        self.navigationController?.pushViewController(LogsViewController(), animated: true)
    }
    
    @objc private func fetchUser() {
        Task { @MainActor [weak self] in
            self?.tableView.isUserInteractionEnabled = false
            try? await self?.goalManager.refreshGoals()

            self?.tableView.reloadData()
            self?.tableView.layoutIfNeeded()
            self?.tableView.refreshControl?.endRefreshing()
            
            self?.tableView.isUserInteractionEnabled = true
        }
    }

}

extension SettingsViewController : UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return UIView()
    }
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude
    }
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 20
    }
    func numberOfSections(in tableView: UITableView) -> Int {
        return HKHealthStore.isHealthDataAvailable() ? 5 : 4
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var section = indexPath.section
        guard let cell = tableView.dequeueReusableCell(withIdentifier: self.cellReuseIdentifier) as? SettingsTableViewCell else { return UITableViewCell() }
        if HKHealthStore.isHealthDataAvailable() {
            if section == 0 {
                cell.title = "Health app integration"
                cell.imageName = "Health"
                cell.accessoryType = .disclosureIndicator
                return cell
            }
            section = section - 1
        }
        
        switch section {
        case 0:
            let selectedGoalSort = UserDefaults.standard.value(forKey: Constants.selectedGoalSortKey) as? String
            cell.title = "Sort goals by: \(selectedGoalSort ?? "")"
            cell.imageName = "arrow.up.arrow.down"
            cell.accessoryType = .disclosureIndicator
        case 1:
            UNUserNotificationCenter.current().getNotificationSettings { (settings) in
                DispatchQueue.main.async {
                    cell.title = "Emergency notifications: \(settings.authorizationStatus == .authorized ? "on" : "off")"
                }
            }
            cell.imageName = "app.badge"
            cell.accessoryType = .disclosureIndicator
        case 2:
            let user = currentUserManager.user(context: viewContext)
            let timezone = user?.timezone ?? "Unknown"
            cell.title = "Time zone: \(timezone)"
            cell.imageName = "clock"
            cell.accessoryType = .none
        case 3:
            cell.title = "Sign out"
            cell.imageName = "rectangle.portrait.and.arrow.right"
            cell.accessoryType = .none
        default:
            break
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var section = indexPath.section
        if HKHealthStore.isHealthDataAvailable() {
            if section == 0 {
                self.navigationController?.pushViewController(HealthKitConfigViewController(
                    goalManager: goalManager,
                    viewContext: viewContext,
                    healthStoreManager: ServiceLocator.healthStoreManager,
                    requestManager: requestManager), animated: true)
                return
            }
            section = section - 1
        }
        
        switch section {
        case 0:
            self.navigationController?.pushViewController(ChooseGoalSortViewController(), animated: true)
        case 1:
            self.navigationController?.pushViewController(ConfigureNotificationsViewController(
                goalManager: goalManager,
                viewContext: viewContext,
                currentUserManager: currentUserManager,
                requestManager: requestManager), animated: true)
        case 2:
            print("nothing")
        case 3:
            self.signOutButtonPressed()
        default:
            break
        }
    }
}
