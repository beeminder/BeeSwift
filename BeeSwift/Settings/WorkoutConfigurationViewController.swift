import BeeKit
import Foundation
import SnapKit
import UIKit

class WorkoutConfigurationViewController: UIViewController {
  let syncModeSegmentedControl = UISegmentedControl(items: ["Daily Total", "Individual Workouts"])
  var onConfigurationChanged: (() -> Void)?
  init() { super.init(nibName: nil, bundle: nil) }
  required init?(coder: NSCoder) { return nil }
  override func viewDidLoad() {
    super.viewDidLoad()
    setupSegmentedControl()
  }
  private func setupSegmentedControl() {
    view.addSubview(syncModeSegmentedControl)
    syncModeSegmentedControl.selectedSegmentIndex = 0
    syncModeSegmentedControl.snp.makeConstraints { make in
      make.top.equalTo(view.snp.top)
      make.left.equalTo(view.snp.left)
      make.right.equalTo(view.snp.right)
      make.height.equalTo(32)
      make.bottom.equalTo(view.snp.bottom)
    }
    syncModeSegmentedControl.addTarget(self, action: #selector(syncModeChanged), for: .valueChanged)
  }
  @objc private func syncModeChanged() { onConfigurationChanged?() }
  func getConfigParameters() -> [String: Any] {
    let dailyAggregate = syncModeSegmentedControl.selectedSegmentIndex == 0
    return ["daily_aggregate": dailyAggregate]
  }
}
