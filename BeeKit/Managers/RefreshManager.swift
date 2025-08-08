// Part of BeeSwift. Copyright Beeminder

import Foundation
import OSLog

public class RefreshManager {
    private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "RefreshManager")
    private let healthStoreManager: HealthStoreManager
    private let goalManager: GoalManager
    
    public init(healthStoreManager: HealthStoreManager, goalManager: GoalManager) {
        self.healthStoreManager = healthStoreManager
        self.goalManager = goalManager
    }
    
    @MainActor
    public func refreshGoalsAndHealthKitData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                do {
                    let _ = try await self.healthStoreManager.updateAllGoalsWithRecentData(days: 7)
                } catch {
                    self.logger.error("Error updating from healthkit: \(error)")
                }
            }
            
            group.addTask {
                do {
                    try await self.goalManager.refreshGoals()
                } catch {
                    self.logger.error("Error refreshing goals: \(error)")
                }
            }
        }
    }
}