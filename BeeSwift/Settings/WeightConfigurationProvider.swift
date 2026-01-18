import BeeKit
import SnapKit
import UIKit

class WeightConfigurationProvider: MetricConfigurationProvider {
  let syncModeSegmentedControl = UISegmentedControl(items: ["Daily Minimum", "Individual Measurements"])

  var onConfigurationChanged: (() -> Void)?
  var onPushViewController: ((UIViewController) -> Void)?

  init(existingConfig: [String: Any] = [:]) {
    let initialDailyAggregate = existingConfig["daily_aggregate"] as? Bool ?? true
    syncModeSegmentedControl.selectedSegmentIndex = initialDailyAggregate ? 0 : 1
    syncModeSegmentedControl.addTarget(self, action: #selector(syncModeChanged), for: .valueChanged)
  }

  @objc private func syncModeChanged() { onConfigurationChanged?() }

  // MARK: - MetricConfigurationProvider

  var numberOfRows: Int { return 1 }

  func cell(for tableView: UITableView, at row: Int) -> UITableViewCell {
    let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
    cell.selectionStyle = .none
    cell.backgroundColor = .secondarySystemGroupedBackground

    syncModeSegmentedControl.removeFromSuperview()
    cell.contentView.addSubview(syncModeSegmentedControl)
    syncModeSegmentedControl.snp.makeConstraints { make in
      make.edges.equalToSuperview().inset(UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16))
    }
    return cell
  }

  func didSelectRow(at row: Int) {
    // No-op - the segmented control handles interaction
  }

  func getConfigParameters() -> [String: Any] {
    let dailyAggregate = syncModeSegmentedControl.selectedSegmentIndex == 0
    return ["daily_aggregate": dailyAggregate]
  }
}
