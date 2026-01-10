// Shows a preview of a healthkit metric and allows any relevant
// settings to be configured

import BeeKit
import Foundation
import OSLog
import UIKit

class ConfigureHKMetricViewController: UIViewController {
  fileprivate let logger = Logger(subsystem: "com.beeminder.beeminder", category: "ConfigureHKMetricViewController")

  let componentMargin = 10

  private let goal: Goal
  private let metric: HealthKitMetric
  private let healthStoreManager: HealthStoreManager
  private let requestManager: RequestManager

  let previewDescriptionLabel = BSLabel()
  fileprivate var datapointTableController = DatapointTableViewController()
  fileprivate let noDataFoundLabel = BSLabel()
  private var metricConfigViewController: HealthKitMetricConfigViewController?
  private var workoutConfigProvider: WorkoutConfigurationProvider?
  let saveButton = BSButton()

  init(goal: Goal, metric: HealthKitMetric, healthStoreManager: HealthStoreManager, requestManager: RequestManager) {
    self.goal = goal
    self.metric = metric
    self.healthStoreManager = healthStoreManager
    self.requestManager = requestManager
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) { return nil }

  override func viewDidLoad() {
    super.viewDidLoad()

    self.title = self.metric.humanText
    self.view.backgroundColor = UIColor.systemBackground

    setupMetricConfiguration()

    self.view.addSubview(previewDescriptionLabel)
    previewDescriptionLabel.text = "Data Preview"
    previewDescriptionLabel.font = UIFont.beeminder.defaultBoldFont
    previewDescriptionLabel.textAlignment = .left
    previewDescriptionLabel.snp.makeConstraints { (make) in
      if let metricConfig = metricConfigViewController {
        make.top.equalTo(metricConfig.view.snp.bottom).offset(componentMargin)
      } else {
        make.top.equalTo(self.view.safeAreaLayoutGuide.snp.topMargin).offset(componentMargin)
      }
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

    self.view.addSubview(noDataFoundLabel)
    noDataFoundLabel.attributedText = {
      let text = NSMutableAttributedString()
      text.append(
        NSMutableAttributedString(
          string: "No Data Found\n\n",
          attributes: [NSAttributedString.Key.font: UIFont.beeminder.defaultBoldFont]
        )
      )
      text.append(
        NSMutableAttributedString(
          string:
            "This may be because you have not granted the app access to this data, or because there is no recent data in Apple Health.\n\n",
          attributes: [NSAttributedString.Key.font: UIFont.beeminder.defaultFont]
        )
      )
      text.append(
        NSMutableAttributedString(
          string: "You can still connect the goal, and future data will be synced if it becomes available.",
          attributes: [NSAttributedString.Key.font: UIFont.beeminder.defaultFont]
        )
      )
      return text
    }()
    noDataFoundLabel.textAlignment = .left
    noDataFoundLabel.numberOfLines = 0
    noDataFoundLabel.snp.makeConstraints { (make) in
      make.top.equalTo(datapointTableController.view.snp.bottom)
      make.left.equalTo(self.view.safeAreaLayoutGuide.snp.leftMargin).offset(componentMargin)
      make.right.equalTo(self.view.safeAreaLayoutGuide.snp.rightMargin).offset(-componentMargin)
    }
    noDataFoundLabel.isHidden = true

    self.view.addSubview(saveButton)
    saveButton.snp.makeConstraints { (make) in
      make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottomMargin).offset(-20)
      make.centerX.equalTo(self.view)
      make.width.equalTo(self.view).multipliedBy(0.5)
      make.height.equalTo(Constants.defaultTextFieldHeight)
    }
    saveButton.setTitle("Save", for: .normal)
    saveButton.addTarget(self, action: #selector(self.saveButtonPressed), for: .touchUpInside)

    self.datapointTableController.hhmmformat = self.goal.hhmmFormat
    Task { @MainActor in
      let datapoints: [BeeDataPoint]
      var currentConfig = goal.autodataConfig
      if let metricConfig = metricConfigViewController {
        let configParams = metricConfig.getConfigParameters()
        for (key, value) in configParams { currentConfig[key] = value }
      }
      datapoints = try await self.metric.recentDataPoints(
        days: 5,
        deadline: self.goal.deadline,
        healthStore: self.healthStoreManager.healthStore,
        autodataConfig: currentConfig
      )
      self.datapointTableController.datapoints = datapoints

      if datapoints.isEmpty {
        noDataFoundLabel.isHidden = false
        previewDescriptionLabel.isHidden = true
        previewDescriptionLabel.snp.makeConstraints { (make) in make.height.equalTo(0) }
      } else {
        noDataFoundLabel.snp.makeConstraints { (make) in make.height.equalTo(0) }
      }

      let units = try await self.metric.units(healthStore: self.healthStoreManager.healthStore)
      metricConfigViewController?.unitName = units.description
    }
  }

  override func viewWillAppear(_ animated: Bool) {
    // Re-allow use of the save button as we have been shown again
    saveButton.isUserInteractionEnabled = true
  }

  @objc func saveButtonPressed() {
    // Disable interaction to avoid double-taps
    saveButton.isUserInteractionEnabled = false

    Task { @MainActor in
      let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
      hud.mode = .indeterminate

      self.goal.healthKitMetric = metric.databaseString
      self.goal.autodata = "apple"

      do { try await self.healthStoreManager.ensureUpdatesRegularly(goalID: self.goal.objectID) } catch {
        logger.error("Error setting up goal \(error)")
        hud.hide(animated: true)

        // Re-enable the save button as we did not dismiss the screen
        saveButton.isUserInteractionEnabled = true
        return
      }

      var params: [String: Any] = [:]
      var iiParams: [String: Any] = ["name": "apple", "metric": self.goal.healthKitMetric!]

      if let metricConfig = metricConfigViewController {
        let configParams = metricConfig.getConfigParameters()
        for (key, value) in configParams { iiParams[key] = value }
      }

      params = ["ii_params": iiParams]

      do {
        let _ = try await self.requestManager.put(
          url: "api/v1/users/{username}/goals/\(self.goal.slug).json",
          parameters: params
        )
        hud.mode = .customView
        hud.customView = UIImageView(image: UIImage(systemName: "checkmark"))
        hud.hide(animated: true, afterDelay: 2)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
          guard
            let healthKitConfigController = self.navigationController?.viewControllers.first(where: { vc in
              vc is HealthKitConfigViewController
            })
          else {
            self.logger.error("Could not find HealthKitConfigViewController in view stack")
            return
          }
          self.navigationController?.popToViewController(healthKitConfigController, animated: true)

        }
      } catch {
        // TODO: This needs to be done somehow? Or dismiss?
        // self.tableView.reloadData()
        let errorString = error.localizedDescription
        MBProgressHUD.hide(for: self.view, animated: true)
        let alert = UIAlertController(
          title: "Error saving metric to Beeminder",
          message: errorString,
          preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)

        // Re-enable the save button as we did not dismiss the screen
        saveButton.isUserInteractionEnabled = true
      }
    }
  }

