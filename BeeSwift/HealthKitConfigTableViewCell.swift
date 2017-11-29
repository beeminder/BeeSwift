//
//  HealthKitConfigTableViewCell.swift
//  BeeSwift
//
//  Created by Andy Brett on 3/15/17.
//  Copyright © 2017 APB. All rights reserved.
//

import UIKit

class HealthKitConfigTableViewCell: UITableViewCell {

    var goal : Goal? {
        didSet {
            self.goalnameLabel.text = self.goal?.slug
            self.autodataNameLabel.text = self.goal?.humanizedAutodata()
            if self.goal!.autodata.count > 0 {
                self.autodataNameLabel.layer.opacity = 0.5
                self.addMetricLabel.isHidden = true
            } else {
                self.addMetricLabel.isHidden = false
                self.autodataNameLabel.layer.opacity = 1.0
            }
        }
    }
    
    fileprivate var goalnameLabel = BSLabel()
    fileprivate var autodataNameLabel = BSLabel()
    fileprivate var addMetricLabel = BSLabel()
    
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
        
        self.contentView.addSubview(self.goalnameLabel)
        self.goalnameLabel.snp.makeConstraints { (make) -> Void in
            make.centerY.equalTo(0)
            make.left.equalTo(15)
            make.width.equalTo(self.contentView).multipliedBy(0.55)
        }
        
        self.contentView.addSubview(self.autodataNameLabel)
        self.autodataNameLabel.snp.makeConstraints { (make) -> Void in
            make.centerY.equalTo(0)
            make.right.equalTo(-15)
            make.width.equalTo(self.contentView).multipliedBy(0.45)
        }
        
        self.contentView.addSubview(self.addMetricLabel)
        self.addMetricLabel.snp.makeConstraints { (make) in
            make.edges.equalTo(self.autodataNameLabel)
        }
        self.addMetricLabel.text = "Add source..."
    }
}
