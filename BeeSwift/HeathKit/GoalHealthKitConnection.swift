//
//  GoalHealthKitConnection.swift
//  BeeSwift
//
//  Created by Theo Spears on 10/29/22.
//  Copyright © 2022 APB. All rights reserved.
//

import Foundation
import HealthKit

protocol GoalHealthKitConnection {
    /// The permission required for this connection to read data from HealthKit
    func hkPermissionType() -> HKObjectType

    /// Perform an initial sync and register for changes to the relevant metric so the goal can be kept up to date
    func setupHealthKit() async throws

    /// Register for changes to the relevant metric. Assumes permission and background delivery already enabled
    func registerObserverQuery()

    /// Explicitly sync goal data for the number of days specified
    func hkQueryForLast(days : Int) async throws
}
