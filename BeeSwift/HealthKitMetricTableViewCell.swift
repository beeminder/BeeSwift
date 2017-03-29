//
//  HealthKitMetricTableViewCell.swift
//  BeeSwift
//
//  Created by Andy Brett on 3/29/17.
//  Copyright © 2017 APB. All rights reserved.
//

import UIKit

class HealthKitMetricTableViewCell: UITableViewCell {

    var metric : String? {
        didSet {
            self.metricLabel.text = self.metric
        }
    }
    
    fileprivate var metricLabel = BSLabel()
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.configure()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.configure()
    }
    
    func configure() {
        self.backgroundColor = UIColor.clear
        self.accessoryType = .none
        self.selectionStyle = .none
        
        self.contentView.addSubview(self.metricLabel)
        self.metricLabel.snp.makeConstraints { (make) -> Void in
            make.centerY.equalTo(0)
            make.left.equalTo(25)
            make.width.equalTo(self.contentView)
        }
    }
}
