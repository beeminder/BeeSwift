//
//  UIFontExtension.swift
//  BeeSwift
//
//  Created by Andy Brett on 11/7/15.
//  Copyright 2015 APB. All rights reserved.
//

import Foundation
import UIKit

extension UIFont {
  public struct beeminder {
    public static var defaultFont: UIFont { return defaultFontLight }
    public static var defaultFontLight: UIFont { return UIFont(name: "Avenir-Light", size: 18)! }
    public static var defaultFontHeavy: UIFont { return UIFont(name: "Avenir-Heavy", size: 18)! }
    public static var defaultBoldFont: UIFont { return UIFont(name: "Avenir-Black", size: 18)! }
    public static var defaultFontPlain: UIFont { return UIFont(name: "Avenir", size: 18)! }
  }
}
