// Part of BeeSwift. Copyright Beeminder

import Foundation
import AppIntents
import BeeKit

struct AddDataPointIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Data Point"
    static var description = IntentDescription("Add a data point to a Beeminder goal")
    
    @Parameter(title: "Goal", optionsProvider: GoalOptionsProvider())
    var goal: GoalEntity
    
    @Parameter(title: "Value")
    var value: Double
    
    @Parameter(title: "Comment", default: "Added via Beeminder")
    var comment: String?
    
    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$value) to \(\.$goal)") {
            \.$comment
        }
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let dataComment = comment ?? ""
        
        do {
            let _ = try await ServiceLocator.requestManager.addDatapoint(
                urtext: "^ \(value) \"\(dataComment)\"",
                slug: goal.slug
            )
            
            // Use displayTitle to show title with slug fallback
            let formatter = NumberFormatter()
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 5
            let formattedValue = formatter.string(from: NSNumber(value: value)) ?? String(value)
            
            return .result(dialog: "Added \(formattedValue) to \(goal.displayTitle)")
        } catch ServerError.notFound {
            throw AddDataError.apiError("Goal '\(goal.slug)' not found")
        } catch {
            throw AddDataError.apiError(error.localizedDescription)
        }
    }
    
    private struct GoalOptionsProvider: DynamicOptionsProvider {
        func results() async throws -> [GoalEntity] {
            return try await GoalEntityQuery().suggestedEntities()
        }
    }
}
