//
//  BSButton.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/27/15.
//  Copyright 2015 APB. All rights reserved.
//

import Foundation
import UIKit

public class BSButton: UIButton {
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented; neither xib nor storyboards in use")
  }
  override init(frame: CGRect) {
    super.init(frame: frame)
    registerForTraitChanges([UITraitUserInterfaceStyle.self]) {
      (self: Self, previousTraitCollection: UITraitCollection) in self.resetStyle()
    }
    self.resetStyle()
  }
  private func resetStyle() {
    self.configuration = .filled()

    self.titleLabel?.font = UIFont.beeminder.defaultBoldFont

    self.setTitleColor(dynamicTitleColor, for: UIControl.State())
    self.tintColor = dynamicTintFillColor

    self.backgroundColor = .clear
    self.layer.borderColor =
      traitCollection.userInterfaceStyle == .dark ? UIColor.Beeminder.yellow.cgColor : UIColor.clear.cgColor
    self.layer.borderWidth = traitCollection.userInterfaceStyle == .dark ? 1 : 0
    self.layer.cornerRadius = traitCollection.userInterfaceStyle == .dark ? 4 : 0
  }
  private let dynamicTintFillColor = UIColor { traitCollection in
    switch traitCollection.userInterfaceStyle {
    case .dark: return UIColor.black
    default: return UIColor(red: 235.0 / 255.0, green: 235.0 / 255.0, blue: 235.0 / 255.0, alpha: 1.0)
    }
  }
  private let dynamicTitleColor = UIColor { traitCollection in
    switch traitCollection.userInterfaceStyle {
    case .dark: return UIColor.Beeminder.yellow
    default: return UIColor.black
    }
  }
}
