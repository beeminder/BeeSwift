//
//  GoalTableViewCell.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/24/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation

class GoalCollectionViewCell: UICollectionViewCell {
    var titleLabel :BSLabel = BSLabel()
    var thumbnailImageView :UIImageView = UIImageView()
    var rateLabel :BSLabel = BSLabel()
    var deltasLabel :BSLabel = BSLabel()
    var countdownView :UIView = UIView()
    var countdownLabel :BSLabel = BSLabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.contentView.addSubview(self.titleLabel)
        self.contentView.addSubview(self.rateLabel)
        self.contentView.addSubview(self.thumbnailImageView)
        self.contentView.addSubview(self.deltasLabel)
        self.contentView.addSubview(self.countdownView)
        self.countdownView.addSubview(self.countdownLabel)
        
        self.titleLabel.font = UIFont(name: "Avenir-Heavy", size: 18)
        self.titleLabel.snp_makeConstraints { (make) -> Void in
            make.left.equalTo(8)
            make.top.equalTo(10)
        }

        self.thumbnailImageView.snp_makeConstraints { (make) -> Void in
            make.left.equalTo(8)
            make.top.equalTo(self.titleLabel.snp_bottom).offset(5)
            make.height.equalTo(70)
            make.width.equalTo(106)
        }
        
        self.rateLabel.textAlignment = NSTextAlignment.Center
        self.rateLabel.snp_makeConstraints { (make) -> Void in
            make.left.equalTo(self.thumbnailImageView.snp_right).offset(5)
            make.top.equalTo(self.thumbnailImageView)
            make.right.equalTo(self.countdownView.snp_left).offset(-5)
        }

        self.deltasLabel.textAlignment = NSTextAlignment.Center
        self.deltasLabel.font = UIFont(name: "Avenir-Black", size: 13)
        self.deltasLabel.snp_makeConstraints { (make) -> Void in
            make.left.equalTo(self.rateLabel)
            make.top.equalTo(self.rateLabel.snp_bottom).offset(10)
            make.right.equalTo(self.rateLabel)
        }
        
        self.countdownView.snp_makeConstraints { (make) -> Void in
            make.right.equalTo(0)
            make.top.equalTo(self.thumbnailImageView)
            make.bottom.equalTo(self.thumbnailImageView)
            make.width.equalTo(75)
        }
        
        self.countdownView.addSubview(self.countdownLabel)
        self.countdownLabel.textColor = UIColor.whiteColor()
        self.countdownLabel.font = UIFont(name: "Avenir-Heavy", size: 18)
        self.countdownLabel.snp_makeConstraints { (make) -> Void in
            make.center.equalTo(self.countdownView)
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
            self.thumbnailImageView.setImageWithURL(NSURL(string: goal!.cacheBustingThumbUrl))
            self.rateLabel.text = goal!.rateString
            self.deltasLabel.attributedText = goal!.attributedDeltaText
            self.countdownLabel.text = goal!.briefLosedate
            self.countdownView.backgroundColor = goal!.countdownColor
        }
    }
}