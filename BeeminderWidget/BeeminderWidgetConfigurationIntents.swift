//
//  BeeminderWidgetConfigurationIntents.swift
//  BeeminderWidget
//
//  Created by krugerk on 2024-11-13.
//

import AppIntents
import BeeKit
import WidgetKit

struct GoalBasicsConfigurationAppIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Goal Basics"
    static let description = IntentDescription("Shows basic data of a goal!")

    @Parameter(title: "Goal Name (aka slug)",
               default: "steps",
               inputOptions: String.IntentInputOptions(keyboardType: .default, capitalizationType: .none, autocorrect: false))
    var goalName: String
}

struct PledgedConfigurationAppIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Amount Pledged"
    static let description = IntentDescription("Shows the sum you currently have pledged!")

    enum BeeminderPledgeDenomination: String, AppEnum {
        case honeyMoney, usDollar

        static let typeDisplayRepresentation: TypeDisplayRepresentation = "Pledge Denomination"
        static let caseDisplayRepresentations: [BeeminderPledgeDenomination: DisplayRepresentation] = [
            .honeyMoney: "Honey Money",
            .usDollar: "US Dollar",
        ]
    }

    @Parameter(title: "Denomination", default: .honeyMoney)
    var denomination: BeeminderPledgeDenomination
}

struct GoalCountdownConfigurationAppIntent: AppIntent, WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Colored Goal"
    static let description = IntentDescription("Shows a goal in its countdown color!")

    @Parameter(title: "Goal Name (aka slug)",
               optionsProvider: BeeminderGoalCountdownWidgetProvider.GoalNameProvider())
    var goalName: String?

    @Parameter(title: "Show Summary of what you need to do to eke by, e.g., \"+2 within 1 day\".", default: true)
    var showLimSum: Bool
}

// namespace?
extension BeeminderGoalCountdownWidgetProvider {
    struct GoalNameProvider: DynamicOptionsProvider {
        func results() async throws -> [String] {
            ServiceLocator.goalManager
                .staleGoals(context: ServiceLocator.persistentContainer.viewContext)?
                .sorted(using: SortDescriptor(\.slug))
                .map { $0.slug }
                ?? []
        }
    }
}
