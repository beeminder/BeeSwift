//
//  GoalViewModel.swift
//  BeeSwift
//
//  Created by krugerk on 2024-11-25.
//

import Foundation
import Intents

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
}
