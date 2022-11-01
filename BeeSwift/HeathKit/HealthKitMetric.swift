//  HealthKitMetric.swift
//  BeeSwift
//
//  Represents a metric which is possible to read from HealthKit

import Foundation
import HealthKit

protocol HealthKitMetric {
    var humanText : String { get }
    var databaseString : String { get }

    /// The permission required for this connection to read data from HealthKit
    func permissionType() -> HKObjectType
    func sampleType() -> HKSampleType

    func recentDataPoints(days : Int, deadline : Int, healthStore : HKHealthStore) async throws -> [DataPoint]

}
