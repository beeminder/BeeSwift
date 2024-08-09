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

    public static let persistentContainer = BeeminderPersistentContainer.create()

    public static let requestManager = RequestManager()
    public static let signedRequestManager = SignedRequestManager(requestManager: requestManager)
    public static let currentUserManager = CurrentUserManager(requestManager: requestManager, container: persistentContainer)
    public static let goalManager = GoalManager(requestManager: requestManager, currentUserManager: currentUserManager, container: persistentContainer)
    public static let dataPointManager = DataPointManager(requestManager: requestManager, container: persistentContainer)
    public static let healthStoreManager = HealthStoreManager(goalManager: goalManager, container: persistentContainer)
    public static let versionManager = VersionManager(requestManager: requestManager)
}
