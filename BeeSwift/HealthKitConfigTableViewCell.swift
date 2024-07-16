//
//  HealthKitConfigTableViewCell.swift
//  BeeSwift
//
//  Created by Andy Brett on 3/15/17.
//  Copyright © 2017 APB. All rights reserved.
//

import UIKit

import BeeKit

class HealthKitConfigTableViewCell: UITableViewCell {

    var goal : GoalProtocol? {
        didSet {
            self.goalnameLabel.text = self.goal?.slug
            self.autodataNameLabel.text = self.goal?.humanizedAutodata
            
                self.addMetricLabel.isHidden = false
                self.autodataNameLabel.layer.opacity = 1.0
            self.goalnameLabel.layer.opacity = 1.0
            
            if self.goal?.isDataProvidedAutomatically == true {
                if self.goal?.autodata != "apple" {
                    self.autodataNameLabel.layer.opacity = 0.5
                    self.goalnameLabel.layer.opacity = 0.5
                }
                self.addMetricLabel.isHidden = true
            }
        }
    }
    
    fileprivate var goalnameLabel = BSLabel()
    fileprivate var autodataNameLabel = BSLabel()
    fileprivate var addMetricLabel = BSLabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.configure()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.configure()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.goalnameLabel.text = nil
        self.autodataNameLabel.text = nil
        self.addMetricLabel.text = "Add source..."

        self.goal = nil
    }
    
    func configure() {
        self.backgroundColor = UIColor.secondarySystemBackground
        self.accessoryType = .none
        self.selectionStyle = .none
        
        self.contentView.addSubview(self.goalnameLabel)
        self.goalnameLabel.snp.makeConstraints { (make) -> Void in
            make.centerY.equalTo(self.contentView)
            make.left.equalTo(15)
            make.width.equalTo(self.contentView).multipliedBy(0.45)
        }
        
        self.contentView.addSubview(self.autodataNameLabel)
        self.autodataNameLabel.textAlignment = .right
        self.autodataNameLabel.snp.makeConstraints { (make) -> Void in
            make.centerY.equalTo(self.contentView)
            make.right.equalTo(-15)
            make.width.equalTo(self.contentView).multipliedBy(0.45)
        }
        
        self.contentView.addSubview(self.addMetricLabel)
        self.addMetricLabel.textAlignment = .right
        self.addMetricLabel.snp.makeConstraints { make in
            make.edges.equalTo(self.autodataNameLabel)
        }
        self.addMetricLabel.text = "Add source..."
    }
}
