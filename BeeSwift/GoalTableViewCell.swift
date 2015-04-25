//
//  GoalTableViewCell.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/24/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation

class GoalTableViewCell: UITableViewCell {
    var titleLabel :UILabel = UILabel()
    var thumbnailImageView :UIImageView = UIImageView()
    var rateLabel :UILabel = UILabel()
    var deltasLabel :UILabel = UILabel()
    var countdownView :UIView = UIView()
    var countdownLabel :UILabel = UILabel()
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.contentView.addSubview(self.titleLabel)
        self.contentView.addSubview(self.rateLabel)
        self.contentView.addSubview(self.thumbnailImageView)
        self.contentView.addSubview(self.deltasLabel)
        
        self.titleLabel.snp_makeConstraints { (make) -> Void in
            make.left.equalTo(0)
            make.top.equalTo(10)
        }

        self.thumbnailImageView.snp_makeConstraints { (make) -> Void in
            make.left.equalTo(0)
            make.top.equalTo(self.titleLabel.snp_bottom).offset(10)
        }
        
        self.rateLabel.snp_makeConstraints { (make) -> Void in
            make.left.equalTo(self.thumbnailImageView.snp_right).offset(10)
            make.top.equalTo(self.thumbnailImageView)
            make.bottom.equalTo(self.deltasLabel.snp_top)
        }

        self.deltasLabel.snp_makeConstraints { (make) -> Void in
            make.left.equalTo(self.rateLabel)
        }
    }

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
    }
    
    var goal :Goal?
    {
        didSet {
            self.titleLabel.text = goal!.title
            self.thumbnailImageView.setImageWithURL(NSURL(string: goal!.thumb_url))
            self.rateLabel.text = goal!.rateString
            self.deltasLabel.text = goal!.delta_text
        }
    }
}