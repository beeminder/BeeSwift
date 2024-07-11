import Foundation
import OSLog

import SwiftyJSON

/// Read and update datapoints from the beeminder server
public class DataPointManager {
    let logger = Logger(subsystem: "com.beeminder.beeminder", category: "DataPointManager")

    // Ignore automatic datapoint updates where the difference is a smaller fraction than this. This
    // prevents effectively no-op updates due to float rounding
    private let datapointValueEpsilon = 0.00000001

    let requestManager: RequestManager
    let container: BeeminderPersistentContainer

    init(requestManager: RequestManager, container: BeeminderPersistentContainer) {
        self.requestManager = requestManager
        self.container = container
    }

    private func fetchRecentDatapoints(goal: BeeGoal, success: @escaping ((_ datapoints : [ExistingDataPoint]) -> ()), errorCompletion: (() -> ())?) {
        Task { @MainActor in
            let params = ["sort" : "daystamp", "count" : 7] as [String : Any]
            do {
                let response = try await requestManager.get(url: "api/v1/users/{username}/goals/\(goal.slug)/datapoints.json", parameters: params)
                let responseJSON = JSON(response!)
                success(try ExistingDataPoint.fromJSONArray(array: responseJSON.arrayValue))
            } catch {
                errorCompletion?()
            }
        }
    }

    private func datapointsMatchingDaystamp(datapoints : [ExistingDataPoint], daystamp : Daystamp) -> [ExistingDataPoint] {
        datapoints.filter { (datapoint) -> Bool in
            return daystamp == datapoint.daystamp
        }
    }

    private func updateDatapoint(goal : BeeGoal, datapoint : ExistingDataPoint, datapointValue : NSNumber, success: (() -> ())?, errorCompletion: (() -> ())?) {
        Task { @MainActor in
            let val = datapoint.value
            if datapointValue == val {
                success?()
                return
            }
            let params = [
                "value": "\(datapointValue)",
                "comment": "Auto-updated via Apple Health",
            ]
            do {
                let _ = try await requestManager.put(url: "api/v1/users/{username}/goals/\(goal.slug)/datapoints/\(datapoint.id).json", parameters: params)
                success?()
            } catch {
                errorCompletion?()
            }
        }
    }

    private func deleteDatapoint(goal: BeeGoal, datapoint : ExistingDataPoint) {
        Task { @MainActor in
            do {
                let _ = try await requestManager.delete(url: "api/v1/users/{username}/goals/\(goal.slug)/datapoints/\(datapoint.id)", parameters: nil)
            } catch {
                logger.error("Error deleting datapoint: \(error)")
            }
        }
    }

    private func postDatapoint(goal : BeeGoal, params : [String : String], success : ((Any?) -> Void)?, failure : ((Error?, String?) -> Void)?) {
        Task { @MainActor in
            do {
                let response = try await requestManager.post(url: "api/v1/users/{username}/goals/\(goal.slug)/datapoints.json", parameters: params)
                success?(response)
            } catch {
                failure?(error, error.localizedDescription)
            }
        }
    }

    private func fetchDatapoints(goal: BeeGoal, sort: String, per: Int, page: Int) async throws -> [ExistingDataPoint] {
        let params = ["sort" : sort, "per" : per, "page": page] as [String : Any]
        let response = try await requestManager.get(url: "api/v1/users/{username}/goals/\(goal.slug)/datapoints.json", parameters: params)
        let responseJSON = JSON(response!)
        return try ExistingDataPoint.fromJSONArray(array: responseJSON.arrayValue)
    }

