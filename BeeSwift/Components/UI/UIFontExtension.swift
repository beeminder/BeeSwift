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
    public static var defaultFont: UIFont = { defaultFontLight }()
    public static var defaultFontLight: UIFont = {
      UIFont(name: "Avenir-Light", size: 18) ?? .systemFont(ofSize: 18, weight: .light)
    }()
    public static var defaultFontHeavy: UIFont = {
      UIFont(name: "Avenir-Heavy", size: 18) ?? .systemFont(ofSize: 18, weight: .heavy)
    }()
    public static var defaultBoldFont: UIFont = {
      UIFont(name: "Avenir-Black", size: 18) ?? .systemFont(ofSize: 18, weight: .black)
    }()
    public static var defaultFontPlain: UIFont = {
      UIFont(name: "Avenir", size: 18) ?? .systemFont(ofSize: 18, weight: .regular)
    }()
  }
}
