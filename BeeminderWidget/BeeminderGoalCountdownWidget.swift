//
//  BeeminderGoalCountdownWidget.swift
//  BeeminderWidget
//
//  Created by krugerk on 2024-11-13.
//

import BeeKit
import SwiftUI
import WidgetKit

struct BeeminderGoalCountdownWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in _: Context) -> BeeminderGoalCountdownWidgetEntry {
        .init(date: Date(),
              configuration: GoalCountdownConfigurationAppIntent(),
              updatedAt: Date().addingTimeInterval(-60 * 1000).timeIntervalSince1970,
              username: "username",
              goalDTO: BeeminderGoalCountdownGoalDTO(name: "goal1",
                                                     limSum: "+3 in 3 days",
                                                     countdownColor: Color.cyan,
                                                     lastTouch: ""))
    }

    func snapshot(for _: GoalCountdownConfigurationAppIntent, in context: Context) async -> BeeminderGoalCountdownWidgetEntry {
        placeholder(in: context)
    }

    func timeline(for configuration: GoalCountdownConfigurationAppIntent, in _: Context) async -> Timeline<BeeminderGoalCountdownWidgetEntry> {
        var goal: BeeminderGoalCountdownGoalDTO? {
            guard let goalName = configuration.goalName else { return nil }
            return usersGoals.first { $0.name.caseInsensitiveCompare(goalName) == .orderedSame }
        }

        let updatedAt: TimeInterval? = {
            guard let lastTouch = goal?.lastTouch else { return nil }

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"

            let date = formatter.date(from: lastTouch)
            return date?.timeIntervalSince1970
        }()

        let entries: [BeeminderGoalCountdownWidgetEntry] = await [
            BeeminderGoalCountdownWidgetEntry(date: Date(),
                                              configuration: configuration,
                                              updatedAt: updatedAt,
                                              username: username,
                                              goalDTO: goal),
        ]

        return Timeline(entries: entries, policy: .atEnd)
    }
}

private extension BeeminderGoalCountdownWidgetProvider {
    private var username: String? {
        get async {
            await ServiceLocator.currentUserManager.username
        }
    }

    var usersGoals: [BeeminderGoalCountdownGoalDTO] {
        ServiceLocator.goalManager
            .staleGoals(context: ServiceLocator.persistentContainer.viewContext)?
            .sorted(using: SortDescriptor(\.urgencyKey))
            .map(BeeminderGoalCountdownGoalDTO.init)
            ?? []
    }
}

struct BeeminderGoalCountdownGoalDTO {
    let name: String
    let limSum: String
    let countdownColor: Color
    let lastTouch: String

    init(goal: Goal) {
        self.init(name: goal.slug,
                  limSum: goal.limSum,
                  countdownColor: Color(uiColor: goal.countdownColor),
                  lastTouch: goal.lastTouch)
    }

    init(name: String,
         limSum: String,
         countdownColor: Color,
         lastTouch: String)
    {
        self.name = name
        self.limSum = limSum
        self.countdownColor = countdownColor
        self.lastTouch = lastTouch
    }
}

struct BeeminderGoalCountdownWidgetEntry: TimelineEntry {
    var date: Date

    let configuration: GoalCountdownConfigurationAppIntent

    let updatedAt: TimeInterval?
    let username: String?
    // let goal: Goal?
    let goalDTO: BeeminderGoalCountdownGoalDTO?

    var userProvidedGoalName: String? {
        configuration.goalName
    }

    var appGoalDeepLink: URL {
        guard let foundGoalName = goalDTO?.name else {
            return URL(string: "beeminder://")!
        }

        return URL(string: "beeminder://?slug=\(foundGoalName)")!
    }
}

struct BeeminderGoalCountdownWidgetEntryView: View {
    var entry: BeeminderGoalCountdownWidgetProvider.Entry

