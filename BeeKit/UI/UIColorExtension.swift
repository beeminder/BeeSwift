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
  public func adjustedBrightness(by amount: CGFloat) -> UIColor {
    var hue: CGFloat = 0
    var saturation: CGFloat = 0
    var brightness: CGFloat = 0
    var alpha: CGFloat = 0
    if getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
      let newBrightness = max(0, min(1, brightness + amount))
      return UIColor(hue: hue, saturation: saturation, brightness: newBrightness, alpha: alpha)
    }
    return self
  }

  public struct Beeminder {
    public static let red: UIColor = .systemRed
    public static let gray = UIColor.systemGray
    public static let yellow = UIColor(red: 255.0 / 255.0, green: 217.0 / 255.0, blue: 17.0 / 255.0, alpha: 1)
    public struct SafetyBuffer {
      public static let red: UIColor = .systemRed  // .init(red: 1, green: 0, blue: 0, alpha: 1)
      public static let orange: UIColor = .systemOrange  // .init(red: 1, green: 165/255.0, blue: 00, alpha: 1)
      public static let blue: UIColor = .systemBlue  // .init(red: 63/255.0, green: 63/255.0, blue: 1, alpha: 1)
      public static let green: UIColor = .systemGreen  // .init(red: 0, green: 170/255.0, blue: 0, alpha: 1)
      public static let forestGreen: UIColor = .init(red: 34 / 255.0, green: 139 / 255.0, blue: 34 / 255.0, alpha: 1)
    }
    public struct GalleryBackground {
      // Red - derailing today (safeBuf < 1)
      public static let red: UIColor = UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .dark: return .systemBackground
        default: return UIColor(red: 255 / 255.0, green: 210 / 255.0, blue: 210 / 255.0, alpha: 1)
        }
      }
      // Orange - 1 day buffer (safeBuf 1-2)
      public static let orange: UIColor = UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .dark: return .systemBackground
        default: return UIColor(red: 255 / 255.0, green: 230 / 255.0, blue: 200 / 255.0, alpha: 1)
        }
      }
      // Blue - 2 days buffer (safeBuf 2-3)
      public static let blue: UIColor = UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .dark: return .systemBackground
        default: return UIColor(red: 210 / 255.0, green: 230 / 255.0, blue: 255 / 255.0, alpha: 1)
        }
      }
      // Green - 3-6 days buffer (safeBuf 3-7)
      public static let green: UIColor = UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .dark: return .systemBackground
        default: return UIColor(red: 210 / 255.0, green: 255 / 255.0, blue: 210 / 255.0, alpha: 1)
        }
      }
      // Forest green - 7+ days buffer (safeBuf 7+)
      public static let forestGreen: UIColor = UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .dark: return .systemBackground
        default: return UIColor(red: 182 / 255.0, green: 225 / 255.0, blue: 182 / 255.0, alpha: 1)
        }
      }
    }
  }
}
