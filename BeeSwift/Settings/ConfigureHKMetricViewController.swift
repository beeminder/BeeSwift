// Shows a preview of a healthkit metric and allows any relevant
// settings to be configured

import BeeKit
import Foundation
import OSLog
import UIKit

class ConfigureHKMetricViewController: UIViewController {
  fileprivate let logger = Logger(subsystem: "com.beeminder.beeminder", category: "ConfigureHKMetricViewController")

  // MARK: - Layout Constants

  private enum Layout {
    static let componentMargin: CGFloat = 10
    static let buttonBottomMargin: CGFloat = -20
    static let buttonSideMargin: CGFloat = 20
    static let buttonGap: CGFloat = 10
    static let sideBySideButtonWidth: CGFloat = 0.44
    static let centeredButtonWidth: CGFloat = 0.5
  }

  // MARK: - Properties

  private let goal: Goal
  private let metric: HealthKitMetric
  private let healthStoreManager: HealthStoreManager
  private let requestManager: RequestManager
  private let goalManager: GoalManager?

  private var isRequestInFlight = false

  private var isReconfigureMode: Bool { goalManager != nil }

  let previewDescriptionLabel = BSLabel()
  fileprivate var datapointTableController = DatapointTableViewController()
  fileprivate let noDataFoundLabel = BSLabel()
  private var metricConfigViewController: HealthKitMetricConfigViewController?
  let saveButton = BSButton()
  let disconnectButton = BSButton()

  private var hasConfiguredEmptyState = false

  // MARK: - Initialization

  init(
    goal: Goal,
    metric: HealthKitMetric,
    healthStoreManager: HealthStoreManager,
    requestManager: RequestManager,
    goalManager: GoalManager? = nil
  ) {
    self.goal = goal
    self.metric = metric
    self.healthStoreManager = healthStoreManager
    self.requestManager = requestManager
    self.goalManager = goalManager
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) { return nil }

  // MARK: - View Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()

    self.title = self.metric.humanText
    self.view.backgroundColor = UIColor.systemBackground

