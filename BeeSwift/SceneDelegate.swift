// Part of BeeSwift. Copyright Beeminder

import Foundation
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .all))

        let galleryVC = GalleryViewController(
            currentUserManager: ServiceLocator.currentUserManager,
            viewContext: ServiceLocator.persistentContainer.viewContext,
            versionManager: ServiceLocator.versionManager,
            goalManager: ServiceLocator.goalManager,
            healthStoreManager: ServiceLocator.healthStoreManager
        )
        
        let navigationController = UINavigationController(rootViewController: galleryVC)
        navigationController.navigationBar.isTranslucent = false
        navigationController.navigationBar.barStyle = .black
        navigationController.navigationBar.tintColor = .white

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()
    }
}
