// Part of BeeSwift. Copyright Beeminder

import Foundation
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .all))

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = UINavigationController(rootViewController: GalleryViewController())
        window?.makeKeyAndVisible()
    }
}
