//
//  BeeminderGoalListWidget.swift
//  BeeminderWidget
//
//  Created by krugerk on 2024-11-13.
//

import BeeKit
import SwiftUI
import WidgetKit

struct BeeminderGoalListProvider: TimelineProvider {
    func placeholder(in context: Context) -> BeeminderGoalListEntry {
        let min = context.family == .systemLarge ? 3 : 1
        let numGoals = Int.random(in: min ... 7)

        let goals = !usersGoals.isEmpty
            ? usersGoals
            : BeeminderGoalListEntryGoalDTO.goalDTOs.shuffled()

        return .init(date: Date(),
                     username: username ?? "Player1",
                     goals: goals.prefix(numGoals).map { $0 })
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (BeeminderGoalListEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in _: Context, completion: @escaping @Sendable (Timeline<BeeminderGoalListEntry>) -> Void) {
        let entries: [BeeminderGoalListEntry] = [
            .init(date: Date(),
                  username: username,
                  goals: usersGoals),
        ]

        let timeline = Timeline(entries: entries, policy: .atEnd)

        completion(timeline)
    }
}

private extension BeeminderGoalListProvider {
    private var username: String? {
        ServiceLocator.currentUserManager.username
    }

    private var usersGoals: [BeeminderGoalListEntryGoalDTO] {
        ServiceLocator.goalManager
            .staleGoals(context: ServiceLocator.persistentContainer.viewContext)?
            .sorted(using: SortDescriptor(\.urgencyKey))
            .map(BeeminderGoalListEntryGoalDTO.init)
            ?? []
    }
}

struct BeeminderGoalListEntry: TimelineEntry {
    var date: Date

    let username: String?

    let goals: [BeeminderGoalListEntryGoalDTO]
}

struct BeeminderGoalListEntryGoalDTO {
    let id: String
    let name: String
    let limSum: String
    let urgencyKey: String
    let countdownColor: Color

    var appLink: URL {
        URL(string: "beeminder://?slug=\(name)")!
    }

    init(goal: Goal) {
        self.init(id: goal.id,
                  name: goal.slug,
                  limSum: goal.limSum,
                  urgencyKey: goal.urgencyKey,
                  countdownColor: Color(uiColor: goal.countdownColor))
    }

    init(id: String, name: String, limSum: String, urgencyKey: String, countdownColor: Color) {
        self.id = id
        self.name = name
        self.limSum = limSum
        self.urgencyKey = urgencyKey
        self.countdownColor = countdownColor
    }
}

struct BeeminderGoalListWidgetEntryView: View {
    @Environment(\.widgetFamily) var family

    var entry: BeeminderGoalListProvider.Entry

    private var goalLimit: Int {
        return switch family {
        case .systemSmall:
            0
        case .systemMedium:
            3
        case .systemLarge:
            7
        case .systemExtraLarge:
            7
        case .accessoryCircular:
            0
        case .accessoryRectangular:
            0
        case .accessoryInline:
            0
        @unknown default:
            0
        }
    }

    private var goalsToDisplay: [BeeminderGoalListEntryGoalDTO] {
        entry.goals
            .sorted(using: SortDescriptor(\.urgencyKey))
            .prefix(goalLimit)
            .map { $0 }
    }

    var errorMessage: String? {
        if entry.username == nil {
            return "Sign In"
        } else if goalsToDisplay.isEmpty {
            return "No Goals"
        } else {
            return nil
        }
    }

