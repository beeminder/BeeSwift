//
//  DateUtils.swift
//  BeeSwift
//
//  Created by Theo Spears on 1/27/23.
//  Copyright 2023 APB. All rights reserved.
//

import Foundation

class DateUtils {
    static func date(daystamp: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        return dateFormatter.date(from: daystamp)
    }
}
