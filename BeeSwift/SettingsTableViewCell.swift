//
//  SettingsTableViewCell.swift
//  BeeSwift
//
//  Created by Andy Brett on 11/2/15.
//  Copyright © 2015 APB. All rights reserved.
//

import Foundation

import BeeKit

class SettingsTableViewCell: UITableViewCell {
    var title : String? {
        didSet {
            self.titleLabel.text = self.title
        }
    }
    
    // the name of the image to use, with preference of system image of that name followed by an app-bundled asset catalog image
    var imageName : String? {
        didSet {
            guard let imageName else {
                self.settingsImage.image = nil
                return
            }
            
            self.settingsImage.image = UIImage(systemName: imageName) ?? UIImage(named: imageName)
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
        self.backgroundColor = .secondarySystemBackground.withAlphaComponent(0.4)

        self.titleLabel.textColor = .label
        self.titleLabel.snp.remakeConstraints { (make) -> Void in
            make.centerY.equalTo(self.contentView)
            make.left.equalTo(self.settingsImage.snp.right).offset(10)
        }
        
        self.settingsImage.snp.remakeConstraints({ (make) in
            make.centerY.equalTo(self.contentView)
            make.left.equalTo(10)
            make.height.width.equalTo(26)
        })
        
        self.settingsImage.tintColor = dynamicImageTintColor
    }
    
    private let dynamicImageTintColor = UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .light:
            return UIColor.black
        default:
            return UIColor(red: 235.0/255.0,
                           green: 235.0/255.0,
                           blue: 235.0/255.0,
                           alpha: 1.0)
        }
    }
}
