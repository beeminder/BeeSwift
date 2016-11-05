//
//  DatapointsTableView.swift
//  BeeSwift
//
//  Created by Andy Brett on 5/16/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation

class DatapointsTableView : UITableView {
    
    override var intrinsicContentSize : CGSize {
        self.layoutIfNeeded()
        return CGSize(width: UIViewNoIntrinsicMetric, height: self.contentSize.height)
    }
}
