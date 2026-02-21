// Part of BeeSwift. Copyright Beeminder

import BeeKit
import CoreData
import Foundation
import UIKit
import UserNotifications

class GoalSettingsViewController: UIViewController {
  fileprivate var tableView = UITableView(frame: .zero, style: .insetGrouped)
  fileprivate let cellReuseIdentifier = "goalSettingsTableViewCell"
  let goal: Goal
  private let currentUserManager: CurrentUserManager
  private let requestManager: RequestManager
  private let goalManager: GoalManager
  private weak var coordinator: MainCoordinator?

  private var notificationsAuthorized: Bool?

  private enum Row {
    case notifications
    case dataSource
  }

  private var rows: [Row] { [.notifications, .dataSource] }

  init(
    goal: Goal,
    currentUserManager: CurrentUserManager,
    requestManager: RequestManager,
    goalManager: GoalManager,
    coordinator: MainCoordinator
  ) {
    self.goal = goal
    self.currentUserManager = currentUserManager
    self.requestManager = requestManager
    self.goalManager = goalManager
    self.coordinator = coordinator
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.title = "Goal Settings"
    self.view.backgroundColor = .systemBackground

    self.view.addSubview(self.tableView)

    self.tableView.snp.makeConstraints { (make) -> Void in
      make.left.equalTo(0)
      make.right.equalTo(0)
      make.top.equalTo(self.view.safeAreaLayoutGuide.snp.topMargin)
      make.bottom.equalTo(self.view.snp.bottom)
    }
    self.tableView.delegate = self
    self.tableView.dataSource = self
    self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: self.cellReuseIdentifier)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    updateNotificationStatus()
    tableView.reloadData()
  }

  private func updateNotificationStatus() {
    UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
      DispatchQueue.main.async {
        self?.notificationsAuthorized = settings.authorizationStatus == .authorized
        self?.tableView.reloadData()
      }
    }
  }

  private var isDataSourceRowTappable: Bool { goal.isLinkedToHealthKit || !goal.isDataProvidedAutomatically }

  private var notificationsSummary: String {
    guard notificationsAuthorized != false else { return "Disabled" }
    if goal.useDefaults {
      return "Using defaults"
    } else {
      let days = goal.leadTime
      if days == 0 {
        let hours = hoursUntilDeadline
        if hours == 1 { return "1 hour before" } else { return "\(hours) hours before" }
      } else if days == 1 {
        return "1 day before"
      } else {
        return "\(days) days before"
      }
    }
  }

  private var hoursUntilDeadline: Int {
    // alertStart is seconds from midnight (e.g., 8pm = 72000)
    // deadline can be negative for times after 6am (e.g., 11pm = -3600)
    // or positive for times 0-6am (e.g., 3am = 10800)
    var deadlineSeconds = goal.deadline
    if deadlineSeconds < 0 { deadlineSeconds += 24 * 3600 }

    let alertStartSeconds = goal.alertStart

    var diff = deadlineSeconds - alertStartSeconds
    if diff <= 0 {
      // Deadline is before or at alertStart, so it wraps to next day
      diff += 24 * 3600
    }

    return diff / 3600
  }

  private var dataSourceSummary: String {
    if goal.isLinkedToHealthKit {
      return goal.humanizedAutodata ?? "Apple Health"
    } else if !goal.isDataProvidedAutomatically {
      return "Connect to Apple Health"
    } else {
      return goal.humanizedAutodata ?? goal.autodata?.capitalized ?? "Autodata"
    }
  }
}

extension GoalSettingsViewController: UITableViewDataSource, UITableViewDelegate {
  func numberOfSections(in tableView: UITableView) -> Int { 1 }
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows.count }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = UITableViewCell(style: .value1, reuseIdentifier: self.cellReuseIdentifier)

    let row = rows[indexPath.row]
    switch row {
    case .notifications:
      cell.textLabel?.text = "Notifications"
      cell.detailTextLabel?.text = notificationsSummary
      cell.accessoryType = .disclosureIndicator

    case .dataSource:
      cell.textLabel?.text = "Data source"
      cell.detailTextLabel?.text = dataSourceSummary
      if isDataSourceRowTappable {
        cell.accessoryType = .disclosureIndicator
      } else {
        cell.accessoryType = .none
        cell.selectionStyle = .none
      }
    }
    return cell
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    let row = rows[indexPath.row]
    switch row {
    case .notifications: coordinator?.showConfigureNotificationsForGoal(goal)

    case .dataSource:
      if goal.isLinkedToHealthKit {
        coordinator?.showReconfigureHealthKitForGoal(goal)
      } else if !goal.isDataProvidedAutomatically {
        coordinator?.showAssociateHealthKitWithGoal(goal)
      }
    // Other autodata sources are not tappable
    }
  }
}
