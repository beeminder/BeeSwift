//
//  SettingsTableViewCell.swift
//  BeeSwift
//
//  Created by Andy Brett on 11/2/15.
//  Copyright © 2015 APB. All rights reserved.
//

import Foundation

class SettingsTableViewCell: UITableViewCell {
    var title : String? {
        didSet {
            self.titleLabel.text = self.title
        }
    }
    var imageName : String? {
        didSet {
            self.configure()
        }
    }
    var titleLabel = BSLabel()
    
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
        self.backgroundColor = .white
        self.accessoryType = .disclosureIndicator
        
        self.contentView.addSubview(self.titleLabel)
        
        if self.imageName != nil {
            let imageView = UIImageView(image: UIImage(named: self.imageName!))
            self.contentView.addSubview(imageView)
            imageView.snp.remakeConstraints({ (make) in
                make.centerY.equalTo(self.contentView)
                make.left.equalTo(10)
                make.height.width.equalTo(26)
            })
            self.titleLabel.snp.remakeConstraints { (make) -> Void in
                make.centerY.equalTo(self.contentView)
                make.left.equalTo(imageView.snp.right).offset(10)
            }
        } else {
            self.titleLabel.snp.remakeConstraints { (make) -> Void in
                make.centerY.equalTo(self.contentView)
                make.left.equalTo(10)
            }
        }
    }
}
