import Foundation
import SnapKit
import UIKit

// MARK: - MetricConfigurationProvider Protocol

protocol MetricConfigurationProvider: AnyObject {
  var numberOfRows: Int { get }
  var onConfigurationChanged: (() -> Void)? { get set }
  func cell(for tableView: UITableView, at row: Int) -> UITableViewCell
  func didSelectRow(at row: Int)
  func getConfigParameters() -> [String: Any]
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

  var onConfigurationChanged: (() -> Void)?

  var configurationProvider: MetricConfigurationProvider? {
    didSet { configurationProvider?.onConfigurationChanged = { [weak self] in self?.onConfigurationChanged?() } }
  }

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
      return 3  // Goal, Metric, Unit
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
