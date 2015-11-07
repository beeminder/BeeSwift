//
//  GoalNotificationSettingsTableViewCell.swift
//  BeeSwift
//
//  Created by Andy Brett on 11/2/15.
//  Copyright © 2015 APB. All rights reserved.
//

import Foundation

class GoalNotificationSettingsTableViewCell: UITableViewCell {
    var goal : Goal? {
        didSet {
            self.goalLabel.text = self.goal?.title
        }
    }
    
    private var goalLabel = BSLabel()
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.configure()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.configure()
    }
    
    func configure() {
        self.selectionStyle = .None
        self.backgroundColor = UIColor.clearColor()
        self.accessoryType = .DisclosureIndicator
        
        self.contentView.addSubview(self.goalLabel)
        self.goalLabel.snp_makeConstraints { (make) -> Void in
            make.centerY.equalTo(0)
            make.left.equalTo(15)
        }
    }
}