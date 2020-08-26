//
//  GoalTableViewCell.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/24/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation

class GoalCollectionViewCell: UICollectionViewCell {
    let slugLabel :BSLabel = BSLabel()
    let titleLabel :BSLabel = BSLabel()
    let thumbnailImageView :UIImageView = UIImageView()
    let safesumLabel :BSLabel = BSLabel()
    let margin = 8
    
    var goal: JSONGoal? {
        didSet {
            self.thumbnailImageView.image = nil
            self.setThumbnailImage()
            self.titleLabel.text = goal?.title
            self.slugLabel.text = goal?.slug
            self.titleLabel.isHidden = goal?.title == goal?.slug
            self.safesumLabel.text = goal?.capitalSafesum()
            self.safesumLabel.textColor = goal?.countdownColor ?? UIColor.beeminder.gray
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.contentView.addSubview(self.slugLabel)
        self.contentView.addSubview(self.titleLabel)
        self.contentView.addSubview(self.thumbnailImageView)
        self.contentView.addSubview(self.safesumLabel)
        if #available(iOS 13.0, *) {
            self.contentView.backgroundColor = .systemBackground
        }
        self.slugLabel.font = UIFont.beeminder.defaultFontHeavy
        self.slugLabel.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(self.margin)
            make.top.equalTo(10)
            make.width.lessThanOrEqualTo(self.contentView).multipliedBy(0.35)
        }
        if #available(iOS 13.0, *) {
            self.slugLabel.textColor = .label
        }
        
        self.titleLabel.font = UIFont.beeminder.defaultFont
        if #available(iOS 13.0, *) {
            self.titleLabel.textColor = .label
        }
        self.titleLabel.snp.makeConstraints { (make) -> Void in
            make.centerY.equalTo(self.slugLabel)
            make.left.equalTo(self.slugLabel.snp.right).offset(10)
            make.width.lessThanOrEqualTo(self.contentView).multipliedBy(0.6)
        }
        self.titleLabel.textAlignment = .right

        self.thumbnailImageView.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(0).offset(self.margin)
            make.top.equalTo(self.slugLabel.snp.bottom).offset(5)
            make.height.equalTo(Constants.thumbnailHeight)
            make.width.equalTo(Constants.thumbnailWidth)
        }

        self.safesumLabel.textAlignment = NSTextAlignment.center
        self.safesumLabel.font = UIFont.beeminder.defaultBoldFont.withSize(13)
        self.safesumLabel.numberOfLines = 0
        self.safesumLabel.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(self.thumbnailImageView.snp.right).offset(5)
            make.centerY.equalTo(self.thumbnailImageView.snp.centerY)
            make.right.equalTo(-self.margin)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        self.slugLabel.text = nil
        self.titleLabel.text = nil
        self.thumbnailImageView.image = UIImage(named: "ThumbnailPlaceholder")
        self.safesumLabel.text = nil
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
            self.thumbnailImageView.af_setImage(withURL: URL(string: self.goal!.cacheBustingThumbUrl)!, placeholderImage: UIImage(named: "ThumbnailPlaceholder"), filter: nil, progress: nil, progressQueue: DispatchQueue.global(), imageTransition: .noTransition, runImageTransitionIfCached: false, completion: nil)
        }
    }
}
