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
      public static let green: UIColor = UIColor { traitCollection in
        if traitCollection.userInterfaceStyle == .dark {
          return UIColor(red: 90 / 255.0, green: 220 / 255.0, blue: 120 / 255.0, alpha: 1)  // Lighter green for dark mode
        } else {
          return UIColor(red: 40 / 255.0, green: 160 / 255.0, blue: 70 / 255.0, alpha: 1)  // Darker green for light mode
        }
      }
      public static let dkgreen: UIColor = UIColor { traitCollection in
        if traitCollection.userInterfaceStyle == .dark {
          return UIColor(red: 60 / 255.0, green: 179 / 255.0, blue: 113 / 255.0, alpha: 1)  // Medium sea green for dark mode
        } else {
          return UIColor(red: 20 / 255.0, green: 100 / 255.0, blue: 20 / 255.0, alpha: 1)  // Dark forest green for light mode
        }
      }
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
