//
//  BeeminderWidgetBundle.swift
//  BeeminderWidget
//
//  Created by krugerk on 2024-11-13.
//

import SwiftUI
import WidgetKit

@main
struct BeeminderWidgetBundle: WidgetBundle {
    var body: some Widget {
        BeeminderGoalCountdownWidget()

        BeeminderGoalListWidget()

        BeeminderPledgedTodayWidget()
    }
}
