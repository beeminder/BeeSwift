import BeeKit
import SnapKit
import UIKit

class WorkoutConfigurationProvider: MetricConfigurationProvider {
  let syncModeSegmentedControl = UISegmentedControl(items: ["Daily Total", "Individual Workouts"])

  var selectedWorkoutTypes: [String] = []
  var onConfigurationChanged: (() -> Void)?
  var onPushViewController: ((UIViewController) -> Void)?

  private weak var tableView: UITableView?

  init(existingConfig: [String: Any] = [:]) {
    if let types = existingConfig["workout_types"] as? [String] { selectedWorkoutTypes = types }
    let initialDailyAggregate = existingConfig["daily_aggregate"] as? Bool ?? true
    syncModeSegmentedControl.selectedSegmentIndex = initialDailyAggregate ? 0 : 1
    syncModeSegmentedControl.addTarget(self, action: #selector(syncModeChanged), for: .valueChanged)
  }

  @objc private func syncModeChanged() { onConfigurationChanged?() }

  func setTableView(_ tableView: UITableView) { self.tableView = tableView }

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

  func didSelectRow(at row: Int) { if row == 1 { showWorkoutTypeSelection() } }

  func getConfigParameters() -> [String: Any] {
    let dailyAggregate = syncModeSegmentedControl.selectedSegmentIndex == 0
    var params: [String: Any] = ["daily_aggregate": dailyAggregate]
    if !selectedWorkoutTypes.isEmpty { params["workout_types"] = selectedWorkoutTypes }
    return params
  }

  // MARK: - Private

  private func workoutTypesDetailText() -> String {
    if selectedWorkoutTypes.isEmpty {
      return "All Types"
    } else if selectedWorkoutTypes.count == 1 {
      return WorkoutActivityTypeInfo.find(byIdentifier: selectedWorkoutTypes[0])?.displayName ?? selectedWorkoutTypes[0]
    } else {
      return "\(selectedWorkoutTypes.count) types"
    }
  }

  private func showWorkoutTypeSelection() {
    let selectionVC = WorkoutTypeSelectionViewController(initialSelection: selectedWorkoutTypes)
    selectionVC.onSelectionChanged = { [weak self] types in
      guard let self = self else { return }
      self.selectedWorkoutTypes = types
      if let tableView = self.tableView { tableView.reloadRows(at: [IndexPath(row: 1, section: 1)], with: .none) }
      self.onConfigurationChanged?()
    }
    onPushViewController?(selectionVC)
  }
}
