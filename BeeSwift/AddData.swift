// Part of BeeSwift. Copyright Beeminder

import Foundation
import AppIntents
import BeeKit

typealias ServerError = BeeKit.ServerError

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
enum AddDataError: Error, CustomLocalizedStringResourceConvertible {
    case noGoal
    case noValue
    case apiError(String)
    
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noGoal:
            return "No goal specified. Please provide a goal slug."
        case .noValue:
            return "No value specified. Please provide a value for the datapoint."
        case .apiError(let message):
            return "Failed to add datapoint: \(message)"
        }
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

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let goalSlug = goal else {
            throw AddDataError.noGoal
        }
        guard let dataValue = value else {
            throw AddDataError.noValue
        }
        
        let dataComment = comment ?? ""
        
        do {
            let _ = try await ServiceLocator.requestManager.addDatapoint(urtext: "^ \(dataValue) \"\(dataComment)\"", slug: goalSlug)
            return .result(dialog: .responseSuccess(goal: goalSlug, value: dataValue))
        } catch ServerError.notFound {
            throw AddDataError.apiError("Goal '\(goalSlug)' not found")
        } catch {
            throw AddDataError.apiError(error.localizedDescription)
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
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 5
        let formattedValue = formatter.string(from: NSNumber(value: value)) ?? String(value)
        return "Added \(formattedValue) to \(goal)"
    }
}

