//
//  JSONGoal+Healthkit.swift
//  BeeSwift
//
//  Created by Andrew Brett on 11/14/21.
//  Copyright © 2021 APB. All rights reserved.
//

import Foundation
import SwiftyJSON
import HealthKit
import OSLog

typealias DataPoint = (daystamp: String, value: Double, comment: String)

class BaseGoalHealthKitConnection : GoalHealthKitConnection {
    private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "GoalHealthKitConnection")
    let healthStore: HKHealthStore
    let goal : JSONGoal

    var haveRegisteredObserverQuery = false

    init(healthStore: HKHealthStore, goal: JSONGoal) {
        self.healthStore = healthStore
        self.goal = goal
    }

    public func hkQueryForLast(days : Int) async throws {
        preconditionFailure("This method must be overridden")
    }

    internal func hkSampleType() -> HKSampleType? {
        preconditionFailure("This method must be overridden")
    }

    func hkPermissionType() -> HKObjectType? {
        preconditionFailure("This method must be overridden")
    }

    func setupHealthKit() async throws {
        guard let sampleType = self.hkSampleType() else { return }
        try await healthStore.enableBackgroundDelivery(for: sampleType, frequency: HKUpdateFrequency.immediate)
        registerObserverQuery()
    }

    func registerObserverQuery() {
        logger.notice("registerObserverQuery(\(self.goal.healthKitMetric ?? "nil", privacy: .public)): requested")

        if haveRegisteredObserverQuery {
            logger.notice("registerObserverQuery(\(self.goal.healthKitMetric ?? "nil", privacy: .public)): skipping because done before")
            return
        }

        guard let sampleType = self.hkSampleType() else { return }
        let query = HKObserverQuery(sampleType: sampleType, predicate: nil, updateHandler: { (query, completionHandler, error) in
            self.logger.notice("ObserverQuery for \(self.goal.healthKitMetric ?? "nil", privacy: .public) received update query \(query, privacy: .public) error \(error, privacy: .public)")
            Task {
                do {
                    try await self.hkQueryForLast(days: 1)
                    completionHandler()
                } catch {
                    self.logger.error("Error fetching data in response to observer query \(query) error: \(error)")
                }
            }
        })
        healthStore.execute(query)

        haveRegisteredObserverQuery = true

        logger.notice("registerObserverQuery(\(self.goal.healthKitMetric ?? "nil", privacy: .public)): done")
    }
    
    internal func predicateForDayOffset(dayOffset : Int) -> NSPredicate? {
        let bounds = dateBoundsForDayOffset(dayOffset: dayOffset)
        return HKQuery.predicateForSamples(withStart: bounds[0], end: bounds[1], options: .strictEndDate)
    }
    
    internal func dateBoundsForDayOffset(dayOffset : Int) -> [Date] {
        let calendar = Calendar.current
        
        let components = calendar.dateComponents(in: TimeZone.current, from: Date())
        let localMidnightThisMorning = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: calendar.date(from: components)!)
        let localMidnightTonight = calendar.date(byAdding: .day, value: 1, to: localMidnightThisMorning!)
        
        let endOfToday = calendar.date(byAdding: .second, value: self.goal.deadline.intValue, to: localMidnightTonight!)
        let startOfToday = calendar.date(byAdding: .second, value: self.goal.deadline.intValue, to: localMidnightThisMorning!)
        
        guard let startDate = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday!) else { return [] }
        guard let endDate = calendar.date(byAdding: .day, value: dayOffset, to: endOfToday!) else { return [] }
        
        return [startDate, endDate]
    }
    
    internal func dayStampFromDayOffset(dayOffset : Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let bounds = self.dateBoundsForDayOffset(dayOffset: dayOffset)
        let datapointDate = (self.goal.deadline.intValue >= 0 && self.goal.healthKitMetric != "timeAsleep" && self.goal.healthKitMetric != "timeInBed") ? bounds[0] : bounds[1]
        return formatter.string(from: datapointDate)
    }

    internal func updateBeeminderWithValue(datapointValue : Double, daystamp : String) async throws {
        if datapointValue == 0  {
            return
        }

        let datapoints = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[JSON], Error>) in
            self.goal.fetchRecentDatapoints(success: { datapoints in
                continuation.resume(returning: datapoints)
            }, errorCompletion: {
                continuation.resume(throwing: RuntimeError("Could not fetch recent datapoints"))
            })
        }
        try await self.updateBeeminderWithValue(datapointValue: datapointValue, daystamp: daystamp, recentDatapoints: datapoints)
    }

    internal func updateBeeminderWithValue(datapointValue : Double, daystamp : String, recentDatapoints: [JSON]) async throws {
        logger.notice("updateBeeminderWithValue(\(self.goal.healthKitMetric ?? "nil", privacy: .public)): Daystamp \(daystamp, privacy: .public) value \(datapointValue, privacy: .public)")
        if datapointValue == 0  {
            return
        }

        var matchingDatapoints = self.goal.datapointsMatchingDaystamp(datapoints: recentDatapoints, daystamp: daystamp)
        if matchingDatapoints.count == 0 {
            logger.notice("updateBeeminderWithValue(\(self.goal.healthKitMetric ?? "nil", privacy: .public)): Creating new point (none match)")

            let requestId = "\(daystamp)-\(self.goal.minuteStamp())"
            let params = ["access_token": CurrentUserManager.sharedManager.accessToken!, "urtext": "\(daystamp.suffix(2)) \(datapointValue) \"Auto-entered via Apple Health\"", "requestid": requestId]

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                self.goal.postDatapoint(params: params, success: { (responseObject) in
                    continuation.resume()
                }, failure: { (error, errorMessage) in
                    self.logger.error("updateBeeminderWithValue(\(self.goal.healthKitMetric ?? "nil", privacy: .public)): Error creating new point: \(error, privacy: .public) - \(errorMessage ?? "nil", privacy: .public)")
                    continuation.resume(throwing: error!)
                })
            }


        } else if matchingDatapoints.count >= 1 {
            let firstDatapoint = matchingDatapoints.remove(at: 0)
            matchingDatapoints.forEach { datapoint in
                logger.notice("updateBeeminderWithValue(\(self.goal.healthKitMetric ?? "nil", privacy: .public)): Deleting data point \(datapoint["id"].string ?? "nil", privacy: .public)")
                self.goal.deleteDatapoint(datapoint: datapoint)
            }

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                logger.notice("updateBeeminderWithValue(\(self.goal.healthKitMetric ?? "nil", privacy: .public)): Updating data point \(firstDatapoint["id"].string ?? "nil", privacy: .public) with value \(datapointValue, privacy: .public)")
                self.goal.updateDatapoint(datapoint: firstDatapoint, datapointValue: datapointValue, success: {
                    continuation.resume()
                }, errorCompletion: {
                    self.logger.error("updateBeeminderWithValue(\(self.goal.healthKitMetric ?? "nil", privacy: .public)): Error updating point")
                    continuation.resume(throwing: RuntimeError("Error updating data point"))
                })
            }
        }
    }

    internal func updateBeeminderToMatchDataPoints(healthKitDataPoints : [DataPoint]) async throws {
        let datapoints = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[JSON], Error>) in
            self.goal.fetchRecentDatapoints(success: { datapoints in
                continuation.resume(returning: datapoints)
            }, errorCompletion: {
                continuation.resume(throwing: RuntimeError("Could not fetch recent datapoints"))
            })
        }

        for (daystamp, newValue, comment) in healthKitDataPoints {
            // TODO: Take comment as input
            try await self.updateBeeminderWithValue(datapointValue: newValue, daystamp: daystamp, recentDatapoints: datapoints)
        }
    }
}


// TODO: More descriptive error?
struct RuntimeError: Error {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    public var localizedDescription: String {
        return message
    }
}
