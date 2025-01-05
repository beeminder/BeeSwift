//
//  Constants.swift
//  BeeSwift
//
//  Created by Andy Brett on 5/15/15.
//  Copyright 2015 APB. All rights reserved.
//

import Foundation
import UIKit

public struct Constants {
    public static let thumbnailWidth = 106
    public static let thumbnailHeight = 70
    public static let graphWidth = 696
    public static let graphHeight = 453
    public static let defaultFontSize = UIDevice.current.userInterfaceIdiom == .pad ? CGFloat(18) : CGFloat(14)
    public static let defaultTextFieldHeight = 44
    public static let selectedGoalSortKey = "selectedGoalSort"
    public static let recentDataGoalSortString = "Recent Data"
    public static let nameGoalSortString = "Name"
    public static let pledgeGoalSortString = "Pledge"
    public static let urgencyGoalSortString = "Urgency"
    public static let healthKitUpdateDictionaryKey = "healthKitUpdateDictionary"
    public static let goalSortOptions = [Constants.urgencyGoalSortString, Constants.nameGoalSortString, Constants.pledgeGoalSortString, Constants.recentDataGoalSortString]
    public static let appGroupIdentifier = "group.beeminder.beeminder"
}

