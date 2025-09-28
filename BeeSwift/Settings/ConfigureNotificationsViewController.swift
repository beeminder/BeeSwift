//
//  ConfigureNotificationsViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 12/20/17.
//  Copyright 2017 APB. All rights reserved.
//

import BeeKit
import CoreData
import OSLog
import SwiftyJSON
import UIKit

class ConfigureNotificationsViewController: UIViewController {
  private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "ConfigureNotificationsViewController")
  private var lastFetched: Date?
  fileprivate var tableView = UITableView()
  fileprivate let settingsButton = BSButton()
  private let goalManager: GoalManager
  private let viewContext: NSManagedObjectContext
  private let currentUserManager: CurrentUserManager
  private let requestManager: RequestManager
  private weak var coordinator: MainCoordinator?
  private lazy var dataSource: NotificationsTableViewDiffibleDataSource = {
    NotificationsTableViewDiffibleDataSource(goals: [], tableView: tableView)
  }()
  init(
    goalManager: GoalManager,
    viewContext: NSManagedObjectContext,
    currentUserManager: CurrentUserManager,
    requestManager: RequestManager,
    coordinator: MainCoordinator
  ) {
    self.goalManager = goalManager
    self.viewContext = viewContext
    self.currentUserManager = currentUserManager
    self.requestManager = requestManager
    self.coordinator = coordinator
    super.init(nibName: nil, bundle: nil)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
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
    self.tableView.dataSource = self.dataSource
    self.tableView.refreshControl = {
      let refresh = UIRefreshControl()
      refresh.addTarget(self, action: #selector(fetchGoals), for: .valueChanged)
      return refresh
    }()
    self.tableView.tableFooterView = UIView()
    self.fetchGoals()
    self.updateHiddenElements()
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(self.foregroundEntered),
      name: UIApplication.willEnterForegroundNotification,
      object: nil
    )
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    self.applySnapshot()
  }
  private func applySnapshot() {
    guard lastFetched != nil else {
      let snapshot = NSDiffableDataSourceSnapshot<NotificationsTableViewDiffibleDataSource.Section, String>()
      dataSource.apply(snapshot)
      return
    }
    let snapshot = dataSource.makeSnapshot()
    dataSource.apply(snapshot, animatingDifferences: true)
  }
  @objc func settingsButtonTapped() { UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!) }

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
        self.dataSource.goals =
          self.goalManager.staleGoals(context: self.viewContext)?.sorted(using: SortDescriptor(\.slug)) ?? []
        self.lastFetched = Date()
        MBProgressHUD.hide(for: self.view, animated: true)
      } catch {
        logger.error("Failure fetching goals: \(error)")

        MBProgressHUD.hide(for: self.view, animated: true)
        if UIApplication.shared.applicationState == .active {
          let alert = UIAlertController(
            title: "Error fetching goals",
            message: error.localizedDescription,
            preferredStyle: .alert
          )
          alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
          self.present(alert, animated: true, completion: nil)
        }
      }
      self.applySnapshot()
    }
  }
}

private class NotificationsTableViewDiffibleDataSource: UITableViewDiffableDataSource<
  NotificationsTableViewDiffibleDataSource.Section, String
>
{
  static let cellReuseIdentifier = "configureNotificationsTableViewCell"
  var goals: [Goal]
  enum Section: Int, CaseIterable {
    case defaultNotificationSettings = 0
    case goalsUsingCustomSettings = 1
    case goalsUsingDefaults = 2
  }
  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    guard let section = Section(rawValue: section) else { return nil }
    return switch section {
    case .defaultNotificationSettings: "Defaults"
    case .goalsUsingDefaults where goalsUsingDefaultNotifications.isEmpty: nil
    case .goalsUsingCustomSettings where goalsUsingNonDefaultNotifications.isEmpty: nil
    case .goalsUsingDefaults: "Using Defaults"
    case .goalsUsingCustomSettings: "Customized"
    }
  }
  init(goals: [Goal], tableView: UITableView) {
    self.goals = goals
    tableView.register(SettingsTableViewCell.self, forCellReuseIdentifier: Self.cellReuseIdentifier)
    super.init(tableView: tableView) { tableView, indexPath, title in
      guard
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellReuseIdentifier, for: indexPath)
          as? SettingsTableViewCell
      else { return UITableViewCell() }
      cell.title = title
      return cell
    }
  }
  var goalsUsingDefaultNotifications: [Goal] { self.goals.filter { $0.useDefaults } }
  var goalsUsingNonDefaultNotifications: [Goal] { self.goals.filter { !$0.useDefaults } }
  func makeSnapshot() -> NSDiffableDataSourceSnapshot<Section, String> {
    var snapshot = NSDiffableDataSourceSnapshot<Section, String>()
    snapshot.appendSections([.defaultNotificationSettings])
    snapshot.appendItems(["Default notification settings"], toSection: .defaultNotificationSettings)

    snapshot.appendSections([.goalsUsingCustomSettings])
    snapshot.appendItems(goalsUsingNonDefaultNotifications.map { $0.slug }, toSection: .goalsUsingCustomSettings)
    snapshot.appendSections([.goalsUsingDefaults])
    snapshot.appendItems(goalsUsingDefaultNotifications.map { $0.slug }, toSection: .goalsUsingDefaults)

    snapshot.reconfigureItems(goals.map({ $0.slug }))
    return snapshot
  }
  func goalAtIndexPath(_ indexPath: IndexPath) -> Goal? {
    guard let section = NotificationsTableViewDiffibleDataSource.Section(rawValue: indexPath.section) else {
      return nil
    }
    return switch section {
    case .defaultNotificationSettings: nil
    case .goalsUsingCustomSettings:
      indexPath.row < goalsUsingNonDefaultNotifications.count ? goalsUsingNonDefaultNotifications[indexPath.row] : nil
    case .goalsUsingDefaults:
      indexPath.row < goalsUsingDefaultNotifications.count ? goalsUsingDefaultNotifications[indexPath.row] : nil
    }
  }
}

extension ConfigureNotificationsViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    self.tableView.deselectRow(at: indexPath, animated: true)
    guard let section = NotificationsTableViewDiffibleDataSource.Section(rawValue: indexPath.section) else { return }
    switch section {
    case .defaultNotificationSettings: coordinator?.showConfigureDefaultNotifications()
    case .goalsUsingDefaults, .goalsUsingCustomSettings:
      guard let goal = self.dataSource.goalAtIndexPath(indexPath) else { return }
      coordinator?.showConfigureNotificationsForGoal(goal)
    }
  }
}
