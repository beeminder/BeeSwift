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
            self.settingsImage.image = UIImage(named: self.imageName!)
        }
    }
    
    let titleLabel = BSLabel()
    let settingsImage = UIImageView()
    
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
    }
    
    func configure() {
        self.contentView.addSubview(self.titleLabel)
        self.contentView.addSubview(self.settingsImage)
        
        self.selectionStyle = .none
        if #available(iOS 13.0, *) {
            self.backgroundColor = .secondarySystemBackground
        } else {
            self.backgroundColor = .white
        }
        
        if #available(iOS 13.0, *) {
            self.titleLabel.textColor = .label
        } else {
            self.titleLabel.textColor = UIColor.beeminder.gray
        }
        
        self.titleLabel.snp.remakeConstraints { (make) -> Void in
            make.centerY.equalTo(self.contentView)
            make.left.equalTo(self.settingsImage.snp.right).offset(10)
        }
        self.settingsImage.snp.remakeConstraints({ (make) in
            make.centerY.equalTo(self.contentView)
            make.left.equalTo(10)
            make.height.width.equalTo(26)
        })

    }
}