    setupMetricConfiguration()
    setupPreviewSection()
    setupButtons()
    loadPreviewData()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    // Only re-enable buttons if no request is in flight
    if !isRequestInFlight {
      saveButton.isUserInteractionEnabled = true
      disconnectButton.isUserInteractionEnabled = true
    }
  }

  // MARK: - Setup Methods

  private func setupPreviewSection() {
    self.view.addSubview(previewDescriptionLabel)
    previewDescriptionLabel.text = "Data Preview"
    previewDescriptionLabel.font = UIFont.beeminder.defaultBoldFont
    previewDescriptionLabel.textAlignment = .left
    previewDescriptionLabel.snp.makeConstraints { make in
      if let metricConfig = metricConfigViewController {
        make.top.equalTo(metricConfig.view.snp.bottom).offset(Layout.componentMargin)
      } else {
        make.top.equalTo(self.view.safeAreaLayoutGuide.snp.topMargin).offset(Layout.componentMargin)
      }
      make.left.equalTo(self.view.safeAreaLayoutGuide.snp.leftMargin).offset(Layout.componentMargin)
      make.right.equalTo(self.view.safeAreaLayoutGuide.snp.rightMargin).offset(-Layout.componentMargin)
    }

    self.addChild(datapointTableController)
    self.view.addSubview(datapointTableController.view)
    self.datapointTableController.view.snp.makeConstraints { make in
      make.top.equalTo(previewDescriptionLabel.snp.bottom).offset(Layout.componentMargin)
      make.left.equalTo(self.view.safeAreaLayoutGuide.snp.leftMargin).offset(Layout.componentMargin)
      make.right.equalTo(self.view.safeAreaLayoutGuide.snp.rightMargin).offset(-Layout.componentMargin)
    }

    self.view.addSubview(noDataFoundLabel)
    noDataFoundLabel.attributedText = createNoDataAttributedString()
    noDataFoundLabel.textAlignment = .left
    noDataFoundLabel.numberOfLines = 0
    noDataFoundLabel.snp.makeConstraints { make in
      make.top.equalTo(datapointTableController.view.snp.bottom)
      make.left.equalTo(self.view.safeAreaLayoutGuide.snp.leftMargin).offset(Layout.componentMargin)
      make.right.equalTo(self.view.safeAreaLayoutGuide.snp.rightMargin).offset(-Layout.componentMargin)
      make.height.equalTo(0)
    }
    noDataFoundLabel.isHidden = true
  }

  private func createNoDataAttributedString() -> NSAttributedString {
    let parts: [(String, UIFont)] = [
      ("No Data Found\n\n", UIFont.beeminder.defaultBoldFont),
      (
        "This may be because you have not granted the app access to this data, or because there is no recent data in Apple Health.\n\n",
        UIFont.beeminder.defaultFont
      ),
      (
        "You can still connect the goal, and future data will be synced if it becomes available.",
        UIFont.beeminder.defaultFont
      ),
    ]

    let text = NSMutableAttributedString()
    for (string, font) in parts { text.append(NSAttributedString(string: string, attributes: [.font: font])) }
    return text
  }

  private func loadPreviewData() {
    self.datapointTableController.hhmmformat = self.goal.hhmmFormat
    Task { @MainActor in
      let currentConfig = buildCurrentConfig()
      let datapoints = try await self.metric.recentDataPoints(
        days: 5,
        deadline: self.goal.deadline,
        healthStore: self.healthStoreManager.healthStore,
        autodataConfig: currentConfig
      )
      self.datapointTableController.datapoints = datapoints
      updateEmptyState(hasData: !datapoints.isEmpty)

      let units = try await self.metric.units(healthStore: self.healthStoreManager.healthStore)
      metricConfigViewController?.unitName = units.description
    }
  }

  private func updateEmptyState(hasData: Bool) {
    guard !hasConfiguredEmptyState else { return }
    hasConfiguredEmptyState = true

    noDataFoundLabel.isHidden = hasData
    previewDescriptionLabel.isHidden = !hasData

    if hasData {
      noDataFoundLabel.snp.updateConstraints { make in make.height.equalTo(0) }
    } else {
      previewDescriptionLabel.snp.updateConstraints { make in make.height.equalTo(0) }
      noDataFoundLabel.snp.remakeConstraints { make in
        make.top.equalTo(datapointTableController.view.snp.bottom)
        make.left.equalTo(self.view.safeAreaLayoutGuide.snp.leftMargin).offset(Layout.componentMargin)
        make.right.equalTo(self.view.safeAreaLayoutGuide.snp.rightMargin).offset(-Layout.componentMargin)
      }
    }
  }

  private func buildCurrentConfig() -> [String: Any] {
    var config = goal.autodataConfig
    if let metricConfig = metricConfigViewController {
      let configParams = metricConfig.getConfigParameters()
      for (key, value) in configParams { config[key] = value }
    }
    return config
  }

  private func setupMetricConfiguration() {
    let metricConfig = HealthKitMetricConfigViewController(goalName: goal.slug, metricName: metric.humanText)
    metricConfigViewController = metricConfig

    if metric is WorkoutMinutesHealthKitMetric {
      let workoutProvider = WorkoutConfigurationProvider(existingConfig: goal.autodataConfig)
      metricConfig.configurationProvider = workoutProvider
      workoutProvider.setTableView(metricConfig.tableView)
      workoutProvider.onPushViewController = { [weak self] viewController in
        self?.navigationController?.pushViewController(viewController, animated: true)
      }
    } else if metric is WeightHealthKitMetric {
      let weightProvider = WeightConfigurationProvider(existingConfig: goal.autodataConfig)
      metricConfig.configurationProvider = weightProvider
    }

    metricConfig.onConfigurationChanged = { [weak self] in
      guard let self = self else { return }
      Task { @MainActor in
        do {
          let currentConfig = self.buildCurrentConfig()
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

  // MARK: - Button Setup

  private func setupButtons() {
    if isReconfigureMode && metric.hasAdditionalOptions {
      setupDisconnectButton(centered: false)
      setupSaveButton(sideBySide: true)
    } else if isReconfigureMode {
      setupDisconnectButton(centered: true)
    } else {
      setupSaveButton(sideBySide: false)
    }
  }

  private func setupDisconnectButton(centered: Bool) {
    view.addSubview(disconnectButton)
    disconnectButton.setTitle("Disconnect", for: .normal)
    disconnectButton.setTitleColor(.systemRed, for: .normal)
    disconnectButton.layer.borderColor = UIColor.systemRed.cgColor
    disconnectButton.addTarget(self, action: #selector(disconnectButtonPressed), for: .touchUpInside)

    disconnectButton.snp.makeConstraints { make in
      make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottomMargin).offset(Layout.buttonBottomMargin)
      make.height.equalTo(Constants.defaultTextFieldHeight)

      if centered {
        make.centerX.equalTo(view)
        make.width.equalTo(view).multipliedBy(Layout.centeredButtonWidth)
      } else {
        make.left.equalTo(view).offset(Layout.buttonSideMargin)
        make.width.equalTo(view).multipliedBy(Layout.sideBySideButtonWidth)
      }
    }
  }

  private func setupSaveButton(sideBySide: Bool) {
    view.addSubview(saveButton)
    saveButton.setTitle(isReconfigureMode ? "Save" : "Connect", for: .normal)
    saveButton.addTarget(self, action: #selector(saveButtonPressed), for: .touchUpInside)

    saveButton.snp.makeConstraints { make in
      make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottomMargin).offset(Layout.buttonBottomMargin)
      make.height.equalTo(Constants.defaultTextFieldHeight)

      if sideBySide {
        make.right.equalTo(view).offset(-Layout.buttonSideMargin)
        make.width.equalTo(view).multipliedBy(Layout.sideBySideButtonWidth)
      } else {
        make.centerX.equalTo(view)
        make.width.equalTo(view).multipliedBy(Layout.centeredButtonWidth)
      }
    }
  }

  // MARK: - Actions

  @objc func saveButtonPressed() {
    guard !isRequestInFlight else { return }
    isRequestInFlight = true
    saveButton.isUserInteractionEnabled = false

    Task { @MainActor in
      let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
      hud.mode = .indeterminate

      self.goal.healthKitMetric = metric.databaseString
      self.goal.autodata = "apple"

      do { try await self.healthStoreManager.ensureUpdatesRegularly(goalID: self.goal.objectID) } catch {
        logger.error("Error setting up goal \(error)")
        hud.hide(animated: true)
        resetRequestState()
        return
      }

      var iiParams: [String: Any] = ["name": "apple", "metric": self.goal.healthKitMetric!]
      if let metricConfig = metricConfigViewController {
        let configParams = metricConfig.getConfigParameters()
        for (key, value) in configParams { iiParams[key] = value }
      }
      let params: [String: Any] = ["ii_params": iiParams]

      do {
        let _ = try await self.requestManager.put(
          url: "api/v1/users/{username}/goals/\(self.goal.slug).json",
          parameters: params
        )
        hud.mode = .customView
        hud.customView = UIImageView(image: UIImage(systemName: "checkmark"))
        hud.hide(animated: true, afterDelay: 2)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.popToHealthKitConfig() }
      } catch {
        let errorString = error.localizedDescription
        MBProgressHUD.hide(for: self.view, animated: true)
        showErrorAlert(title: "Error saving metric to Beeminder", message: errorString)
        resetRequestState()
      }
    }
  }

  @objc func disconnectButtonPressed() {
    let alert = UIAlertController(
      title: "Disconnect from Apple Health?",
      message: "This goal will no longer receive data from Apple Health.",
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(
      UIAlertAction(title: "Disconnect", style: .destructive) { [weak self] _ in self?.performDisconnect() }
    )
    present(alert, animated: true)
  }

  private func performDisconnect() {
    guard !isRequestInFlight else { return }
    isRequestInFlight = true
    disconnectButton.isUserInteractionEnabled = false

    let params: [String: [String: String?]] = ["ii_params": ["name": nil, "metric": ""]]
    let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
    hud.mode = .indeterminate

    Task { @MainActor in
      do {
        let _ = try await self.requestManager.put(
          url: "api/v1/users/{username}/goals/\(self.goal.slug).json",
          parameters: params
        )

        if let goalManager = self.goalManager { try await goalManager.refreshGoal(self.goal.objectID) }

        hud.mode = .customView
        hud.customView = UIImageView(image: UIImage(systemName: "checkmark"))

        NotificationCenter.default.post(
          name: CurrentUserManager.NotificationName.healthKitMetricRemoved,
          object: self,
          userInfo: ["goal": self.goal as Any]
        )

        hud.hide(animated: true, afterDelay: 1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
          self.navigationController?.popViewController(animated: true)
        }
      } catch {
        logger.error("Error disconnecting metric from apple health: \(error)")
        hud.hide(animated: true)
        showErrorAlert(title: "Error disconnecting", message: error.localizedDescription)
        resetRequestState()
      }
    }
  }

  // MARK: - Helpers

  private func resetRequestState() {
    isRequestInFlight = false
    saveButton.isUserInteractionEnabled = true
    disconnectButton.isUserInteractionEnabled = true
  }

  private func showErrorAlert(title: String, message: String) {
    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: .default))
    present(alert, animated: true)
  }

  private func popToHealthKitConfig() {
    if let healthKitConfigController = navigationController?.viewControllers.first(where: {
      $0 is HealthKitConfigViewController
    }) {
      navigationController?.popToViewController(healthKitConfigController, animated: true)
    } else {
      logger.error("Could not find HealthKitConfigViewController in view stack")
      navigationController?.popViewController(animated: true)
    }
  }

}
