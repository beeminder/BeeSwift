// Part of BeeSwift. Copyright Beeminder

import Foundation
import AppIntents
import BeeKit

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct AddDataResult: AppEntity {
    let id: String
    let success: Bool
    let message: String
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Add Data Result"
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(message)")
    }
    
    static var defaultQuery = AddDataResultQuery()
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct AddDataResultQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [AddDataResult] {
        [] // Not used for our purpose
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct AddData: AppIntent, WidgetConfigurationIntent, CustomIntentMigratedAppIntent, PredictableIntent {
    static let intentClassName = "AddDataIntent"

    static var title: LocalizedStringResource = "Add Data"
    static var description = IntentDescription("Add data to a Beeminder goal")

    @Parameter(title: "Value", default: 1)
    var value: Double?

    @Parameter(title: "Goal (slug)")
    var goal: String?

    @Parameter(title: "Comment", default: "Added via iOS Shortcut")
    var comment: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Add datapoint \(\.$value) to \(\.$goal) with comment \(\.$comment)")
    }

    static var predictionConfiguration: some IntentPredictionConfiguration {
        IntentPrediction(parameters: (\.$value, \.$goal, \.$comment)) { value, goal, comment in
            DisplayRepresentation(
                title: "Add datapoint \(value!) to \(goal!) with comment \(comment!)",
                subtitle: ""
            )
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<AddDataResult> {
        guard let goalSlug = goal else {
            let result = AddDataResult(id: UUID().uuidString, success: false, message: "No goal specified")
            return .result(value: result, dialog: IntentDialog("No goal specified. Please provide a goal slug."))
        }
        guard let dataValue = value else {
            let result = AddDataResult(id: UUID().uuidString, success: false, message: "No value specified")
            return .result(value: result, dialog: IntentDialog("No value specified. Please provide a value for the datapoint."))
        }
        
        let dataComment = comment ?? ""
        
        do {
            let _ = try await ServiceLocator.requestManager.addDatapoint(urtext: "^ \(dataValue) \"\(dataComment)\"", slug: goalSlug)
            let result = AddDataResult(id: UUID().uuidString, success: true, message: "Added \(dataValue) to \(goalSlug)")
            return .result(value: result, dialog: .responseSuccess(goal: goalSlug, value: dataValue))
        } catch {
            let result = AddDataResult(id: UUID().uuidString, success: false, message: "Failed: \(error.localizedDescription)")
            return .result(value: result, dialog: .responseFailure(goal: goalSlug, error: error.localizedDescription))
        }
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
fileprivate extension IntentDialog {
    static var valueParameterPrompt: Self {
        "What's the value of the datapoint?"
    }
    static func goalParameterConfiguration(goal: String) -> Self {
        "\(goal)"
    }
    static var goalParameterPrompt: Self {
        "Which goal?"
    }
    static func responseSuccess(goal: String, value: Double) -> Self {
        "Added \(value) to \(goal)"
    }
    static func responseFailure(goal: String, error: String) -> Self {
        "Failed to add data to \(goal): \(error)"
    }
}