    var body: some View {
        if let errorMessage {
            // no user
            ZStack {
                Image(systemName: "laser.burst")
                    .resizable()
                    .scaledToFit()
                    .clipShape(.rect(cornerRadius: 8))
                    .opacity(0.04)

                VStack {
                    Spacer()

                    Text(errorMessage)
                        .font(.title3)

                    Spacer()
                    Text("List of goals' amounts due, sorted by urgency")
                        .font(.caption)
                        .italic()
                }
            }
            .shadow(radius: 5)
        } else {
            ZStack {
                Image(systemName: "chart.dots.scatter")
                    .resizable()
                    .scaledToFit()
                    .clipShape(.rect(cornerRadius: 8))
                    .opacity(0.04)

                GroupBox {
                    ForEach(goalsToDisplay, id: \.id) { goal in
                        Link(destination: goal.appLink) {
                            LabeledContent(goal.limSum, value: goal.name)
                        }
                        .padding(8)
                        .background(goal.countdownColor.gradient.opacity(0.2))
                        .clipShape(
                            // rounded background
                            RoundedRectangle(cornerRadius: 2, style: .circular)
                        )
                        .overlay(
                            // rounded border
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(goal.countdownColor.gradient, lineWidth: 2)
                        )
                    }
                }
                .backgroundStyle(.clear)
            }
        }
    }
}

struct BeeminderGoalListWidget: Widget {
    let kind: String = "BeeminderGoalListWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind,
                            provider: BeeminderGoalListProvider())
        { entry in
            BeeminderGoalListWidgetEntryView(entry: entry)
                .containerBackground(Color.clear,
                                     for: .widget)
        }
        .configurationDisplayName("Goal List")
        .description("Displays goals sorted by urgency")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

private extension BeeminderGoalListEntryGoalDTO {
    static var goalDTOs: [BeeminderGoalListEntryGoalDTO] {
        [
            .init(id: "id-011",
                  name: "dial",
                  limSum: "+1 due tomorrow 11:00",
                  urgencyKey: "urgency-011",
                  countdownColor: .red),
            .init(id: "id-022",
                  name: "teeth",
                  limSum: "+2 due tomorrow 23:59",
                  urgencyKey: "urgency-022",
                  countdownColor: .red),
            .init(id: "id-111",
                  name: "jogging",
                  limSum: "+5km within 4 days",
                  urgencyKey: "urgency-111",
                  countdownColor: .indigo),
            .init(id: "id-999",
                  name: "goalname",
                  limSum: "-421 in 431 days",
                  urgencyKey: "urgency-999",
                  countdownColor: .green),
            .init(id: "id-222",
                  name: "steps",
                  limSum: "+10k this week",
                  urgencyKey: "urgency-222",
                  countdownColor: .cyan),
            .init(id: "id-888",
                  name: "productivity",
                  limSum: "+1.15032 due in 54 days",
                  urgencyKey: "urgency-888",
                  countdownColor: .green),
            .init(id: "id-765",
                  name: "sleep_hours",
                  limSum: "+8h in 7 days",
                  urgencyKey: "urgency-765",
                  countdownColor: .orange),
            .init(id: "id-745",
                  name: "readingbee2",
                  limSum: "limit +1 today, safe until Sat",
                  urgencyKey: "urgency-745",
                  countdownColor: .orange),
        ]
    }
}

#Preview(as: .systemMedium) {
    BeeminderGoalListWidget()
} timeline: {
    let goals = BeeminderGoalListEntryGoalDTO.goalDTOs
        .prefix(10)
        .map { $0 }

    BeeminderGoalListEntry(date: .now,
                           username: "User531",
                           goals: goals)
}

#Preview(as: .systemLarge) {
    BeeminderGoalListWidget()
} timeline: {
    let goals = BeeminderGoalListEntryGoalDTO.goalDTOs
        .prefix(10)
        .map { $0 }

    BeeminderGoalListEntry(date: .now,
                           username: "captain",
                           goals: goals)
}

#Preview(as: .systemLarge) {
    BeeminderGoalListWidget()
} timeline: {
    BeeminderGoalListEntry(date: .now,
                           username: nil,
                           goals: [])
}

#Preview(as: .systemMedium) {
    BeeminderGoalListWidget()
} timeline: {
    BeeminderGoalListEntry(date: .now,
                           username: nil,
                           goals: [])
}

#Preview(as: .systemMedium) {
    BeeminderGoalListWidget()
} timeline: {
    BeeminderGoalListEntry(date: .now,
                           username: "someUser",
                           goals: [])
}
