//
//  GoalTableViewCell.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/24/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation

class GoalCollectionViewCell: UICollectionViewCell {
    var slugLabel :BSLabel = BSLabel()
    var titleLabel :BSLabel = BSLabel()
    var thumbnailImageView :UIImageView = UIImageView()
    var rateLabel :BSLabel = BSLabel()
    var deltasLabel :BSLabel = BSLabel()
    var countdownView :UIView = UIView()
    var countdownLabel :BSLabel = BSLabel()
    let margin = 8
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.contentView.addSubview(self.slugLabel)
        self.contentView.addSubview(self.titleLabel)
        self.contentView.addSubview(self.rateLabel)
        self.contentView.addSubview(self.thumbnailImageView)
        self.contentView.addSubview(self.deltasLabel)
        self.contentView.addSubview(self.countdownView)
        self.countdownView.addSubview(self.countdownLabel)
        
        self.slugLabel.font = UIFont(name: "Avenir-Heavy", size: 18)
        self.slugLabel.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(self.margin)
            make.top.equalTo(10)
            make.width.lessThanOrEqualTo(self.contentView).multipliedBy(0.35)
        }
        
        self.titleLabel.font = UIFont(name: "Avenir-Light", size: 18)
        self.titleLabel.snp.makeConstraints { (make) -> Void in
            make.centerY.equalTo(self.slugLabel)
            make.left.equalTo(self.slugLabel.snp.right).offset(10)
            make.width.lessThanOrEqualTo(self.contentView).multipliedBy(0.6)
        }
        self.titleLabel.textAlignment = .right
        
        self.countdownView.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(8)
            make.top.equalTo(self.slugLabel.snp.bottom).offset(5)
            make.bottom.equalTo(self.thumbnailImageView)
            make.width.equalTo(75)
        }
        
        self.countdownView.addSubview(self.countdownLabel)
        self.countdownLabel.textColor = UIColor.white
        self.countdownLabel.font = UIFont(name: "Avenir-Heavy", size: 18)
        self.countdownLabel.snp.makeConstraints { (make) -> Void in
            make.center.equalTo(self.countdownView)
        }

        self.thumbnailImageView.snp.makeConstraints { (make) -> Void in
            make.centerX.equalTo(0)
            make.top.equalTo(self.countdownView)
            make.height.equalTo(Constants.thumbnailHeight)
            make.width.equalTo(Constants.thumbnailWidth)
        }
        
        self.rateLabel.textAlignment = NSTextAlignment.center
        self.rateLabel.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(self.thumbnailImageView.snp.right).offset(5)
            make.bottom.equalTo(self.thumbnailImageView.snp.centerY)
            make.right.equalTo(-self.margin)
        }

        self.deltasLabel.textAlignment = NSTextAlignment.center
        self.deltasLabel.font = UIFont(name: "Avenir-Black", size: 13)
        self.deltasLabel.numberOfLines = 0
        self.deltasLabel.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(self.rateLabel)
            make.top.equalTo(self.thumbnailImageView.snp.centerY)
            make.right.equalTo(self.rateLabel)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(GoalCollectionViewCell.willSignOutNotificationReceived), name: NSNotification.Name(rawValue: CurrentUserManager.willSignOutNotificationName), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(GoalCollectionViewCell.willResetNotificationReceived), name: NSNotification.Name(rawValue: CurrentUserManager.willResetNotificationName), object: nil)
    }
    
    @objc func willSignOutNotificationReceived() {
        self.removeAllObservers()
        self.goal = nil
    }
    
    @objc func willResetNotificationReceived() {
        self.removeAllObservers()
        self.goal = nil
    }
    
    func deadbeatChanged() {
        self.setThumbnailImage()
    }
    
    func setThumbnailImage() {
        guard let _ = self.goal else { return } 
        if CurrentUserManager.sharedManager.isDeadbeat() {
            self.thumbnailImageView.image = UIImage(named: "ThumbnailPlaceholder")
        } else {
            self.thumbnailImageView.setImageWith(URL(string: goal!.cacheBustingThumbUrl)!, placeholderImage: UIImage(named: "ThumbnailPlaceholder"))
        }
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
    }
    
    func removeAllObservers() {
        self.goal?.removeObserver(self, forKeyPath: "thumb_url")
        self.goal?.removeObserver(self, forKeyPath: "losedate")
        self.goal?.removeObserver(self, forKeyPath: "lane")
        self.goal?.removeObserver(self, forKeyPath: "rate")
        self.goal?.removeObserver(self, forKeyPath: "title")
        self.goal?.removeObserver(self, forKeyPath: "delta_text")
    }
    
    deinit {
        self.removeAllObservers()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if (!CurrentUserManager.sharedManager.signedIn()) { return }
        if keyPath == "thumb_url" {
            self.thumbnailImageView.image = nil
            self.setThumbnailImage()
        } else if keyPath == "losedate" || keyPath == "lane" {
            self.countdownLabel.text = goal?.briefLosedate
            self.countdownView.backgroundColor = goal?.countdownColor
        } else if keyPath == "title" {
            self.titleLabel.text = goal?.title
        } else if keyPath == "rate" {
            self.rateLabel.text = goal?.rateString
        } else if keyPath == "delta_text" {
            self.deltasLabel.attributedText = goal?.attributedDeltaText
        }
    }
    
    var goal :Goal?
    {
        didSet {
            goal?.addObserver(self, forKeyPath: "thumb_url", options: [], context: nil)
            goal?.addObserver(self, forKeyPath: "losedate", options: [], context: nil)
            goal?.addObserver(self, forKeyPath: "lane", options: [], context: nil)
            goal?.addObserver(self, forKeyPath: "rate", options: [], context: nil)
            goal?.addObserver(self, forKeyPath: "title", options: [], context: nil)
            goal?.addObserver(self, forKeyPath: "delta_text", options: [], context: nil)
            self.thumbnailImageView.image = nil
            self.setThumbnailImage()

            if DataSyncManager.sharedManager.isFetching || goal == nil {
                self.countdownLabel.text = ""
                self.countdownView.backgroundColor = UIColor.beeGrayColor()
            } else {
                self.countdownLabel.text = goal!.briefLosedate
                self.countdownView.backgroundColor = goal!.countdownColor
            }

            self.titleLabel.text = goal?.title
            self.slugLabel.text = goal?.slug
            self.titleLabel.isHidden = goal?.title == goal?.slug
            self.rateLabel.text = goal?.rateString
            self.deltasLabel.attributedText = goal?.attributedDeltaText
        }
    }
}
