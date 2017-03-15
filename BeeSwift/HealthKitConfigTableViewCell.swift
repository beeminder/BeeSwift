//
//  HealthKitConfigTableViewCell.swift
//  BeeSwift
//
//  Created by Andy Brett on 3/15/17.
//  Copyright © 2017 APB. All rights reserved.
//

import UIKit

class HealthKitConfigTableViewCell: UITableViewCell {

    var goalname : String? {
        didSet {
            self.goalnameLabel.text = self.goalname
        }
    }
    var goalMetric : String? {
        didSet {
            self.metricLabel.text = self.goalMetric ?? "None"
        }
    }
    
    fileprivate var goalnameLabel = BSLabel()
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
        self.selectionStyle = .none
        self.backgroundColor = UIColor.clear
        self.accessoryType = .none
        
        self.contentView.addSubview(self.goalnameLabel)
        self.goalnameLabel.snp.makeConstraints { (make) -> Void in
            make.centerY.equalTo(0)
            make.left.equalTo(15)
            make.width.equalTo(self.contentView).multipliedBy(0.75)
        }
        
        self.contentView.addSubview(self.metricLabel)
        self.metricLabel.snp.makeConstraints { (make) -> Void in
            make.centerY.equalTo(0)
            make.right.equalTo(-15)
            make.width.equalTo(self.contentView).multipliedBy(0.25)
        }
    }
}
