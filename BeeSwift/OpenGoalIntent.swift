// Part of BeeSwift. Copyright Beeminder

import Foundation
import AppIntents
import UIKit
import BeeKit

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct OpenGoalIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Goal"
    static var description = IntentDescription("Open Beeminder app to view a specific goal or the goal gallery")

    @Parameter(title: "Goal", optionsProvider: GoalOptionsProvider())
    var goal: GoalEntity?
    
    static var parameterSummary: some ParameterSummary {
        When(\OpenGoalIntent.$goal, .equalTo, nil) {
            Summary("Open Beeminder")
        } otherwise: {
            Summary("Open \(\OpenGoalIntent.$goal) in Beeminder")
        }
    }
    
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult {
        if let goal = goal {
            await MainActor.run {
                NotificationCenter.default.post(
                    name: GalleryViewController.NotificationName.openGoal,
                    object: nil,
                    userInfo: ["slug": goal.slug]
                )
            }
            BeeSwift/GoalEntityQuery.swift}
        return .result()
    }
    
    private struct GoalOptionsProvider: DynamicOptionsProvider {
        func results() async throws -> [GoalEntity] {
            return try await GoalEntityQuery().suggestedEntities()
        }
    }
}