  private func setupMetricConfiguration() {
    let metricConfig = HealthKitMetricConfigViewController(goalName: goal.slug, metricName: metric.humanText)
    metricConfigViewController = metricConfig

    // Set up workout-specific configuration if applicable
    if metric is WorkoutMinutesHealthKitMetric {
      let workoutProvider = WorkoutConfigurationProvider(existingConfig: goal.autodataConfig)
      workoutConfigProvider = workoutProvider
      metricConfig.configurationProvider = workoutProvider

      workoutProvider.onConfigurationChanged = { [weak self] in
        Task { @MainActor in
          guard let self = self else { return }
          do {
            var currentConfig = self.goal.autodataConfig
            if let metricConfig = self.metricConfigViewController {
              let configParams = metricConfig.getConfigParameters()
              for (key, value) in configParams { currentConfig[key] = value }
            }
            let datapoints = try await self.metric.recentDataPoints(
              days: 5,
              deadline: self.goal.deadline,
              healthStore: self.healthStoreManager.healthStore,
              autodataConfig: currentConfig
            )
            self.datapointTableController.datapoints = datapoints
          } catch { self.logger.error("Failed to fetch preview data: \(error)") }
        }
      }
      workoutProvider.onNavigateToTypeSelection = { [weak self] in self?.showWorkoutTypeSelection() }
    }

    addChild(metricConfig)
    view.addSubview(metricConfig.view)
    metricConfig.view.setContentHuggingPriority(.required, for: .vertical)
    metricConfig.view.snp.makeConstraints { make in
      make.top.equalTo(view.safeAreaLayoutGuide.snp.topMargin)
      make.left.equalTo(view.safeAreaLayoutGuide.snp.leftMargin)
      make.right.equalTo(view.safeAreaLayoutGuide.snp.rightMargin)
    }
    metricConfig.didMove(toParent: self)
  }

  private func showWorkoutTypeSelection() {
    guard let workoutProvider = workoutConfigProvider, let metricConfig = metricConfigViewController else { return }
    let selectionVC = WorkoutTypeSelectionViewController(initialSelection: workoutProvider.selectedWorkoutTypes)
    selectionVC.onSelectionChanged = { [weak workoutProvider, weak metricConfig] types in
      guard let provider = workoutProvider, let config = metricConfig else { return }
      provider.setSelectedWorkoutTypes(types, in: config.tableView)
    }
    navigationController?.pushViewController(selectionVC, animated: true)
  }

}
