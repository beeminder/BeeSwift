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
        self.setUp()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setUp()
    }
    
    func setUp() {
        self.titleLabel?.font = UIFont.beeminder.defaultBoldFont
        self.setTitleColor(UIColor.Beeminder.yellow, for: UIControl.State())
        self.tintColor = .black
        self.configuration = .filled()
        
        self.layer.borderColor = UIColor.Beeminder.yellow.cgColor
        self.layer.borderWidth = 1
    }
    
}
