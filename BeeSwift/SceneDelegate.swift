// Part of BeeSwift. Copyright Beeminder

import CoreSpotlight
import Foundation
import UIKit

import BeeKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    private var coordinator: MainCoordinator?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
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
        if userActivity.activityType == CSSearchableItemActionType {
            guard let goalIdentifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return }
            NotificationCenter.default.post(name: GalleryViewController.NotificationName.openGoal, object: nil, userInfo: ["identifier": goalIdentifier])
        } else if let intent = userActivity.interaction?.intent as? AddDataIntent {
            guard let goalSlug = intent.goal else { return }
            NotificationCenter.default.post(name: GalleryViewController.NotificationName.openGoal, object: nil, userInfo: ["slug": goalSlug])
        } else if let goalSlug = userActivity.userInfo?["slug"] {
            NotificationCenter.default.post(name: GalleryViewController.NotificationName.openGoal, object: nil, userInfo: ["slug": goalSlug])
        }
    }
}