    var body: some View {
        if entry.username == nil {
            // no user
            ZStack {
                Image(systemName: "laser.burst")
                    .resizable()
                    .scaledToFit()
                    .clipShape(.rect(cornerRadius: 8))
                    .opacity(0.04)

                VStack {
                    Text("Sign In")
                        .font(.title3)
                    Spacer()
                    Spacer()
                }
            }
            .shadow(radius: 5)
        } else if entry.goalDTO == nil {
            // no goal
            ZStack {
                Image(systemName: "laser.burst")
                    .resizable()
                    .scaledToFit()
                    .clipShape(.rect(cornerRadius: 8))
                    .opacity(0.04)

                VStack {
                    Text("Goal not found")
                        .font(.title3)
                    Spacer()
                    Spacer()

                    Text(entry.userProvidedGoalName ?? "Edit Widget")
                        .font(.title)
                        .frame(width: .infinity)
                        .minimumScaleFactor(0.2)
                        .lineLimit(2)
                }
            }
        } else {
            ZStack {
                Image(systemName: "chart.bar.xaxis.ascending")
                    .resizable()
                    .scaledToFit()
                    .clipShape(.rect(cornerRadius: 8))
                    .opacity(0.04)

                VStack {
                    if let updatedAt = entry.updatedAt {
                        Text(Date(timeIntervalSince1970: updatedAt),
                             format: .dateTime)
                            .font(.caption2)
                            .monospaced()
                    } else {
                        Text("last updated at: unknown")
                            .font(.caption2)
                            .monospaced()
                    }

                    Spacer()

                    Text(entry.userProvidedGoalName ?? "Edit Widget")
                        .font(.title)
                        .frame(width: .infinity)
                        .minimumScaleFactor(0.2)
                        .lineLimit(2)

                    if entry.configuration.showLimSum {
                        Spacer()
                        Text(entry.goalDTO?.limSum ?? "?")
                            .font(.caption2)
                            .monospaced()
                    }
                }
                .shadow(radius: 5)
                .widgetURL(entry.appGoalDeepLink)
            }
        }
    }
}

struct BeeminderGoalCountdownWidget: Widget {
    let kind: String = "BeeminderGoalCountdownWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: GoalCountdownConfigurationAppIntent.self, provider: BeeminderGoalCountdownWidgetProvider()) { entry in

            var countdownColor: Color? {
                guard let countdownColor = entry.goalDTO?.countdownColor else { return nil }
                return Color(countdownColor)
            }

            let background: Color = countdownColor ?? .accentColor

            BeeminderGoalCountdownWidgetEntryView(entry: entry)
                .containerBackground(background, for: .widget)
        }
        .configurationDisplayName("Goal Countdown")
        .description("A single goal in its countdown color")
        .supportedFamilies([.systemSmall])
    }
}

extension GoalCountdownConfigurationAppIntent {
    static var steps: GoalCountdownConfigurationAppIntent {
        let config = GoalCountdownConfigurationAppIntent()
        config.goalName = "steps"
        config.showLimSum = true
        return config
    }

    static var withoutLimSum: GoalCountdownConfigurationAppIntent {
        let config = GoalCountdownConfigurationAppIntent()
        config.goalName = "dial"
        config.showLimSum = false
        return config
    }
}

#Preview(as: .systemSmall) {
    BeeminderGoalCountdownWidget()
} timeline: {
    BeeminderGoalCountdownWidgetEntry(date: .now,
                                      configuration: .steps,
                                      updatedAt: Date().addingTimeInterval(-60 * 1000).timeIntervalSince1970,
                                      username: "user123",
                                      goalDTO: nil)
    BeeminderGoalCountdownWidgetEntry(date: .now,
                                      configuration: .withoutLimSum,
                                      updatedAt: Date().addingTimeInterval(-60 * 1000).timeIntervalSince1970,
                                      username: "",
                                      goalDTO: .init(name: "writing",
                                                     limSum: "3 pages in 2 days", countdownColor: .cyan,
                                                     lastTouch: ""))
}

#Preview(as: .systemSmall) {
    BeeminderGoalCountdownWidget()
} timeline: {
    BeeminderGoalCountdownWidgetEntry(date: .now,
                                      configuration: .withoutLimSum,
                                      updatedAt: Date().addingTimeInterval(-60 * 1000).timeIntervalSince1970,
                                      username: "Player1",
                                      goalDTO: .init(name: "writing",
                                                     limSum: "3 pages in 2 days", countdownColor: .cyan, lastTouch: ""))
}
