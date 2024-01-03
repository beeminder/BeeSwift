//
//  HealthKitError.swift
//  BeeSwift
//
//  Created by Theo Spears on 11/5/22.
//  Copyright © 2022 APB. All rights reserved.
//

import Foundation

struct HealthKitError: Error {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    public var localizedDescription: String {
        return message
    }
}
