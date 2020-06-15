//
//  Array+JSONGoal.swift
//  BeeSwift
//
//  Copyright © 2020 Beeminder. All rights reserved.
//

import Foundation

extension Array where Element == JSONGoal {
    
    func sorted() -> [JSONGoal] {
        self.sorted { (lhs, rhs) -> Bool in
            
            if let selectedGoalSort = UserDefaults.standard.string(forKey: Constants.selectedGoalSortKey) {
                
                switch selectedGoalSort {
                case Constants.nameGoalSortString:
                    return lhs.slug < rhs.slug
                    
                case Constants.recentDataGoalSortString:
                    return lhs.lasttouch?.intValue ?? 0 > rhs.lasttouch?.intValue ?? 0
                    
                case Constants.pledgeGoalSortString:
                    return lhs.pledge.intValue > rhs.pledge.intValue
                    
                default:
                    break
                }
            }
            
            return lhs.losedate.intValue < rhs.losedate.intValue
            
        }
    }
    
    mutating func sort() {
        self = self.sorted()
    }
}

