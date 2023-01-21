// Shows a preview of a healthkit metric and allows any relevant
// settings to be configured

import Foundation
import UIKit
import OSLog

class ConfigureHKMetricViewController : UIViewController {
    fileprivate let logger = Logger(subsystem: "com.beeminder.beeminder", category: "ConfigureHKMetricViewController")

    let componentMargin = 10

    private let goal: Goal
    private let metric: HealthKitMetric

    fileprivate var datapointTableController = DatapointTableViewController()

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

        self.title = self.metric.humanText
        self.view.backgroundColor = UIColor.systemBackground


        let previewDescriptionLabel = BSLabel()
        self.view.addSubview(previewDescriptionLabel)
        previewDescriptionLabel.attributedText = {
            let text = NSMutableAttributedString()
            text.append(NSMutableAttributedString(string: "Here is a preview of the data points which will be added to your ", attributes: [NSAttributedString.Key.font: UIFont.beeminder.defaultFont]))
            text.append(NSMutableAttributedString(string: self.goal.slug, attributes: [NSAttributedString.Key.font: UIFont.beeminder.defaultBoldFont]))
            text.append(NSMutableAttributedString(string: " goal:", attributes: [NSAttributedString.Key.font: UIFont.beeminder.defaultFont]))
            return text
        }()
        previewDescriptionLabel.textAlignment = .left
        previewDescriptionLabel.numberOfLines = 0
        previewDescriptionLabel.snp.makeConstraints { (make) in
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.topMargin).offset(componentMargin)
            make.left.equalTo(self.view.safeAreaLayoutGuide.snp.leftMargin).offset(componentMargin)
            make.right.equalTo(self.view.safeAreaLayoutGuide.snp.rightMargin).offset(-componentMargin)
        }

        self.addChild(datapointTableController)
        self.view.addSubview(datapointTableController.view)
        self.datapointTableController.view.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(previewDescriptionLabel.snp.bottom).offset(componentMargin)
            make.left.equalTo(self.view.safeAreaLayoutGuide.snp.leftMargin).offset(componentMargin)
            make.right.equalTo(self.view.safeAreaLayoutGuide.snp.rightMargin).offset(-componentMargin)
        }

        let unitsLabel = BSLabel()
        self.view.addSubview(unitsLabel)
        unitsLabel.textAlignment = .left
        unitsLabel.numberOfLines = 0
        unitsLabel.snp.makeConstraints { (make) in
            make.top.equalTo(datapointTableController.view.snp.bottom).offset(componentMargin)
            make.left.equalTo(self.view.safeAreaLayoutGuide.snp.leftMargin).offset(componentMargin)
            make.right.equalTo(self.view.safeAreaLayoutGuide.snp.rightMargin).offset(-componentMargin)
        }

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

        self.datapointTableController.hhmmformat = self.goal.hhmmformat
        Task { @MainActor in
            let datapoints = try await self.metric.recentDataPoints(days: 5, deadline: self.goal.deadline.intValue, healthStore: HealthStoreManager.sharedManager.healthStore)
            self.datapointTableController.datapoints = datapoints

            let units = try await self.metric.units(healthStore: HealthStoreManager.sharedManager.healthStore)

            unitsLabel.attributedText = {
                let text = NSMutableAttributedString()
                text.append(NSMutableAttributedString(string: "This metric reports results as ", attributes: [NSAttributedString.Key.font: UIFont.beeminder.defaultFont]))
                text.append(NSMutableAttributedString(string: units.description, attributes: [NSAttributedString.Key.font: UIFont.beeminder.defaultBoldFont]))
                return text
            }()
        }
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
                    guard let healthKitConfigController = self.navigationController?.viewControllers.first(where: { vc in vc is HealthKitConfigViewController }) else {
                        self.logger.error("Could not find HealthKitConfigViewController in view stack")
                        return
                    }
                    self.navigationController?.popToViewController(healthKitConfigController, animated: true)

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
