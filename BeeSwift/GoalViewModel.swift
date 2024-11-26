//
//  GoalViewModel.swift
//  BeeSwift
//
//  Created by krugerk on 2024-11-25.
//

import Foundation
import Intents

import CoreData
import BeeKit

struct GoalViewModel {
    let goal: Goal
    
    public func initialDateStepperValue(date: Date = Date()) -> Double {
        let daystampAccountingForTheGoalsDeadline = Daystamp(fromDate: date,
                                                             deadline: goal.deadline)
        let daystampAssumingMidnightDeadline = Daystamp(fromDate: date,
                                                        deadline: 0)
        
        return Double(daystampAssumingMidnightDeadline.distance(to: daystampAccountingForTheGoalsDeadline))
    }
    
    var title: String {
        goal.slug
    }
    
    var isDataEntryHidden: Bool {
        goal.hideDataEntry
    }
    
    var showPullToRefreshHint: Bool {
        goal.isDataProvidedAutomatically
    }
    
    var pullToRefreshHint: String {
        self.goal.isLinkedToHealthKit
        ? "Pull down to synchronize with Apple Health"
        : "Pull down to update"
    }
    
    var goalName: String {
        goal.slug
    }
    
    var username: String {
        goal.owner.username
    }
    
    var countdownLabelTextColor: UIColor? {
        goal.countdownColor
    }
    
    var countdownLabelText: String? {
        goal.capitalSafesum()
    }
    
    var suggestedNextValue: NSNumber {
        goal.suggestedNextValue ?? 1
    }
    
    var isHhmmFormat: Bool {
        goal.hhmmFormat
    }
    
    var recentDatapoints: [DataPoint] {
        goal.recentData.sorted(using: SortDescriptor(\.updatedAt))
    }
    
    var isLinkedWithHealthKit: Bool {
        goal.isLinkedToHealthKit
    }
    
    var usesManualDataEntry: Bool {
        !goal.isDataProvidedAutomatically
    }
    
    var goalObjectId: NSManagedObjectID {
        goal.objectID
    }
    
    var showTimerButton: Bool {
        !goal.hideDataEntry
    }
}
