import Foundation
import BackgroundTasks
import OSLog

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
                let goals = try await CurrentUserManager.sharedManager.fetchGoals()
                HealthStoreManager.sharedManager.silentlyInstallObservers(goals: goals)

                // It should not be necessary to sync health kit goals here, as that should
                // be handled by our observers (in particular, updating when the phone
                // is unlocked and thus data is available). If we find that to be unreliable
                // we could also trigger a data refresh here.
            } catch {
                logger.error("Error refreshing goals: \(error)")
            }
            task.setTaskCompleted(success: true)
        }
    }
}
