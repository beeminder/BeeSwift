
//
//  BeeminderPledgedTodayWidget.swift
//  BeeminderWidget
//
//  Created by krugerk on 2024-11-13.
//

import BeeKit
import SwiftUI
import WidgetKit

struct BeeminderPledgedTodayWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in _: Context) -> BeeminderPledgedTodayEntry {
        BeeminderPledgedTodayEntry(date: Date(),
                                   configuration: .honeyMoneyConfig,
                                   pledges: usersGoals.map(\.pledge))
    }

    func snapshot(for configuration: PledgedConfigurationAppIntent, in _: Context) async -> BeeminderPledgedTodayEntry {
        BeeminderPledgedTodayEntry(date: Date(),
                                   configuration: configuration,
                                   pledges: usersGoals.map(\.pledge))
    }

    func timeline(for configuration: PledgedConfigurationAppIntent, in _: Context) async -> Timeline<BeeminderPledgedTodayEntry> {
        let pledges = usersGoals.map(\.pledge)

        let entries: [BeeminderPledgedTodayEntry] = [
            .init(date: Date(),
                  configuration: configuration,
                  pledges: pledges),
        ]

        return Timeline(entries: entries, policy: .atEnd)
    }
}

private extension BeeminderPledgedTodayWidgetProvider {
    private var username: String? {
        get async {
            await ServiceLocator.currentUserManager.username
        }
    }

    private var usersGoals: [Goal] {
        ServiceLocator.goalManager
            .staleGoals(context: ServiceLocator.persistentContainer.newBackgroundContext())?
            .filter { !$0.won }
            .sorted(using: SortDescriptor(\.urgencyKey))
            ?? []
    }
}

struct BeeminderPledgedTodayEntry: TimelineEntry {
    var date: Date

    let configuration: PledgedConfigurationAppIntent

    let pledges: [Int]

    var amountPledged: Int {
        pledges.reduce(0, +)
    }

    var denomination: String {
        switch configuration.denomination {
        case .honeyMoney: return "H$"
        case .usDollar: return "$"
        }
    }
}

struct BeeminderPledgedTodayWidgetEntryView: View {
    @Environment(\.widgetFamily) var family

    var entry: BeeminderPledgedTodayWidgetProvider.Entry

    var body: some View {
        ZStack {
            Image(systemName: "banknote")
                .resizable()
                .scaledToFill()
                .foregroundColor(.yellow)
                .padding()
                .opacity(0.2)

            HStack {
                Text(entry.denomination)
                Text(entry.amountPledged, format: .number)
            }
            .font(.largeTitle)
            .bold()
            .fontDesign(.rounded)
            .foregroundColor(.yellow)
        }
    }
}

struct BeeminderPledgedTodayWidget: Widget {
    let kind: String = "BeeminderPledgedTodayWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind,
                               intent: PledgedConfigurationAppIntent.self,
                               provider: BeeminderPledgedTodayWidgetProvider())
        { entry in
            BeeminderPledgedTodayWidgetEntryView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("Amount Pledged")
        .description("Displays the amount currently at stake across all of the user's active goals")
        .supportedFamilies([.systemSmall])
    }
}

extension PledgedConfigurationAppIntent {
    static var honeyMoneyConfig: Self {
        let config = PledgedConfigurationAppIntent()
        config.denomination = .honeyMoney
        return config
    }

    static var usdConfig: Self {
        let config = PledgedConfigurationAppIntent()
        config.denomination = .usDollar
        return config
    }
}

#Preview(as: .systemSmall) {
    BeeminderPledgedTodayWidget()
} timeline: {
    BeeminderPledgedTodayEntry(date: .now,
                               configuration: .honeyMoneyConfig,
                               pledges: [7])
    BeeminderPledgedTodayEntry(date: .now,
                               configuration: .usdConfig,
                               pledges: [137])
}
