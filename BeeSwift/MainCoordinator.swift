import BeeKit
import CoreData
import UIKit

class MainCoordinator {
  private let navigationController: UINavigationController
  private let currentUserManager: CurrentUserManager
  private let viewContext: NSManagedObjectContext
  private let versionManager: VersionManager
  private let goalManager: GoalManager
  private let healthStoreManager: HealthStoreManager
  private let requestManager: RequestManager
  init(
    navigationController: UINavigationController,
    currentUserManager: CurrentUserManager,
    viewContext: NSManagedObjectContext,
    versionManager: VersionManager,
    goalManager: GoalManager,
    healthStoreManager: HealthStoreManager,
    requestManager: RequestManager
  ) {
    self.navigationController = navigationController
    self.currentUserManager = currentUserManager
    self.viewContext = viewContext
    self.versionManager = versionManager
    self.goalManager = goalManager
    self.healthStoreManager = healthStoreManager
    self.requestManager = requestManager
    setUpNotifications()
  }
  private func setUpNotifications() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleSignIn),
      name: CurrentUserManager.NotificationName.signedIn,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleSignOut),
      name: CurrentUserManager.NotificationName.signedOut,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(openGoalFromNotification(_:)),
      name: GalleryViewController.NotificationName.openGoal,
      object: nil
    )
  }
  func start() {
    let galleryVC = GalleryViewController(
      currentUserManager: currentUserManager,
      viewContext: viewContext,
      versionManager: versionManager,
      goalManager: goalManager,
      healthStoreManager: healthStoreManager,
      requestManager: requestManager,
      coordinator: self
    )
    navigationController.setViewControllers([galleryVC], animated: false)
    navigationController.navigationBar.isTranslucent = false
    navigationController.navigationBar.barStyle = .black
    navigationController.navigationBar.tintColor = .white
    if !currentUserManager.signedIn(context: viewContext) { showSignIn() }
  }
  func showGoal(_ goal: Goal) {
    let goalViewController = GoalViewController(
      goal: goal,
      healthStoreManager: healthStoreManager,
      goalManager: goalManager,
      requestManager: requestManager,
      currentUserManager: currentUserManager,
      viewContext: viewContext,
      coordinator: self
    )
    navigationController.pushViewController(goalViewController, animated: true)
  }
  func showSettings() {
    let settingsVC = SettingsViewController(
      currentUserManager: currentUserManager,
      viewContext: viewContext,
      goalManager: goalManager,
      requestManager: requestManager,
      coordinator: self
    )
    navigationController.pushViewController(settingsVC, animated: true)
  }
  func showSignIn() {
    let signInVC = SignInViewController(currentUserManager: currentUserManager, coordinator: self)
    signInVC.modalPresentationStyle = .fullScreen
    navigationController.present(signInVC, animated: true)
  }
  func showTimerForGoal(_ goal: Goal) {
    let controller = TimerViewController(goal: goal, requestManager: requestManager)
    controller.modalPresentationStyle = .fullScreen
    navigationController.present(controller, animated: true, completion: nil)
  }
  func showChooseGallerySortAlgorithm() {
    let controller = ChooseGoalSortViewController()
    navigationController.pushViewController(controller, animated: true)
  }
  func showConfigureNotifications() {
    let controller = ConfigureNotificationsViewController(
      goalManager: goalManager,
      viewContext: viewContext,
      currentUserManager: currentUserManager,
      requestManager: requestManager,
      coordinator: self
    )
    navigationController.pushViewController(controller, animated: true)
  }
  func showConfigureHealthKitIntegration() {
    let controller = HealthKitConfigViewController(
      goalManager: goalManager,
      viewContext: viewContext,
      healthStoreManager: ServiceLocator.healthStoreManager,
      requestManager: requestManager,
      coordinator: self
    )
    navigationController.pushViewController(controller, animated: true)
  }
  func showReconfigureHealthKitForGoal(_ goal: Goal) {
    guard let metric = HealthKitConfig.metrics.first(where: { $0.databaseString == goal.healthKitMetric }) else {
      let alert = UIAlertController(
        title: "Unknown Metric",
        message: "Unable to find configuration for this Apple Health metric. The metric may no longer be supported.",
        preferredStyle: .alert
      )
      alert.addAction(UIAlertAction(title: "OK", style: .default))
      navigationController.present(alert, animated: true)
      return
    }
    let controller = ConfigureHKMetricViewController(
      goal: goal,
      metric: metric,
      healthStoreManager: healthStoreManager,
      requestManager: requestManager,
      goalManager: goalManager
    )
    navigationController.pushViewController(controller, animated: true)
  }
  func showAssociateHealthKitWithGoal(_ goal: Goal) {
    let chooseHKMetricViewController = ChooseHKMetricViewController(
      goal: goal,
      healthStoreManager: healthStoreManager,
      requestManager: requestManager,
      coordinator: self
    )
    navigationController.pushViewController(chooseHKMetricViewController, animated: true)
  }
  func showConfigureNotificationsForGoal(_ goal: Goal) {
    let controller = EditGoalNotificationsViewController(
      goal: goal,
      currentUserManager: currentUserManager,
      requestManager: requestManager,
      goalManager: goalManager,
      viewContext: viewContext
    )
    navigationController.pushViewController(controller, animated: true)
  }
  func showGoalSettings(_ goal: Goal) {
    let controller = GoalSettingsViewController(
      goal: goal,
      currentUserManager: currentUserManager,
      requestManager: requestManager,
      goalManager: goalManager,
      coordinator: self
    )
    navigationController.pushViewController(controller, animated: true)
  }
  func showConfigureDefaultNotifications() {
    let controller = EditDefaultNotificationsViewController(
      currentUserManager: currentUserManager,
      requestManager: requestManager,
      goalManager: goalManager,
      viewContext: viewContext
    )
    navigationController.pushViewController(controller, animated: true)
  }
  func showConfigureHKMetricForGoal(_ goal: Goal, _ metric: HealthKitMetric) {
    let controller = ConfigureHKMetricViewController(
      goal: goal,
      metric: metric,
      healthStoreManager: healthStoreManager,
      requestManager: requestManager
    )
    navigationController.pushViewController(controller, animated: true)
  }
  func showEditDatapointForGoal(goal: Goal, datapoint: DataPoint) {
    let editDatapointViewController = EditDatapointViewController(
      goal: goal,
      datapoint: datapoint,
      requestManager: self.requestManager,
      goalManager: self.goalManager
    )

    let navigationController = UINavigationController(rootViewController: editDatapointViewController)
    navigationController.modalPresentationStyle = .formSheet
    self.navigationController.present(navigationController, animated: true, completion: nil)
  }
  func showLogs() {
    let controller = LogsViewController()
    navigationController.pushViewController(controller, animated: true)
  }
  @objc private func handleSignIn() {
    navigationController.dismiss(animated: true)
    navigationController.popToRootViewController(animated: true)
    start()
  }
  @objc private func handleSignOut() {
    navigationController.popToRootViewController(animated: true)
    showSignIn()
  }
  @objc private func openGoalFromNotification(_ notification: Notification) {
    var goalFromID: Goal? {
      guard let identifier = notification.userInfo?["identifier"] as? String else { return nil }
      guard let url = URL(string: identifier),
        let objectID = viewContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url)
      else { return nil }
      return viewContext.object(with: objectID) as? Goal
    }
    var goalFromSlug: Goal? {
      guard let slug = notification.userInfo?["slug"] as? String,
        let user = currentUserManager.user(context: viewContext)
      else { return nil }
      return user.goals.first { $0.slug == slug }
    }
    if let goal = goalFromID ?? goalFromSlug {
      navigationController.popToRootViewController(animated: false)
      showGoal(goal)
    }
  }
}
