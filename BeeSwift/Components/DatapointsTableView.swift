//
//  DatapointsTableView.swift
//  BeeSwift
//
//  Created by Andy Brett on 5/16/15.
//  Copyright 2015 APB. All rights reserved.
//

import Foundation

class DatapointsTableView : UITableView {
    override var contentSize:CGSize {
        didSet {
            invalidateIntrinsicContentSize()
        }
    }
    
    override var intrinsicContentSize : CGSize {
        self.layoutIfNeeded()
        return CGSize(width: UIView.noIntrinsicMetric, height: self.contentSize.height)
    }
}
