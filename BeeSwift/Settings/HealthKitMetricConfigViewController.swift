import BeeKit
import Foundation
import SnapKit
import UIKit

// MARK: - MetricConfigurationProvider Protocol

protocol MetricConfigurationProvider: AnyObject {
  var numberOfRows: Int { get }
  func cell(for tableView: UITableView, at row: Int) -> UITableViewCell
  func didSelectRow(at row: Int)
  func getConfigParameters() -> [String: Any]
}

// MARK: - WorkoutConfigurationProvider

class WorkoutConfigurationProvider: MetricConfigurationProvider {
  let syncModeSegmentedControl = UISegmentedControl(items: ["Daily Total", "Individual Workouts"])

  var selectedWorkoutTypes: [String] = []
  var onConfigurationChanged: (() -> Void)?
  var onNavigateToTypeSelection: (() -> Void)?

  init(existingConfig: [String: Any] = [:]) {
    if let types = existingConfig["workout_types"] as? [String] { selectedWorkoutTypes = types }
    let initialDailyAggregate = existingConfig["daily_aggregate"] as? Bool ?? true
    syncModeSegmentedControl.selectedSegmentIndex = initialDailyAggregate ? 0 : 1
    syncModeSegmentedControl.addTarget(self, action: #selector(syncModeChanged), for: .valueChanged)
  }

  @objc private func syncModeChanged() { onConfigurationChanged?() }

  func setSelectedWorkoutTypes(_ types: [String], in tableView: UITableView) {
    selectedWorkoutTypes = types
    tableView.reloadRows(at: [IndexPath(row: 1, section: 1)], with: .none)
    onConfigurationChanged?()
  }

  // MARK: - MetricConfigurationProvider

  var numberOfRows: Int { return 2 }

  func cell(for tableView: UITableView, at row: Int) -> UITableViewCell {
    if row == 0 {
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

  func didSelectRow(at row: Int) { if row == 1 { onNavigateToTypeSelection?() } }

  func getConfigParameters() -> [String: Any] {
    let dailyAggregate = syncModeSegmentedControl.selectedSegmentIndex == 0
    var params: [String: Any] = ["daily_aggregate": dailyAggregate]
    if !selectedWorkoutTypes.isEmpty { params["workout_types"] = selectedWorkoutTypes }
    return params
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
}

// MARK: - SelfSizingTableView

private class SelfSizingTableView: UITableView {
  override var contentSize: CGSize { didSet { invalidateIntrinsicContentSize() } }

  override var intrinsicContentSize: CGSize {
    layoutIfNeeded()
    return CGSize(width: UIView.noIntrinsicMetric, height: contentSize.height)
  }
}

// MARK: - HealthKitMetricConfigViewController

class HealthKitMetricConfigViewController: UIViewController {
  fileprivate let internalTableView = SelfSizingTableView(frame: .zero, style: .insetGrouped)
  var tableView: UITableView { return internalTableView }

  private let goalName: String
  private let metricName: String
  var unitName: String? { didSet { tableView.reloadData() } }

  var configurationProvider: MetricConfigurationProvider?

  init(goalName: String, metricName: String) {
    self.goalName = goalName
    self.metricName = metricName
    super.init(nibName: nil, bundle: nil)
  }
  required init?(coder: NSCoder) { return nil }

  override func viewDidLoad() {
    super.viewDidLoad()
    setupTableView()
  }

  private func setupTableView() {
    internalTableView.delegate = self
    internalTableView.dataSource = self
    internalTableView.isScrollEnabled = false
    internalTableView.backgroundColor = .clear
    internalTableView.tableHeaderView = UIView(
      frame: CGRect(x: 0, y: 0, width: 0, height: CGFloat.leastNonzeroMagnitude)
    )
    view.addSubview(internalTableView)
    internalTableView.snp.makeConstraints { make in make.edges.equalToSuperview() }
  }

  func reloadData() { tableView.reloadData() }

  func getConfigParameters() -> [String: Any] { return configurationProvider?.getConfigParameters() ?? [:] }
}

// MARK: - UITableViewDelegate, UITableViewDataSource

extension HealthKitMetricConfigViewController: UITableViewDelegate, UITableViewDataSource {
  func numberOfSections(in tableView: UITableView) -> Int { return configurationProvider != nil ? 2 : 1 }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if section == 0 {
      return 3  // Goal Name, Apple Health Metric, Unit
    } else {
      return configurationProvider?.numberOfRows ?? 0
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
        cell.textLabel?.text = "Goal"
        cell.detailTextLabel?.text = goalName
      case 1:
        cell.textLabel?.text = "Metric"
        cell.detailTextLabel?.text = metricName
      case 2:
        cell.textLabel?.text = "Unit"
        cell.detailTextLabel?.text = unitName ?? "Loading..."
      default: break
      }
      return cell
    } else {
      return configurationProvider?.cell(for: tableView, at: indexPath.row) ?? UITableViewCell()
    }
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    if indexPath.section == 1 { configurationProvider?.didSelectRow(at: indexPath.row) }
  }

  func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    return section == 0 ? CGFloat.leastNonzeroMagnitude : UITableView.automaticDimension
  }
}
