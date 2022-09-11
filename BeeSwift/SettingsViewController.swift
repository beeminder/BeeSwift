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
    
    fileprivate var tableView = UITableView()
    fileprivate let cellReuseIdentifier = "settingsTableViewCell"
    
    override func viewDidLoad() {
        self.title = "Settings"
        if #available(iOS 13.0, *) {
            self.view.backgroundColor = .systemBackground
        } else {
            self.view.backgroundColor = .white
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.userDefaultsDidChange), name: UserDefaults.didChangeNotification, object: nil)
        
        self.view.addSubview(self.tableView)
        self.tableView.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(0)
            make.right.equalTo(0)
            if #available(iOS 11.0, *) {
                make.top.equalTo(self.view.safeAreaLayoutGuide.snp.topMargin)
                make.bottom.equalTo(self.view.snp.bottom)
            } else {
                make.bottom.equalTo(self.bottomLayoutGuide.snp.top)
                make.top.equalTo(self.topLayoutGuide.snp.bottom)
            }
        }
        
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.isScrollEnabled = false
        self.tableView.tableFooterView = UIView()
        if #available(iOS 13.0, *) {
            self.view.backgroundColor = .systemBackground
        } else {
            self.view.backgroundColor = .white
        }
        self.tableView.register(SettingsTableViewCell.self, forCellReuseIdentifier: self.cellReuseIdentifier)

        if let info = Bundle.main.infoDictionary {
            let appVersion = info["CFBundleShortVersionString"] as? String ?? "Unknown"
            let appBuild = info[kCFBundleVersionKey as String] as? String ?? "Unknown"

            let versionLabel = BSLabel()
            versionLabel.text = "Version: \(appVersion) (\(appBuild))"
            self.view.addSubview(versionLabel)
            versionLabel.snp.makeConstraints { (make) in
                if #available(iOS 11.0, *) {
                    make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottomMargin).offset(-10)
                } else {
                    make.bottom.equalTo(self.bottomLayoutGuide.snp.top).offset(-10)
                }
                make.width.equalTo(self.view)
            }
            versionLabel.textAlignment = .center
        }
    }

    @objc func userDefaultsDidChange() {
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    func signOutButtonPressed() {
        CurrentUserManager.sharedManager.signOut()
        self.navigationController?.popViewController(animated: true)
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
            cell.imageName = "Sort"
            cell.accessoryType = .disclosureIndicator
        case 1:
            UNUserNotificationCenter.current().getNotificationSettings { (settings) in
                DispatchQueue.main.async {
                    cell.title = "Emergency notifications: \(settings.authorizationStatus == .authorized ? "on" : "off")"
                }
            }
            cell.imageName = "Notifications"
            cell.accessoryType = .disclosureIndicator
        case 2:
            cell.title = "Time zone: \(CurrentUserManager.sharedManager.timezone())"
            cell.imageName = "Clock"
            cell.accessoryType = .none
        case 3:
            cell.title = "Sign out"
            cell.imageName = "SignOut"
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
                self.navigationController?.pushViewController(HealthKitConfigViewController(), animated: true)
                return
            }
            section = section - 1
        }
        
        switch section {
        case 0:
            self.navigationController?.pushViewController(ChooseGoalSortViewController(), animated: true)
        case 1:
            self.navigationController?.pushViewController(ConfigureNotificationsViewController(), animated: true)
        case 2:
            print("nothing")
        case 3:
            self.signOutButtonPressed()
        default:
            break
        }
    }
}
