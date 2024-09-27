//
//  UIColorExtension.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/26/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation
import UIKit

extension UIColor {
    
    public struct beeminder {
        public static let green: UIColor = .init(red: 81.0/255.0,
                                                   green: 163.0/255.0,
                                                   blue: 81.0/255.0,
                                                   alpha: 1)

        public static let blue: UIColor = .systemBlue
        public static let orange: UIColor = .systemOrange
        public static let red: UIColor = .systemRed

        public static let gray: UIColor = .init(white: 0.7, alpha: 1.0)
        
        public static let yellow = UIColor.init(red: 255.0/255.0,
                                                green: 217.0/255.0,
                                                blue: 17.0/255.0,
                                                alpha: 1)
    }
}
