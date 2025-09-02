import Foundation
import UIKit
import SnapKit
import BeeKit

class WorkoutConfigurationViewController: UIViewController {
    
    private let goal: Goal
    let syncModeSegmentedControl = UISegmentedControl(items: ["Daily Total", "Individual Workouts"])
    var onConfigurationChanged: (() -> Void)?
    
    init(goal: Goal) {
        self.goal = goal
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        return nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupSegmentedControl()
    }
    
    private func setupSegmentedControl() {
        view.addSubview(syncModeSegmentedControl)
        
        let dailyAggregate = goal.autodataConfig["daily_aggregate"] as? Bool ?? true
        syncModeSegmentedControl.selectedSegmentIndex = dailyAggregate ? 0 : 1
        
        syncModeSegmentedControl.snp.makeConstraints { make in
            make.top.equalTo(view.snp.top)
            make.left.equalTo(view.snp.left)
            make.right.equalTo(view.snp.right)
            make.height.equalTo(32)
            make.bottom.equalTo(view.snp.bottom)
        }
        
        syncModeSegmentedControl.addTarget(self, action: #selector(syncModeChanged), for: .valueChanged)
    }
    
    @objc private func syncModeChanged() {
        onConfigurationChanged?()
    }
    
    func getCurrentConfig() -> [String: Any] {
        var config = goal.autodataConfig
        let dailyAggregate = syncModeSegmentedControl.selectedSegmentIndex == 0
        config["daily_aggregate"] = dailyAggregate
        return config
    }
    
    func getConfigParameters() -> [String: Any] {
        let dailyAggregate = syncModeSegmentedControl.selectedSegmentIndex == 0
        return ["daily_aggregate": dailyAggregate]
    }
}