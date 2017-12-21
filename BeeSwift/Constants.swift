//
//  Constants.swift
//  BeeSwift
//
//  Created by Andy Brett on 5/15/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation
import UIKit

struct Constants {
    static let thumbnailWidth = 106
    static let thumbnailHeight = 70
    static let graphWidth = 696
    static let graphHeight = 453
    static let defaultFontSize = UIDevice.current.userInterfaceIdiom == .pad ? CGFloat(18) : CGFloat(14)
    static let defaultTextFieldHeight = 44
    static let savedMetricNotificationName = "hkMetricSaved"
    static let selectedGoalSortKey = "selectedGoalSort"
    static let recentDataGoalSortString = "Recent Data"
    static let nameGoalSortString = "Name"
    static let pledgeGoalSortString = "Pledge"
    static let deadlineGoalSortString = "Deadline"
    static let goalSortOptions = [Constants.nameGoalSortString, Constants.deadlineGoalSortString, Constants.pledgeGoalSortString, Constants.recentDataGoalSortString]
}

