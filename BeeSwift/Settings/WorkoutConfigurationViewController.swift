import BeeKit
import Foundation
import SnapKit
import UIKit

private class SelfSizingTableView: UITableView {
  override var contentSize: CGSize { didSet { invalidateIntrinsicContentSize() } }

  override var intrinsicContentSize: CGSize {
    layoutIfNeeded()
    return CGSize(width: UIView.noIntrinsicMetric, height: contentSize.height)
  }
}

class WorkoutConfigurationViewController: UIViewController {
  private let tableView = SelfSizingTableView(frame: .zero, style: .insetGrouped)
  let syncModeSegmentedControl = UISegmentedControl(items: ["Daily Total", "Individual Workouts"])

  var selectedWorkoutTypes: [String] = []
  var onConfigurationChanged: (() -> Void)?
  var onNavigateToTypeSelection: (() -> Void)?

  private var initialDailyAggregate: Bool = true

  private let goalName: String
  private let metricName: String
  var unitName: String? { didSet { tableView.reloadData() } }

  init(goalName: String, metricName: String, existingConfig: [String: Any] = [:]) {
    self.goalName = goalName
    self.metricName = metricName
    super.init(nibName: nil, bundle: nil)
    if let types = existingConfig["workout_types"] as? [String] { selectedWorkoutTypes = types }
    if let dailyAggregate = existingConfig["daily_aggregate"] as? Bool { initialDailyAggregate = dailyAggregate }
  }
  required init?(coder: NSCoder) { return nil }

  override func viewDidLoad() {
    super.viewDidLoad()
    setupTableView()
    setupSegmentedControl()
  }

  private func setupTableView() {
    tableView.delegate = self
    tableView.dataSource = self
    tableView.isScrollEnabled = false
    tableView.backgroundColor = .clear
    view.addSubview(tableView)
    tableView.snp.makeConstraints { make in make.edges.equalToSuperview() }
  }

  private func setupSegmentedControl() {
    syncModeSegmentedControl.selectedSegmentIndex = initialDailyAggregate ? 0 : 1
    syncModeSegmentedControl.addTarget(self, action: #selector(syncModeChanged), for: .valueChanged)
  }

  private func workoutTypesDetailText() -> String {
    if selectedWorkoutTypes.isEmpty {
      return "All Types"
    } else if selectedWorkoutTypes.count == 1 {
      return WorkoutActivityTypeInfo.find(byIdentifier: selectedWorkoutTypes[0])?.displayName ?? selectedWorkoutTypes[0]
    } else {
      return "\(selectedWorkoutTypes.count) types"
    }
  }

  @objc private func syncModeChanged() { onConfigurationChanged?() }

  func setSelectedWorkoutTypes(_ types: [String]) {
    selectedWorkoutTypes = types
    tableView.reloadRows(at: [IndexPath(row: 1, section: 1)], with: .none)
    onConfigurationChanged?()
  }

  func getConfigParameters() -> [String: Any] {
    let dailyAggregate = syncModeSegmentedControl.selectedSegmentIndex == 0
    var params: [String: Any] = ["daily_aggregate": dailyAggregate]
    if !selectedWorkoutTypes.isEmpty { params["workout_types"] = selectedWorkoutTypes }
    return params
  }
}

extension WorkoutConfigurationViewController: UITableViewDelegate, UITableViewDataSource {
  func numberOfSections(in tableView: UITableView) -> Int { return 2 }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if section == 0 {
      return 3  // Goal Name, Apple Health Metric, Unit
    } else {
      return 2  // Sync Mode, Workout Types
    }
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if indexPath.section == 0 {
      // Info section (read-only)
      let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
      cell.selectionStyle = .none
      cell.backgroundColor = .secondarySystemGroupedBackground

      switch indexPath.row {
      case 0:
        cell.textLabel?.text = "Goal Name"
        cell.detailTextLabel?.text = goalName
      case 1:
        cell.textLabel?.text = "Apple Health Metric"
        cell.detailTextLabel?.text = metricName
      case 2:
        cell.textLabel?.text = "Unit"
        cell.detailTextLabel?.text = unitName ?? "Loading..."
      default: break
      }
      return cell
    } else if indexPath.row == 0 {
      // Sync Mode cell with segmented control
      let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
      cell.selectionStyle = .none
      cell.backgroundColor = .secondarySystemGroupedBackground

      syncModeSegmentedControl.removeFromSuperview()
      cell.contentView.addSubview(syncModeSegmentedControl)
      syncModeSegmentedControl.snp.makeConstraints { make in
        make.edges.equalToSuperview().inset(UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16))
      }
      return cell
    } else {
      // Workout Types cell with disclosure
      let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
      cell.textLabel?.text = "Workout Types"
      cell.detailTextLabel?.text = workoutTypesDetailText()
      cell.accessoryType = .disclosureIndicator
      cell.backgroundColor = .secondarySystemGroupedBackground
      return cell
    }
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    if indexPath.section == 1 && indexPath.row == 1 { onNavigateToTypeSelection?() }
  }
}
