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
  let slugLabel: BSLabel = BSLabel()
  let titleLabel: BSLabel = BSLabel()
  let todaytaLabel: BSLabel = BSLabel()
  let thumbnailImageView = GoalImageView(isThumbnail: true)
  let safesumLabel: BSLabel = BSLabel()
  lazy var dueByDeltasLabel: BSLabel = {
    let label = BSLabel()
    label.textAlignment = NSTextAlignment.center
    label.font = UIFont.beeminder.defaultBoldFont.withSize(13)
    label.numberOfLines = 0
    return label
  }()
  let margin = 8
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.contentView.addSubview(self.slugLabel)
    self.contentView.addSubview(self.titleLabel)
    self.contentView.addSubview(self.todaytaLabel)
    self.contentView.addSubview(self.thumbnailImageView)
    self.contentView.addSubview(self.safesumLabel)
    self.contentView.addSubview(self.dueByDeltasLabel)
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
    self.dueByDeltasLabel.snp.makeConstraints { make in
      make.left.equalTo(self.thumbnailImageView.snp.right).offset(5)
      make.top.equalTo(self.safesumLabel.snp.bottom).offset(6)
      make.right.equalTo(-self.margin)
    }
  }
  required init?(coder aDecoder: NSCoder) { super.init(coder: aDecoder) }
  override func prepareForReuse() {
    super.prepareForReuse()
    configure(with: nil)
  }
  func configure(with goal: Goal?) {
    self.thumbnailImageView.goal = goal
    self.titleLabel.text = goal?.title
    self.slugLabel.text = goal?.slug
    self.titleLabel.isHidden = goal?.title == goal?.slug
    self.todaytaLabel.text = goal?.todayta == true ? "✓" : ""
    self.safesumLabel.text = goal?.capitalSafesum()
    self.safesumLabel.textColor = goal?.countdownColor ?? UIColor.Beeminder.gray
    self.dueByDeltasLabel.attributedText = goal?.dueByTableAttributedString
    self.dueByDeltasLabel.isHidden = goal == nil || goal?.dueByContainsSpecificAmounts == false
  }
}

extension Goal {
  fileprivate var dueByContainsSpecificAmounts: Bool {
    self.dueBy.values.map { $0.formattedDelta }.joined(separator: " ").contains(where: { $0.isNumber })
  }
  fileprivate var dueByTableAttributedString: NSAttributedString {
    let textAndColor: [(text: String, color: UIColor)] = dueBy.sorted(using: SortDescriptor(\.key)).compactMap({
      $0.value.formattedDelta
    }).map { $0 == "✔" ? "✓" : $0 }.enumerated().map { offset, element in
      var color: UIColor {
        switch offset {
        case 0: return UIColor.Beeminder.SafetyBuffer.orange
        case 1: return UIColor.Beeminder.SafetyBuffer.blue
        case 2: return UIColor.Beeminder.SafetyBuffer.green
        default: return .label.withAlphaComponent(0.8)
        }
      }
      return (text: element, color: color)
    }
    let attrStr = NSMutableAttributedString()
    textAndColor.map { (text: String, color: UIColor) in
      NSAttributedString(string: text + " ", attributes: [.foregroundColor: color])
    }.forEach { attrStr.append($0) }
    return attrStr
  }
}
