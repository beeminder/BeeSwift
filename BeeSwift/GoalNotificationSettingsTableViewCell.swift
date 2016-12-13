//
//  GoalNotificationSettingsTableViewCell.swift
//  BeeSwift
//
//  Created by Andy Brett on 11/2/15.
//  Copyright © 2015 APB. All rights reserved.
//

import Foundation

class GoalNotificationSettingsTableViewCell: UITableViewCell {
    var title : String? {
        didSet {
            self.titleLabel.text = self.title
        }
    }
    fileprivate var titleLabel = BSLabel()
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.configure()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.configure()
    }
    
    func configure() {
        self.selectionStyle = .default
        self.backgroundColor = UIColor.clear
        self.accessoryType = .disclosureIndicator
        
        self.contentView.addSubview(self.titleLabel)
        self.titleLabel.snp.makeConstraints { (make) -> Void in
            make.centerY.equalTo(0)
            make.left.equalTo(15)
        }
    }
}
