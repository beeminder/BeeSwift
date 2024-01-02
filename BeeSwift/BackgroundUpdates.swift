import Foundation
import BackgroundTasks
import OSLog

import BeeKit

class BackgroundUpdates {
    fileprivate let logger = Logger(subsystem: "com.beeminder.beeminder", category: "BackgroundUpdates")
    let backgroundTaskIdentifier = "com.beeminder.beeminder.goals.refresh"
    let maximuimRefreshInterval = TimeInterval(15 * 60)

    /// Install a background update handler to refresh goals, and arrange for it to be called regularly
    func startUpdatingRegularlyInBackground() {
        register()
        scheduleAppRefresh()
    }

    private func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
             self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
    }

    private func scheduleAppRefresh() {
       let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
       request.earliestBeginDate = Date(timeIntervalSinceNow: maximuimRefreshInterval)

       do {
          try BGTaskScheduler.shared.submit(request)
       } catch {
           logger.error("Could not schedule app refresh: \(error)")
       }
    }

    private func handleAppRefresh(task: BGAppRefreshTask) {
        logger.notice("Performing background app refresh")
        scheduleAppRefresh()

        Task { @MainActor in
            do {
                // Update healthkit data and fetch new goals in parallel
                // This means we are not guaranteed to update data if discover a new healthkit goal, but that is very rare
                // and probably would lack permissions, so is not worth keeping the app awake longer for.

                async let goalUpdateResult: () = ServiceLocator.healthStoreManager.updateAllGoalsWithRecentData(days: 3)

                let goals = try await ServiceLocator.goalManager.fetchGoals()
                ServiceLocator.healthStoreManager.silentlyInstallObservers(goals: goals)

                try await goalUpdateResult

            } catch {
                logger.error("Error refreshing goals: \(error)")
            }
            task.setTaskCompleted(success: true)
        }
    }
}
