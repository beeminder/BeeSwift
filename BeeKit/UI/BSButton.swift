//
//  BSButton.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/27/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation
import UIKit

public class BSButton : UIButton {
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        registerForTraitChanges(
            [UITraitUserInterfaceStyle.self]) {
                (self: Self, previousTraitCollection: UITraitCollection) in
                self.resetStyle()
            }
        
        self.setUp()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        registerForTraitChanges(
            [UITraitUserInterfaceStyle.self]) {
                (self: Self, previousTraitCollection: UITraitCollection) in
                self.resetStyle()
            }
        
        self.setUp()
    }
    
    private func setUp() {
        self.titleLabel?.font = UIFont.beeminder.defaultBoldFont
        self.setTitleColor(dynamicTitleColor, for: UIControl.State())
        self.tintColor = dynamicTintFillColor
        self.configuration = .filled()
        
        self.layer.borderColor = UIColor.Beeminder.yellow.cgColor
        self.layer.borderWidth = 1
        self.layer.cornerRadius = 4
    }
    
    private func resetStyle() {
        self.tintColor = dynamicTintFillColor
        self.setTitleColor(dynamicTitleColor, for: UIControl.State())
    }
    
    private let dynamicTintFillColor = UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .dark:
            return UIColor.black
        default:
            return UIColor(red: 235.0/255.0,
                           green: 235.0/255.0,
                           blue: 235.0/255.0,
                           alpha: 1.0)
        }
    }
    
    private let dynamicTitleColor = UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .dark:
            return UIColor.Beeminder.yellow
        default:
            return UIColor.black
        }
    }
}
