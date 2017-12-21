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
        self.view.backgroundColor = UIColor.white
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.userDefaultsDidChange), name: UserDefaults.didChangeNotification, object: nil)
        
        self.view.addSubview(self.tableView)
        self.tableView.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(0)
            make.right.equalTo(0)
            if #available(iOS 11.0, *) {
                make.top.equalTo(self.view.safeAreaLayoutGuide.snp.topMargin)
                make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottomMargin)
            } else {
                make.bottom.equalTo(self.bottomLayoutGuide.snp.top)
                make.top.equalTo(self.topLayoutGuide.snp.bottom)
            }
        }
        
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.tableFooterView = UIView()
        self.tableView.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
        self.tableView.register(SettingsTableViewCell.self, forCellReuseIdentifier: self.cellReuseIdentifier)
    }
    
    @objc func userDefaultsDidChange() {
        self.tableView.reloadData()
    }
    
    func resetButtonPressed() {
        CurrentUserManager.sharedManager.reset()
        self.navigationController?.popViewController(animated: true)
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
        cell.backgroundColor = .white
        if HKHealthStore.isHealthDataAvailable() {
            if section == 0 {
                cell.title = "Health app integration"
                cell.imageName = "Health"
                return cell
            }
            section = section - 1
        }
        switch section {
        case 0:
            let selectedGoalSort = UserDefaults.standard.value(forKey: Config.selectedGoalSortKey) as? String
            cell.title = "Sort goals by: \(selectedGoalSort ?? "")"
            cell.imageName = "Sort"
        case 1:
            cell.title = "Goal emergency notifications: \(RemoteNotificationsManager.sharedManager.on() ? "on" : "off")"
            cell.imageName = "Notifications"
        case 2:
            cell.title = "Reset data"
            cell.imageName = "ResetData"
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
            self.resetButtonPressed()
        case 3:
            self.signOutButtonPressed()
        default:
            break
        }
    }
}
