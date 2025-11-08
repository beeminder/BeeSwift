//
//  ServiceLocator.swift
//  BeeSwift
//
//  Created by Theo Spears on 2/7/23.
//  Copyright 2023 APB. All rights reserved.
//

import Foundation
import OSLog

public class ServiceLocator {
  private static let logger = Logger(subsystem: "com.beeminder.beeminder", category: "ServiceLocationm")

  public static let persistentContainer = BeeminderPersistentContainer.create()

  // RequestManager and CurrentUserManager have a circular dependency
  // We break it by creating both together and using property injection
  private static func createRequestManagerAndCurrentUserManager() -> (RequestManager, CurrentUserManager) {
    let requestManager = RequestManager()
    let currentUserManager = CurrentUserManager(requestManager: requestManager, container: persistentContainer)
    requestManager.currentUserManager = currentUserManager
    return (requestManager, currentUserManager)
  }

  private static let managers = createRequestManagerAndCurrentUserManager()
  public static let requestManager = managers.0
  public static let currentUserManager = managers.1

  public static let signedRequestManager = SignedRequestManager(requestManager: requestManager)

  public static let goalManager = GoalManager(
    requestManager: requestManager,
    currentUserManager: currentUserManager,
    container: persistentContainer
  )

  public static let dataPointManager = DataPointManager(requestManager: requestManager, container: persistentContainer)

  public static let healthStoreManager = HealthStoreManager(
    goalManager: goalManager,
    dataPointManager: dataPointManager,
    container: persistentContainer
  )

  public static let versionManager = VersionManager(requestManager: requestManager)

  public static let refreshManager = RefreshManager(healthStoreManager: healthStoreManager, goalManager: goalManager)
}
