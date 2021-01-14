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
    let titleLabel = BSLabel()
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.configure()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.configure()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.titleLabel.text = nil
        self.title = nil
        self.imageName = nil
    }
    
    func configure() {
        self.selectionStyle = .none
        if #available(iOS 13.0, *) {
            self.backgroundColor = .secondarySystemBackground
        } else {
            self.backgroundColor = .white
        }
        self.accessoryType = .disclosureIndicator
        
        self.contentView.addSubview(self.titleLabel)
        
        
        if #available(iOS 13.0, *) {
            self.titleLabel.textColor = .label
        } else {
            self.titleLabel.textColor = UIColor.beeminder.gray
        }
        
        if let imageName = self.imageName {
            let image = UIImage(named: imageName)
            let imageView = UIImageView(image: image)
            
            
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
