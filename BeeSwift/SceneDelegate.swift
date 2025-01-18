// Part of BeeSwift. Copyright Beeminder

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
}
