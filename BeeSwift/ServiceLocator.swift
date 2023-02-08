//
//  ServiceLocator.swift
//  BeeSwift
//
//  Created by Theo Spears on 2/7/23.
//  Copyright © 2023 APB. All rights reserved.
//

import Foundation

class ServiceLocator {
    static let requestManager = RequestManager()
    static let signedRequestManager = SignedRequestManager(requestManager: requestManager)
    static let currentUserManager = CurrentUserManager(requestManager: requestManager)
    static let healthStoreManager = HealthStoreManager()
    static let versionManager = VersionManager(requestManager: requestManager)
}
