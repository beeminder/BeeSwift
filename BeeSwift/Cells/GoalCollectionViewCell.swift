//
//  GoalTableViewCell.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/24/15.
//  Copyright 2015 APB. All rights reserved.
//

import BeeKit
import Foundation

class GoalCollectionViewCell: UICollectionViewCell {
  private static let expandedHeight: CGFloat = 120
  private static let collapsedHeight: CGFloat = 44

  static func cellHeight(for goal: Goal?) -> CGFloat {
    guard let goal = goal else { return expandedHeight }
    return goal.isPastDeadline ? collapsedHeight : expandedHeight
  }

  let slugLabel: BSLabel = BSLabel()
  let titleLabel: BSLabel = BSLabel()
  let todaytaLabel: BSLabel = BSLabel()
  let thumbnailImageView = GoalImageView(isThumbnail: true)
  let safesumLabel: BSLabel = BSLabel()
  let margin = 8

  override init(frame: CGRect) {
    super.init(frame: frame)
    self.contentView.addSubview(self.slugLabel)
    self.contentView.addSubview(self.titleLabel)
    self.contentView.addSubview(self.todaytaLabel)
    self.contentView.addSubview(self.thumbnailImageView)
    self.contentView.addSubview(self.safesumLabel)
    self.contentView.backgroundColor = .systemBackground

    self.slugLabel.font = UIFont.beeminder.defaultFontHeavy
    self.slugLabel.textColor = .label
    self.slugLabel.snp.makeConstraints { (make) -> Void in
      make.left.equalTo(self.margin)
      make.top.equalTo(10)
      make.width.lessThanOrEqualTo(self.contentView).multipliedBy(0.35)
    }
    self.titleLabel.font = UIFont.beeminder.defaultFont
    self.titleLabel.textColor = .label
    self.titleLabel.textAlignment = .left
    self.titleLabel.snp.makeConstraints { (make) -> Void in
      make.centerY.equalTo(self.slugLabel)
      make.left.equalTo(self.slugLabel.snp.right).offset(10)
      make.right.lessThanOrEqualTo(self.todaytaLabel.snp.left).offset(-10)
    }
    self.todaytaLabel.font = UIFont.beeminder.defaultFont
    self.todaytaLabel.textColor = .label
    self.todaytaLabel.textAlignment = .right
    self.todaytaLabel.snp.makeConstraints { (make) -> Void in
      make.centerY.equalTo(self.slugLabel)
      make.right.equalTo(-self.margin)
    }
    self.todaytaLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

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
  required init?(coder aDecoder: NSCoder) { super.init(coder: aDecoder) }
  override func prepareForReuse() {
    super.prepareForReuse()
    configure(with: nil)
  }
  func configure(with goal: Goal?) {
    let collapsed = goal?.isPastDeadline ?? false

    self.thumbnailImageView.goal = goal
    self.slugLabel.text = goal?.slug
    self.safesumLabel.textColor = goal?.countdownColor ?? UIColor.Beeminder.gray

    if collapsed {
      // Collapsed mode: single line with slug on left, safesum on right
      self.titleLabel.isHidden = true
      self.todaytaLabel.isHidden = true
      self.thumbnailImageView.isHidden = true
      self.safesumLabel.text = goal?.capitalSafesum()

      // Reposition safesum to the right side of the cell, centered vertically
      self.safesumLabel.snp.remakeConstraints { make in
        make.right.equalTo(-self.margin)
        make.centerY.equalToSuperview()
      }
      self.safesumLabel.textAlignment = .right

      // Center the slug vertically for collapsed mode
      self.slugLabel.snp.remakeConstraints { make in
        make.left.equalTo(self.margin)
        make.centerY.equalToSuperview()
        make.right.lessThanOrEqualTo(self.safesumLabel.snp.left).offset(-10)
      }
    } else {
      // Expanded mode: normal layout with thumbnail
      self.titleLabel.text = goal?.title
      self.titleLabel.isHidden = goal?.title == goal?.slug
      self.todaytaLabel.text = goal?.todayta == true ? "✓" : ""
      self.todaytaLabel.isHidden = false
      self.thumbnailImageView.isHidden = false
      self.safesumLabel.text = goal?.capitalSafesum()

      // Restore original constraints for expanded mode
      self.slugLabel.snp.remakeConstraints { make in
        make.left.equalTo(self.margin)
        make.top.equalTo(10)
        make.width.lessThanOrEqualTo(self.contentView).multipliedBy(0.35)
      }
      self.safesumLabel.snp.remakeConstraints { make in
        make.left.equalTo(self.thumbnailImageView.snp.right).offset(5)
        make.centerY.equalTo(self.thumbnailImageView.snp.centerY)
        make.right.equalTo(-self.margin)
      }
      self.safesumLabel.textAlignment = .center
    }
  }
}
