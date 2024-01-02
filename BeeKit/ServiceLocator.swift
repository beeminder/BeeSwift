//
//  ServiceLocator.swift
//  BeeSwift
//
//  Created by Theo Spears on 2/7/23.
//  Copyright © 2023 APB. All rights reserved.
//

import Foundation

public class ServiceLocator {
    public static let requestManager = RequestManager()
    public static let signedRequestManager = SignedRequestManager(requestManager: requestManager)
    public static let currentUserManager = CurrentUserManager(requestManager: requestManager)
    public static let goalManager = GoalManager(requestManager: requestManager, currentUserManager: currentUserManager)
    public static let healthStoreManager = HealthStoreManager()
    public static let versionManager = VersionManager(requestManager: requestManager)
}
