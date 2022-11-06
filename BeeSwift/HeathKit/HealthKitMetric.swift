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

    /// The sampleType to use for observer queries and register for background delivery
    func sampleType() -> HKSampleType

    /// Recent data points for this metric from Apple Health
    ///
    /// - Parameters:
    ///   - days: How many days of history to fetch. Passing 1 will fetch only data for the current day
    ///   - deadline: The time of day of the goal's deadline. 0 is midnight, and can be positive or negative. Impacts what day samples are counted against
    ///   - healthStore: A HKHealthStore instance to use for querying data
    ///
    /// - Returns: A list of DataPoint objects containing values for the provided date range. May or may not include 0 values if there is no data. Values are not guaranteed to be in order.
    func recentDataPoints(days : Int, deadline : Int, healthStore : HKHealthStore) async throws -> [DataPoint]

}
