import CoreData
import CoreDataEvolution
import Foundation
import OSLog

import SwiftyJSON

/// Read and update datapoints from the beeminder server
@NSModelActor(disableGenerateInit: true)
public actor DataPointManager {
    let logger = Logger(subsystem: "com.beeminder.beeminder", category: "DataPointManager")

    // Ignore automatic datapoint updates where the difference is a smaller fraction than this. This
    // prevents effectively no-op updates due to float rounding
    private let datapointValueEpsilon = 0.00000001

    let requestManager: RequestManager

    init(requestManager: RequestManager, container: BeeminderPersistentContainer) {
        self.requestManager = requestManager
        self.modelContainer = container
        let context = container.newBackgroundContext()
        context.name = "DataPointManager"
        modelExecutor = .init(context: context)
    }

    private func datapointsMatchingDaystamp(datapoints : [DataPoint], daystamp : Daystamp) -> [DataPoint] {
        datapoints.filter { (datapoint) -> Bool in
            return daystamp == datapoint.daystamp
        }
    }

    private func updateDatapoint(goal : Goal, datapoint : DataPoint, datapointValue : NSNumber) async throws {
        let val = datapoint.value
        if datapointValue == val {
            return
        }
        let params = [
            "value": "\(datapointValue)",
            "comment": "Auto-updated via Apple Health",
        ]
        let _ = try await requestManager.put(url: "api/v1/users/{username}/goals/\(goal.slug)/datapoints/\(datapoint.id).json", parameters: params)
    }

    private func deleteDatapoint(goal: Goal, datapoint : DataPoint) async throws {
        let _ = try await requestManager.delete(url: "api/v1/users/{username}/goals/\(goal.slug)/datapoints/\(datapoint.id)")
    }

    private func postDatapoint(goal : Goal, params : [String : String]) async throws {
        let _ = try await requestManager.post(url: "api/v1/users/{username}/goals/\(goal.slug)/datapoints.json", parameters: params)
    }

    private func fetchDatapoints(goal: Goal, sort: String, per: Int, page: Int) async throws -> [DataPoint] {
        let params = ["sort" : sort, "per" : per, "page": page] as [String : Any]
        let response = try await requestManager.get(url: "api/v1/users/{username}/goals/\(goal.slug)/datapoints.json", parameters: params)
        let responseJSON = JSON(response!)

        return responseJSON.arrayValue.map({ DataPoint.fromJSON(context: modelContext, goal: goal, json: $0) })
    }

    /// Retrieve all data points on or after the daystamp provided
    /// Estimates how many data points are needed to fetch the correct data points, and then performs additional requests if needed
    /// to guarantee all matching points have been fetched.
    private func datapointsSince(goal: Goal, daystamp: Daystamp) async throws -> [DataPoint] {
        // Estimate how many points we need, based on one point per day
        let daysSince = Daystamp.now(deadline: goal.deadline) - daystamp

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

    public func updateToMatchDataPoints(goalID: NSManagedObjectID, healthKitDataPoints : [BeeDataPoint]) async throws {
        let goal = try modelContext.existingObject(with: goalID) as! Goal
        guard let firstDaystamp = healthKitDataPoints.map({ point in point.daystamp }).min() else { return }

        let datapoints = try await datapointsSince(goal: goal, daystamp: try! Daystamp(fromString: firstDaystamp.description))
        let realDatapoints = datapoints.filter{ !$0.isMeta }

        for newDataPoint in healthKitDataPoints {
            try await self.updateToMatchDataPoint(goal: goal, newDataPoint: newDataPoint, recentDatapoints: realDatapoints)
        }
    }

    private func updateToMatchDataPoint(goal: Goal, newDataPoint : BeeDataPoint, recentDatapoints: [DataPoint]) async throws {
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

            try await postDatapoint(goal: goal, params: params)
        } else if matchingDatapoints.count >= 1 {
            let firstDatapoint = matchingDatapoints.remove(at: 0)
            for datapoint in matchingDatapoints {
                try await deleteDatapoint(goal: goal, datapoint: datapoint)
            }

            if !isApproximatelyEqual(firstDatapoint.value.doubleValue, newDataPoint.value.doubleValue) {
                logger.notice("Updating datapoint for \(goal.id) on \(firstDatapoint.daystamp, privacy: .public) from \(firstDatapoint.value) to \(newDataPoint.value)")

                try await updateDatapoint(goal: goal, datapoint: firstDatapoint, datapointValue: newDataPoint.value)
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
