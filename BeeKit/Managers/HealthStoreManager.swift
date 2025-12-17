//
//  HealthStoreManager.swift
//  BeeSwift
//
//  Created by Andy Brett on 11/28/17.
//  Copyright 2017 APB. All rights reserved.
//

import CoreData
import Foundation
import HealthKit
import OSLog

public actor HealthStoreManager {
  public nonisolated let modelContainer: NSPersistentContainer
  private nonisolated let modelExecutor: CoreDataModelExecutor

  public nonisolated var unownedExecutor: UnownedSerialExecutor { modelExecutor.asUnownedSerialExecutor() }

  private var modelContext: NSManagedObjectContext { modelExecutor.context }

  /// The number of days to update when we are informed of a change. We are only called when the device is unlocked, so we must look
  /// at the previous day in case data was added after the last time the device was locked. There may also be other integrations which report
  /// data with some lag, so we look a bit further back for safety
  /// This does mean users who have very little buffer, and are not regularly unlocking their phone, may erroneously derail. There is nothing we
  /// can do about this.
  static let daysToUpdateOnChangeNotification = 7

  private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "HealthStoreManager")

  private let goalManager: GoalManager

  // TODO: Public for now to use from config
  public let healthStore = HKHealthStore()

  /// The Connection objects responsible for updating goals based on their healthkit metrics
  /// Dictionary key is the goal id, as this is stable across goal renames
  private nonisolated(unsafe) var monitors: [String: HealthKitMetricMonitor] = [:]

  /// Protect concurrent modifications to the connections dictionary
  private nonisolated let monitorsSemaphore = DispatchSemaphore(value: 1)

  init(goalManager: GoalManager, container: NSPersistentContainer) {
    self.goalManager = goalManager
    self.modelContainer = container
    let context = container.newBackgroundContext()
    context.name = "HealthStoreManager"
    self.modelExecutor = .init(context: context)
  }

  /// Request acess to HealthKit data for the supplied metric
  ///
  /// This function will throw an exception on a major failure. However, it will return silently if the user chooses
  /// not to grant read access to the specified goal - Apple does not permit apps to know if they have been
  /// granted read permission
  public func requestAuthorization(metric: HealthKitMetric) async throws {
    logger.notice("requestAuthorization for \(metric.databaseString, privacy: .public)")
    try await self.healthStore.requestAuthorization(toShare: Set(), read: [metric.sampleType()])
  }

  /// Start listening for background updates to the supplied goal if we are not already doing so
  public func ensureUpdatesRegularly(goalID: NSManagedObjectID) async throws {
    let goal = try modelContext.existingObject(with: goalID) as! Goal
    modelContext.refresh(goal, mergeChanges: false)
    guard let metricName = goal.healthKitMetric else { return }
    try await self.ensureUpdatesRegularly(metricNames: [metricName], removeMissing: false)
  }

  /// Ensure we have background update listeners for all known goals such that they
  /// will be updated any time the health data changes.
  public func ensureGoalsUpdateRegularly() async throws {
    modelContext.refreshAllObjects()
    guard let goals = goalManager.staleGoals(context: modelContext) else { return }
    let metrics = goals.compactMap { $0.healthKitMetric }.filter { $0 != "" }
    return try await ensureUpdatesRegularly(metricNames: metrics, removeMissing: true)
  }

  /// Install observers for any goals we currently have permission to read
  ///
  /// This function will never show a permissions dialog - instead it will not update for
  /// metrics where we do not have permission.
  public nonisolated func silentlyInstallObservers(context: NSManagedObjectContext) {
    logger.notice("Silently installing observer queries")

    guard let goals = goalManager.staleGoals(context: context) else { return }
    let metrics = goals.compactMap { $0.healthKitMetric }.filter { $0 != "" }
    let monitors = updateKnownMonitors(metricNames: metrics, removeMissing: true)

    for monitor in monitors { monitor.registerObserverQuery() }
  }

  /// Immediately update the supplied goal based on HealthKit's data record
  ///
  /// Any existing beeminder records for the date range provided will be updated or deleted.
  /// - Parameters:
  ///   - goal: The healthkit-connected goal to be updated
  ///   - days: How many days of history to update. Supplying 1 will update the current day.
  public func updateWithRecentData(goalID: NSManagedObjectID, days: Int) async throws {
    let goal = try modelContext.existingObject(with: goalID) as! Goal
    modelContext.refresh(goal, mergeChanges: false)
    try await updateWithRecentData(goal: goal, days: days)
    try await goalManager.refreshGoal(goalID)
  }

  /// Immediately update all known goals based on HealthKit's data record
  public func updateAllGoalsWithRecentData(days: Int) async throws {
    logger.notice("Updating all goals with recent day for last \(days, privacy: .public) days")

    // We must create this context in a backgrounfd thread as it will be used in background threads
    modelContext.refreshAllObjects()
    guard let goals = goalManager.staleGoals(context: modelContext) else { return }
    let goalsWithHealthData = goals.filter { $0.healthKitMetric != nil && $0.healthKitMetric != "" }

    try await withThrowingTaskGroup(of: Void.self) { group in
      for goal in goalsWithHealthData {
        let goalID = goal.objectID
        group.addTask {
          // This is a new thread, so we are not allowed to use the goal object from CoreData
          // TODO: This will generate lots of unneccesary reloads
          try await self.updateWithRecentData(goalID: goalID, days: days)
        }
      }
      try await group.waitForAll()
    }
    try await goalManager.refreshGoals()
  }

  private func ensureUpdatesRegularly(metricNames: any Sequence<String>, removeMissing: Bool) async throws {
    let monitors = updateKnownMonitors(metricNames: metricNames, removeMissing: removeMissing)

    var permissions = Set<HKObjectType>()
    for monitor in monitors { permissions.insert(monitor.metric.permissionType()) }
    if permissions.count > 0 {
      try await self.healthStore.requestAuthorization(toShare: Set(), read: permissions)

    }

    try await withThrowingTaskGroup(of: Void.self) { group in
      for monitor in monitors { group.addTask { try await monitor.setupHealthKit() } }
      try await group.waitForAll()
    }
  }

  private nonisolated func updateKnownMonitors(metricNames: any Sequence<String>, removeMissing: Bool)
    -> [HealthKitMetricMonitor]
  {
    monitorsSemaphore.wait()

    for metricName in metricNames {
      if monitors[metricName] == nil {
        guard let metric = HealthKitConfig.metrics.first(where: { $0.databaseString == metricName }) else {
          logger.error("No metric found for \(metricName, privacy: .public)")
          continue
        }
        monitors[metricName] = HealthKitMetricMonitor(
          healthStore: healthStore,
          metric: metric,
          onUpdate: { [weak self] metric in
            await self?.updateGoalsForMetricChange(metricName: metricName, metric: metric)
          }
        )
      }
    }

    if removeMissing {
      for (metricName, monitor) in monitors {
        if !metricNames.contains(metricName) {
          monitor.unregisterObserverQuery()
          monitors.removeValue(forKey: metricName)
        }
      }
    }

    let requestedMonitors = metricNames.compactMap { monitors[$0] }

    monitorsSemaphore.signal()
    return requestedMonitors
  }

  private func updateGoalsForMetricChange(metricName: String, metric: HealthKitMetric) async {
    do {
      modelContext.refreshAllObjects()
      guard let allGoals = goalManager.staleGoals(context: modelContext) else { return }
      let goalsForMetric = allGoals.filter { $0.healthKitMetric == metricName }
      if goalsForMetric.count == 0 {
        logger.notice("Received an update for metric \(metricName, privacy: .public) but no goals using it")
        return
      }

      for goal in goalsForMetric {
        try await self.updateWithRecentData(goal: goal, days: HealthStoreManager.daysToUpdateOnChangeNotification)
      }
    } catch { logger.error("Error updating goals for metric change: \(error, privacy: .public)") }
  }

  private func updateWithRecentData(goal: Goal, days: Int) async throws {
    guard let metric = HealthKitConfig.metrics.first(where: { $0.databaseString == goal.healthKitMetric }) else {
      throw HealthKitError("No metric found for goal \(goal.slug) with metric \(goal.healthKitMetric ?? "nil")")
    }
    let newDataPoints = try await metric.recentDataPoints(
      days: days,
      deadline: goal.deadline,
      healthStore: healthStore,
      autodataConfig: goal.autodataConfig
    )
    // TODO: In the future we should gain confidence this code is correct and remove the filter so we handle deleted data better
    let nonZeroDataPoints = newDataPoints.filter { dataPoint in dataPoint.value != 0 }
    logger.notice(
      "Updating \(metric.databaseString, privacy: .public) goal with \(nonZeroDataPoints.count, privacy: .public) datapoints. Skipped \(newDataPoints.count - nonZeroDataPoints.count, privacy: .public) empty points."
    )
    try await ServiceLocator.dataPointManager.updateToMatchDataPoints(
      goalID: goal.objectID,
      healthKitDataPoints: nonZeroDataPoints
    )
  }
}