    /// Retrieve all data points on or after the daystamp provided
    /// Estimates how many data points are needed to fetch the correct data points, and then performs additional requests if needed
    /// to guarantee all matching points have been fetched.
    private func datapointsSince(goal: BeeGoal, daystamp: Daystamp) async throws -> [ExistingDataPoint] {
        // Estimate how many points we need, based on one point per day
        let daysSince = Daystamp.now(deadline: goal.deadline.intValue) - daystamp

        // We want an additional fudge factor because
        // (a) We want to include the starting day itself
        // (b) we need to receive a data point before the chosen day to make sure all possible data points for the chosen day has been fetched
        // (c) We'd rather not do multiple round trips if needed, so allow for some days having multiple data points
        var pageSize = daysSince + 5

        // While we don't have a point that preceeds the provided daystamp
        var fetchedDatapoints = try await fetchDatapoints(goal: goal, sort: "daystamp", per: pageSize, page: 1)
        if fetchedDatapoints.isEmpty {
            return []
        }

        while fetchedDatapoints.map({ point in point.daystamp }).min()! >= daystamp {
            let additionalDatapoints = try await fetchDatapoints(goal: goal, sort: "daystamp", per: pageSize, page: 2)

            // If we recieve an empty page we have fetched all points
            if additionalDatapoints.isEmpty {
                break
            }

            fetchedDatapoints.append(contentsOf: additionalDatapoints)

            // Double our page size to perform exponential fetch. This way even if our initial estimate is very wrong
            // we will not perform too many requests
            pageSize *= 2
        }

        // We will have fetched at least some points which are too old. Filter them out before returning
        return fetchedDatapoints.filter { point in point.daystamp >= daystamp }
    }

    func updateToMatchDataPoints(goal: BeeGoal, healthKitDataPoints : [BeeDataPoint]) async throws {
        guard let firstDaystamp = healthKitDataPoints.map({ point in point.daystamp }).min() else { return }

        let datapoints = try await datapointsSince(goal: goal, daystamp: try! Daystamp(fromString: firstDaystamp.description))

        for newDataPoint in healthKitDataPoints {
            try await self.updateToMatchDataPoint(goal: goal, newDataPoint: newDataPoint, recentDatapoints: datapoints)
        }
    }

    private func updateToMatchDataPoint(goal: BeeGoal, newDataPoint : BeeDataPoint, recentDatapoints: [ExistingDataPoint]) async throws {
        var matchingDatapoints = datapointsMatchingDaystamp(datapoints: recentDatapoints, daystamp: newDataPoint.daystamp)
        if matchingDatapoints.count == 0 {
            // If there are not already data points for this day, do not add points
            // from before the creation of the goal. This avoids immediate derailment
            //on do less goals, and excessive safety buffer on do-more goals.
            if newDataPoint.daystamp < goal.initDaystamp {
                return
            }

            let params = ["urtext": "\(newDataPoint.daystamp.day) \(newDataPoint.value) \"\(newDataPoint.comment)\"", "requestid": newDataPoint.requestid]

            logger.notice("Creating new datapoint for \(goal.id, privacy: .public) on \(newDataPoint.daystamp, privacy: .public): \(newDataPoint.value, privacy: .private)")

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                postDatapoint(goal: goal, params: params, success: { (responseObject) in
                    continuation.resume()
                }, failure: { (error, errorMessage) in
                    continuation.resume(throwing: error!)
                })
            }
        } else if matchingDatapoints.count >= 1 {
            let firstDatapoint = matchingDatapoints.remove(at: 0)
            matchingDatapoints.forEach { datapoint in
                deleteDatapoint(goal: goal, datapoint: datapoint)
            }

            if !isApproximatelyEqual(firstDatapoint.value.doubleValue, newDataPoint.value.doubleValue) {
                logger.notice("Updating datapoint for \(goal.id) on \(firstDatapoint.daystamp, privacy: .public) from \(firstDatapoint.value) to \(newDataPoint.value)")

                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    updateDatapoint(goal: goal, datapoint: firstDatapoint, datapointValue: newDataPoint.value, success: {
                        continuation.resume()
                    }, errorCompletion: {
                        continuation.resume(throwing: HealthKitError("Error updating data point"))
                    })
                }
            }
        }
    }

    /// Compares two datapoint values for equality, allowing a certain epsilon
    private func isApproximatelyEqual(_ first: Double, _ second: Double) -> Bool {
        // Zero is never approximately equal to another number (as a relative different makes no sense)
        if first == 0.0 && second == 0.0 {
            return true
        }
        if first == 0.0 || second == 0.0 {
            return false
        }

        let allowedDelta = ((first / 2) + (second / 2)) * datapointValueEpsilon

        return fabs(first - second) < allowedDelta
    }

}
