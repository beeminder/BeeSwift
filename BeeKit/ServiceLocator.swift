//
//  ServiceLocator.swift
//  BeeSwift
//
//  Created by Theo Spears on 2/7/23.
//  Copyright © 2023 APB. All rights reserved.
//

import Foundation
import OSLog

public class ServiceLocator {
    private static let logger = Logger(subsystem: "com.beeminder.beeminder", category: "ServiceLocationm")

    static let persistentContainer: BeeminderPersistentContainer = {
        let container = BeeminderPersistentContainer(name: "BeeminderModel")
        container.loadPersistentStores { description, error in
            if let error = error {
                logger.error("Unable to load persistent stores: \(error, privacy: .public)")
                // TODO: Reconsider this approach after we use this data for real
                try! FileManager.default.removeItem(at: BeeminderPersistentContainer.defaultDirectoryURL())
                container.loadPersistentStores { description, error in
                    if let error = error {
                        fatalError("Unable to load persistent stores on retry: \(error)")
                    }
                }
            }
        }
        return container
    }()

    public static let requestManager = RequestManager()
    public static let signedRequestManager = SignedRequestManager(requestManager: requestManager)
    public static let currentUserManager = CurrentUserManager(requestManager: requestManager, container: persistentContainer)
    public static let goalManager = GoalManager(requestManager: requestManager, currentUserManager: currentUserManager, container: persistentContainer)
    public static let healthStoreManager = HealthStoreManager()
    public static let versionManager = VersionManager(requestManager: requestManager)
}
