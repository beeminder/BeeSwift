// Part of BeeSwift. Copyright Beeminder

import BeeKit
import Foundation
import OSLog
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  let logger = Logger(subsystem: "com.beeminder.beeminder", category: "SceneDelegate")
  var window: UIWindow?
  private var coordinator: MainCoordinator?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = (scene as? UIWindowScene) else { return }
    windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .all))

    let navigationController = UINavigationController()
    self.coordinator = MainCoordinator(
      navigationController: navigationController,
      currentUserManager: ServiceLocator.currentUserManager,
      viewContext: ServiceLocator.persistentContainer.viewContext,
      versionManager: ServiceLocator.versionManager,
      goalManager: ServiceLocator.goalManager,
      healthStoreManager: ServiceLocator.healthStoreManager,
      requestManager: ServiceLocator.requestManager
    )
    window = UIWindow(windowScene: windowScene)
    window?.rootViewController = navigationController
    window?.makeKeyAndVisible()
    coordinator?.start()
  }
  func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    logger.info("\(#function)")
    // Spotlight results are handled by OpenGoalIntent (via OpenIntent conformance)
    // This handles other NSUserActivity continuations (e.g., Handoff)
    guard let goalname = userActivity.userInfo?["slug"] as? String else { return }
    logger.info("\(#function): continuing, found goal named: \(goalname)")
    NotificationCenter.default.post(
      name: GalleryViewController.NotificationName.openGoal,
      object: nil,
      userInfo: ["slug": goalname]
    )
  }
  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    logger.info("\(#function)")
    guard let url = URLContexts.first?.url else { return }
    logger.info("SceneDelegate: Received URL \(url)")
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false), components.scheme == "beeminder",
      let goalname = components.queryItems?.first(where: { $0.name == "slug" })?.value
    else { return }
    NotificationCenter.default.post(
      name: GalleryViewController.NotificationName.openGoal,
      object: nil,
      userInfo: ["slug": goalname]
    )
  }
  func sceneWillEnterForeground(_ scene: UIScene) {
    logger.info("\(#function)")
    Task { @MainActor in await ServiceLocator.refreshManager.refreshGoalsAndHealthKitData() }
  }

}
