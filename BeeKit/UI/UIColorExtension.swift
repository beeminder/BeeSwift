//
//  UIColorExtension.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/26/15.
//  Copyright 2015 APB. All rights reserved.
//

import Foundation
import UIKit

extension UIColor {
    
    public struct Beeminder {
        public static let red: UIColor = .systemRed
        
        public static let gray = UIColor.systemGray
        
        public static let yellow = UIColor(red: 255.0/255.0,
                                           green: 217.0/255.0,
                                           blue: 17.0/255.0,
                                           alpha: 1)
        
        public struct SafetyBuffer {
            public static let red: UIColor = .systemRed // .init(red: 1, green: 0, blue: 0, alpha: 1)
            public static let orange: UIColor = .systemOrange // .init(red: 1, green: 165/255.0, blue: 00, alpha: 1)
            public static let blue: UIColor = .systemBlue // .init(red: 63/255.0, green: 63/255.0, blue: 1, alpha: 1)
            public static let green: UIColor = .systemGreen // .init(red: 0, green: 170/255.0, blue: 0, alpha: 1)
            public static let forestGreen: UIColor = .init(red: 34/255.0, green: 139/255.0, blue: 34/255.0, alpha: 1)
        }
    }
}
