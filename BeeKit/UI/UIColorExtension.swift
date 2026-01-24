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
    public static let yellow = UIColor(red: 255.0 / 255.0, green: 217.0 / 255.0, blue: 17.0 / 255.0, alpha: 1)
    public struct SafetyBuffer {
      public static let red: UIColor = .systemRed
      public static let orange: UIColor = .systemOrange
      public static let blue: UIColor = .systemBlue
      public static let green: UIColor = .systemGreen
      public static let dkgreen: UIColor = .init(red: 34 / 255.0, green: 139 / 255.0, blue: 34 / 255.0, alpha: 1)
      public static let gray: UIColor = .systemGray

      public static func color(for colorkey: String) -> UIColor {
        switch colorkey {
        case "red": return red
        case "orange": return orange
        case "blue": return blue
        case "green": return green
        case "dkgreen": return dkgreen
        case "gray": return gray
        default: return gray
        }
      }
    }
  }
}
