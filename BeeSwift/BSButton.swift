//
//  BSButton.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/27/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation
import UIKit

class BSButton : UIButton {
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setup()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }
    
    func setup() {
        self.titleLabel?.font = UIFont.Beeminder.defaultFont
        self.setTitleColor(UIColor.white, for: UIControlState())
        self.backgroundColor = UIColor.Beeminder.gray
    }
    
}
