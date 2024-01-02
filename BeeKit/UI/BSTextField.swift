//
//  BSTextField.swift
//  BeeSwift
//
//  Created by Andy Brett on 11/22/16.
//  Copyright © 2016 APB. All rights reserved.
//

import Foundation
import UIKit

public class BSTextField : UITextField {
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.font = UIFont.beeminder.defaultFont
        self.layer.borderColor = UIColor.beeminder.gray.cgColor
        self.tintColor = UIColor.beeminder.gray
        self.layer.borderWidth = 1
        self.textAlignment = NSTextAlignment.center
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.font = UIFont.beeminder.defaultFont
        self.layer.borderColor = UIColor.beeminder.gray.cgColor
        self.tintColor = UIColor.beeminder.gray
        self.layer.borderWidth = 1
        self.textAlignment = NSTextAlignment.center
    }
    
    
}
