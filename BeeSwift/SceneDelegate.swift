// Part of BeeSwift. Copyright Beeminder

import CoreSpotlight
import Foundation
import OSLog
import UIKit

import BeeKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    let logger = Logger(subsystem: "com.beeminder.beeminder", category: "SceneDelegate")
    
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .all))
        
        let galleryVC = GalleryViewController(
            currentUserManager: ServiceLocator.currentUserManager,
            viewContext: ServiceLocator.persistentContainer.viewContext,
            versionManager: ServiceLocator.versionManager,
            goalManager: ServiceLocator.goalManager,
            healthStoreManager: ServiceLocator.healthStoreManager,
            requestManager: ServiceLocator.requestManager
        )
        
        let navigationController = UINavigationController(rootViewController: galleryVC)
        navigationController.navigationBar.isTranslucent = false
        navigationController.navigationBar.barStyle = .black
        navigationController.navigationBar.tintColor = .white
        
        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()
    }
    
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        logger.info("\(#function)")
        
        var userInfoOfGoalFromSpotlight: [AnyHashable : Any]? {
            guard userActivity.activityType == CSSearchableItemActionType else { return nil }
            guard let goalIdentifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return nil }
            logger.info("\(#function): continuing from spotlight result, found goal with identifier: \(goalIdentifier)")
            return ["identifier": goalIdentifier]
        }
        
        var userInfoOfGoalFrom: [AnyHashable : Any]? {
            guard let goalname = userActivity.userInfo?["slug"] as? String else { return nil }
            logger.info("\(#function): continuing, found goal named: \(goalname)")
            return ["slug": goalname]
        }
        
        if let userInfo = userInfoOfGoalFromSpotlight ?? userInfoOfGoalFrom {
            logger.info("\(#function): opening goal")
            NotificationCenter.default.post(name: GalleryViewController.NotificationName.openGoal,
                                            object: nil,
                                            userInfo: userInfo)
        }
    }
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        logger.info("\(#function)")
        guard let url = URLContexts.first?.url else { return }
        
        logger.info("SceneDelegate: Received URL \(url)")
        
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            components.scheme == "beeminder",
            let goalname = components.queryItems?.first(where: { $0.name == "slug" })?.value
        else { return }
        
        NotificationCenter.default.post(name: GalleryViewController.NotificationName.openGoal,
                                        object: nil,
                                        userInfo: ["slug": goalname])
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        logger.info("\(#function)")
        Task { @MainActor in
            await ServiceLocator.refreshManager.refreshGoalsAndHealthKitData()
        }
    }

}
