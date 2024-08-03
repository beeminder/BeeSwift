import Foundation
import SwiftyJSON
import HealthKit
import OSLog

/// Monitor a specific HealthKit metric and report when it changes
class HealthKitMetricMonitor {
    static let minimumIntervalBetweenObserverUpdates : TimeInterval = 5 // Seconds

    private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "HealthKitMetricMonitor")
    private let healthStore: HKHealthStore
    private let metric : HealthKitMetric
    private let onUpdate: (HealthKitMetric) async -> Void

    private var observerQuery : HKObserverQuery? = nil
    private var lastObserverUpdate : Date? = nil

    init(healthStore: HKHealthStore, metric: HealthKitMetric, onUpdate: @escaping (HealthKitMetric) async -> Void) {
        self.healthStore = healthStore
        self.metric = metric
        self.onUpdate = onUpdate
    }

    /// Perform an initial sync and register for changes to the relevant metric so the goal can be kept up to date
    public func setupHealthKit() async throws {
        try await healthStore.enableBackgroundDelivery(for: metric.sampleType(), frequency: HKUpdateFrequency.immediate)
        registerObserverQuery()
    }

    /// Register for changes to the relevant metric. Assumes permission and background delivery already enabled
    public func registerObserverQuery() {
        guard observerQuery == nil else {
            return
        }
        logger.notice("Registering observer query for \(self.metric.databaseString, privacy: .public)")

        let query = HKObserverQuery(sampleType: metric.sampleType(), predicate: nil, updateHandler: { (query, completionHandler, error) in
            self.logger.notice("ObserverQuery response for \(self.metric.databaseString, privacy: .public)")

            guard error == nil else {
                self.logger.error("ObserverQuery for \(self.metric.databaseString, privacy: .public) was error: \(error, privacy: .public)")
                return
            }

            if let lastUpdate = self.lastObserverUpdate {
                if Date().timeIntervalSince(lastUpdate) < HealthKitMetricMonitor.minimumIntervalBetweenObserverUpdates {
                    self.logger.notice("Ignoring update to \(self.metric.databaseString, privacy: .public) due to recent previous update")
                    completionHandler()
                    return
                }
            }
            self.lastObserverUpdate = Date()

            Task {
                await self.onUpdate(self.metric)
                completionHandler()
            }
        })
        healthStore.execute(query)

        // Once we have successfully executed the query then keep track of it to stop later
        self.observerQuery = query
    }

    /// Remove any registered queries to prevent further updates
    public func unregisterObserverQuery() {
        guard let query = self.observerQuery else {
            logger.warning("unregisterObserverQuery(\(self.metric.databaseString, privacy: .public)): Attempted to unregister query when not registered")
            return
        }
        logger.notice("Unregistering observer query for \(self.metric.databaseString, privacy: .public)")

        healthStore.stop(query)
    }
}

