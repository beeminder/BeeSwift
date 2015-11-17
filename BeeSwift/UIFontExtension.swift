//
//  UIFontExtension.swift
//  BeeSwift
//
//  Created by Andy Brett on 11/7/15.
//  Copyright © 2015 APB. All rights reserved.
//

import Foundation

extension UIFont {
    class func beeminderDefaultFont() -> UIFont {
        return UIFont(name: "Avenir-Light", size: 18)!
    }
    
    class func beeminderDefaultBoldFont() -> UIFont {
        return UIFont(name: "Avenir-Black", size: 18)!
    }
}