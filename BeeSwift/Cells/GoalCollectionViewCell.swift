//
//  GoalCollectionViewCell.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/24/15.
//  Copyright 2015 APB. All rights reserved.
//

import BeeKit
import Foundation

class GoalCollectionViewCell: UICollectionViewCell {
  private let cardView = CardView()
  private let thumbnailImageView = GoalImageView(isThumbnail: true)
  private let titleLabel = BSLabel()
  private let slugLabel = BSLabel()
  private let countdownLabel = BSLabel()
  private let todaytaLabel = BSLabel()
  override init(frame: CGRect) {
    super.init(frame: frame)
    setupView()
  }
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    setupView()
  }
  private func setupView() {
    self.contentView.backgroundColor = .clear
    self.contentView.addSubview(self.cardView)
    self.cardView.backgroundColor = .secondarySystemGroupedBackground
    self.cardView.layer.cornerRadius = CardLookConstants.cornerRadius
    self.cardView.layer.shadowColor = UIColor.black.cgColor
    self.cardView.layer.shadowOpacity = 0.1
    self.cardView.layer.shadowRadius = 4
    self.cardView.layer.shadowOffset = CardLookConstants.shadowOffset

    self.slugLabel.textColor = .label
    self.cardView.snp.makeConstraints { make in make.edges.equalToSuperview().inset(6) }
    [self.thumbnailImageView, self.titleLabel, self.todaytaLabel, self.slugLabel, self.countdownLabel].forEach {
      self.cardView.addSubview($0)
    }
    self.thumbnailImageView.snp.makeConstraints { make in
      make.left.top.bottom.equalToSuperview().inset(CardLookConstants.spacing)
      make.width.equalTo(CGFloat(Constants.thumbnailWidth))
      make.height.equalTo(CGFloat(Constants.thumbnailHeight))
    }
    self.titleLabel.font = UIFont.beeminder.defaultFontHeavy.withSize(17)
    self.titleLabel.textColor = .label
    self.titleLabel.snp.makeConstraints { make in
      make.top.equalToSuperview().offset(CardLookConstants.verticalPadding)
      make.left.equalTo(self.thumbnailImageView.snp.right).offset(CardLookConstants.spacing)
      make.right.equalTo(self.todaytaLabel.snp.left).offset(-8)
    }
    self.todaytaLabel.textColor = .label
    self.todaytaLabel.font = UIFont.beeminder.defaultFont.withSize(14)
    self.todaytaLabel.textAlignment = .right
    self.todaytaLabel.snp.makeConstraints { make in
      make.centerY.equalTo(self.titleLabel)
      make.right.equalToSuperview().offset(-CardLookConstants.horizontalPadding)
    }
    self.todaytaLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    self.slugLabel.font = UIFont.beeminder.defaultFont.withSize(15)
    self.slugLabel.snp.makeConstraints { make in
      make.top.equalTo(self.titleLabel.snp.bottom).offset(2)
      make.left.right.equalTo(self.titleLabel)
    }
    self.countdownLabel.font = UIFont.beeminder.defaultBoldFont.withSize(13)
    self.countdownLabel.numberOfLines = 0
    self.countdownLabel.snp.makeConstraints { make in
      make.top.equalTo(self.slugLabel.snp.bottom).offset(4)
      make.left.right.equalTo(self.titleLabel)
      make.bottom.lessThanOrEqualToSuperview().offset(-CardLookConstants.verticalPadding)
    }
  }
  override func prepareForReuse() {
    super.prepareForReuse()
    self.configure(with: nil)
  }
  func configure(with goal: Goal?) {
    self.thumbnailImageView.goal = goal
    self.titleLabel.text = goal?.title
    self.slugLabel.text = goal?.slug
    self.titleLabel.isHidden = goal?.title == goal?.slug
    self.todaytaLabel.text = goal?.todayta == true ? "✓" : ""
    self.countdownLabel.text = goal?.capitalSafesum()
    self.countdownLabel.textColor = goal?.countdownColor ?? UIColor.Beeminder.SafetyBuffer.gray
  }
}
