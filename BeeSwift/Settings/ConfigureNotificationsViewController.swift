//
//  ConfigureNotificationsViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 12/20/17.
//  Copyright 2017 APB. All rights reserved.
//

import UIKit
import SwiftyJSON
import OSLog
import CoreData

import BeeKit

class ConfigureNotificationsViewController: UIViewController {
    private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "ConfigureNotificationsViewController")
    
    private var lastFetched : Date?
    fileprivate var tableView = UITableView()
    fileprivate let settingsButton = BSButton()
    private let goalManager: GoalManager
    private let viewContext: NSManagedObjectContext
    private let currentUserManager: CurrentUserManager
    private let requestManager: RequestManager
    
    // MARK: - Diffable Data Source Types
    private enum Section: Int, CaseIterable {
        case defaultSettings = 0
        case customizedGoals = 1
        case defaultGoals = 2
    }
    
    private enum Item: Hashable {
        case defaultSettings
        case goal(NSManagedObjectID)
    }
    
    private typealias NotificationsSnapshot = NSDiffableDataSourceSnapshot<Section, Item>
    private typealias NotificationsDataSource = UITableViewDiffableDataSource<Section, Item>
    
    private var dataSource: NotificationsDataSource!
    private var fetchedResultsController: NSFetchedResultsController<Goal>!
    
    init(goalManager: GoalManager, viewContext: NSManagedObjectContext, currentUserManager: CurrentUserManager, requestManager: RequestManager) {
        self.goalManager = goalManager
        self.viewContext = viewContext
        self.currentUserManager = currentUserManager
        self.requestManager = requestManager
        
        // Set up fetched results controller
        let fetchRequest = Goal.fetchRequest()
        let typedFetchRequest = fetchRequest as! NSFetchRequest<Goal>
        typedFetchRequest.sortDescriptors = [
            NSSortDescriptor(key: "useDefaults", ascending: false), // false (customized) comes before true (defaults)
            NSSortDescriptor(key: "slug", ascending: true)
        ]
        
        if let user = currentUserManager.user(context: viewContext) {
            typedFetchRequest.predicate = NSPredicate(format: "owner == %@", user)
        }
        
        self.fetchedResultsController = NSFetchedResultsController(
            fetchRequest: typedFetchRequest,
            managedObjectContext: viewContext,
            sectionNameKeyPath: "useDefaults",
            cacheName: nil
        )
        
        super.init(nibName: nil, bundle: nil)
        
        self.fetchedResultsController.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
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
        self.tableView.refreshControl = {
            let refresh = UIRefreshControl()
            refresh.addTarget(self, action: #selector(fetchGoals), for: .valueChanged)
            return refresh
        }()
        self.tableView.tableFooterView = UIView()
        self.tableView.register(SettingsTableViewCell.self, forCellReuseIdentifier: "configureNotificationsTableViewCell")
        
        // Configure data source
        self.configureDataSource()
        
        // Perform initial fetch
        do {
            try self.fetchedResultsController.performFetch()
            self.applySnapshot(animatingDifferences: false)
        } catch {
            logger.error("Failed to fetch goals: \(error)")
        }
        
        self.fetchGoals()
        self.updateHiddenElements()
        NotificationCenter.default.addObserver(self, selector: #selector(self.foregroundEntered), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Refresh the snapshot to ensure changes are reflected
        applySnapshot(animatingDifferences: true)
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
                try await self.goalManager.refreshGoals()
                self.lastFetched = Date()
                
                // Update predicate in case user has changed
                if let user = currentUserManager.user(context: viewContext) {
                    fetchedResultsController.fetchRequest.predicate = NSPredicate(format: "owner == %@", user)
                }
                
                try self.fetchedResultsController.performFetch()
                self.applySnapshot(animatingDifferences: true)
                
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
        }
    }
    
    // MARK: - Data Source Configuration
    private func configureDataSource() {
        dataSource = NotificationsDataSource(tableView: tableView) { [weak self] tableView, indexPath, item in
            let cell = tableView.dequeueReusableCell(withIdentifier: "configureNotificationsTableViewCell", for: indexPath) as? SettingsTableViewCell ?? SettingsTableViewCell()
            
            switch item {
            case .defaultSettings:
                cell.title = "Default notification settings"
            case .goal(let objectID):
                if let goal = try? self?.viewContext.existingObject(with: objectID) as? Goal {
                    cell.title = goal.slug
                }
            }
            
            return cell
        }
        
        dataSource.defaultRowAnimation = .fade
        self.tableView.dataSource = dataSource
    }
    
    private func applySnapshot(animatingDifferences: Bool = true) {
        var snapshot = NotificationsSnapshot()
        
        // Add default settings section
        snapshot.appendSections([.defaultSettings])
        snapshot.appendItems([.defaultSettings], toSection: .defaultSettings)
        
        // Add goal sections based on fetched results controller sections
        if let sections = fetchedResultsController.sections {
            for (index, sectionInfo) in sections.enumerated() {
                guard let objects = sectionInfo.objects as? [Goal] else { continue }
                
                // Map Core Data sections to our sections
                // Section 0 (useDefaults = false) -> customizedGoals
                // Section 1 (useDefaults = true) -> defaultGoals
                let section: Section = (index == 0) ? .customizedGoals : .defaultGoals
                
                if !objects.isEmpty {
                    snapshot.appendSections([section])
                    let items = objects.map { Item.goal($0.objectID) }
                    snapshot.appendItems(items, toSection: section)
                }
            }
        }
        
        dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
    }
}

// MARK: - UITableViewDelegate
extension ConfigureNotificationsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let sectionEnum = Section(rawValue: section) else { return nil }
        
        switch sectionEnum {
        case .defaultSettings:
            return lastFetched != nil && hasAnyGoals() ? "Defaults" : nil
        case .customizedGoals:
            return dataSource.snapshot().numberOfItems(inSection: .customizedGoals) > 0 ? "Customized" : nil
        case .defaultGoals:
            return dataSource.snapshot().numberOfItems(inSection: .defaultGoals) > 0 ? "Using Defaults" : nil
        }
    }
    
    private func hasAnyGoals() -> Bool {
        let snapshot = dataSource.snapshot()
        return snapshot.numberOfItems(inSection: .customizedGoals) > 0 || 
               snapshot.numberOfItems(inSection: .defaultGoals) > 0
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        
        let editNotificationsVC: UIViewController
        
        switch item {
        case .defaultSettings:
            editNotificationsVC = EditDefaultNotificationsViewController(
                currentUserManager: currentUserManager,
                requestManager: requestManager,
                goalManager: goalManager,
                viewContext: viewContext)
        case .goal(let objectID):
            guard let goal = try? viewContext.existingObject(with: objectID) as? Goal else { return }
            editNotificationsVC = EditGoalNotificationsViewController(
                goal: goal,
                currentUserManager: currentUserManager,
                requestManager: requestManager,
                goalManager: goalManager,
                viewContext: viewContext)
        }
        
        self.navigationController?.pushViewController(editNotificationsVC, animated: true)
    }
}

// MARK: - NSFetchedResultsControllerDelegate
extension ConfigureNotificationsViewController: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        applySnapshot(animatingDifferences: true)
    }
}
