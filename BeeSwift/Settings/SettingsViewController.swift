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
    private weak var coordinator: MainCoordinator?
    
    init(currentUserManager: CurrentUserManager,
         viewContext: NSManagedObjectContext,
         goalManager: GoalManager,
         requestManager: RequestManager,
         coordinator: MainCoordinator) {
        self.currentUserManager = currentUserManager
        self.viewContext = viewContext
        self.goalManager = goalManager
        self.requestManager = requestManager
        self.coordinator = coordinator
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
        coordinator?.showLogs()
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
        UIView()
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        UIView()
    }
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        CGFloat.leastNormalMagnitude
    }
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        20
    }
    func numberOfSections(in tableView: UITableView) -> Int {
        5
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: self.cellReuseIdentifier, for: indexPath) as? SettingsTableViewCell
        else { return UITableViewCell() }
        

        switch indexPath.section {
        case 0:
            cell.title = "Health app integration"
            cell.imageName = "Health"
            cell.accessoryType = .disclosureIndicator
            cell.isUserInteractionEnabled = HKHealthStore.isHealthDataAvailable()
            return cell
        case 1:
            let selectedGoalSort = UserDefaults.standard.value(forKey: Constants.selectedGoalSortKey) as? String
            cell.title = "Sort goals by: \(selectedGoalSort ?? "")"
            cell.imageName = "arrow.up.arrow.down"
            cell.accessoryType = .disclosureIndicator
        case 2:
            UNUserNotificationCenter.current().getNotificationSettings { (settings) in
                DispatchQueue.main.async {
                    cell.title = "Emergency notifications: \(settings.authorizationStatus == .authorized ? "on" : "off")"
                }
            }
            cell.imageName = "app.badge"
            cell.accessoryType = .disclosureIndicator
        case 3:
            let user = currentUserManager.user(context: viewContext)
            let timezone = user?.timezone ?? "Unknown"
            cell.title = "Time zone: \(timezone)"
            cell.imageName = "clock"
            cell.accessoryType = .none
        case 4:
            cell.title = "Sign out"
            cell.imageName = "rectangle.portrait.and.arrow.right"
            cell.accessoryType = .none
        default:
            break
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case 0 where HKHealthStore.isHealthDataAvailable():
            coordinator?.showConfigureHealthKitIntegration()
        case 1:
            coordinator?.showChooseGallerySortAlgorithm()
        case 2:
            coordinator?.showConfigureNotifications()
        case 3:
            print("nothing")
        case 4:
            self.signOutButtonPressed()
        default:
            break
        }
    }
}
