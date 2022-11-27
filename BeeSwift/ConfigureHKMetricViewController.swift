// Shows a preview of a healthkit metric and allows any relevant
// settings to be configured

import Foundation
import UIKit
import OSLog

class ConfigureHKMetricViewController : UIViewController {
    fileprivate let logger = Logger(subsystem: "com.beeminder.beeminder", category: "ConfigureHKMetricViewController")

    private let goal: Goal
    private let metric: HealthKitMetric

    init(goal: Goal, metric : HealthKitMetric) {
        self.goal = goal
        self.metric = metric
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = UIColor.systemBackground

        let saveButton = BSButton()
        self.view.addSubview(saveButton)
        saveButton.snp.makeConstraints { (make) in
            make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottomMargin).offset(-20)
            make.centerX.equalTo(self.view)
            make.width.equalTo(self.view).multipliedBy(0.5)
            make.height.equalTo(Constants.defaultTextFieldHeight)
        }
        saveButton.setTitle("Save", for: .normal)
        saveButton.addTarget(self, action: #selector(self.saveButtonPressed), for: .touchUpInside)
    }

    @objc func saveButtonPressed() {
        Task { @MainActor in
            let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
            hud?.mode = .indeterminate

            self.goal.healthKitMetric = metric.databaseString
            self.goal.autodata = "apple"

            do {
                try await HealthStoreManager.sharedManager.ensureUpdatesRegularly(goal: self.goal)
            } catch {
                logger.error("Error setting up goal \(error)")
                hud?.hide(true)
                return
            }

            var params : [String : [String : String]] = [:]
            params = ["ii_params" : ["name" : "apple", "metric" : self.goal.healthKitMetric!]]

            do {
                let _ = try await RequestManager.put(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!)/goals/\(self.goal.slug).json", parameters: params)
                hud?.mode = .customView
                hud?.customView = UIImageView(image: UIImage(named: "checkmark"))
                hud?.hide(true, afterDelay: 2)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    // TODO: Do something better here?
                    self.navigationController?.popViewController(animated: true)
                    self.navigationController?.popViewController(animated: true)
                }
            } catch {
                // TODO: This needs to be done somehow? Or dismiss?
                // self.tableView.reloadData()
                let errorString = error.localizedDescription
                MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
                let alert = UIAlertController(title: "Error saving metric to Beeminder", message: errorString, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
        }
    }

}
