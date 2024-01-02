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
        public static var green: UIColor {
            return UIColor(red: 81.0/255.0, green: 163.0/255.0, blue: 81.0/255.0, alpha: 1)
        }

        public static var blue: UIColor = UIColor.systemBlue
        public static var orange: UIColor = UIColor.systemOrange
        public static var red: UIColor = UIColor.systemRed

        public static var gray: UIColor {
            return UIColor(white: 0.7, alpha: 1.0)
        }
    }
}
