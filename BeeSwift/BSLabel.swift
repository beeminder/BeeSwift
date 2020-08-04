//
//  BSLabel.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/26/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation
import UIKit

class BSLabel : UILabel {

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.font = UIFont.beeminder.defaultFont
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.font = UIFont.beeminder.defaultFont
    }
    
    
}
