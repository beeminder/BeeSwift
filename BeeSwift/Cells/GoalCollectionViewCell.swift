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
  private lazy var cardView: CardView = {
    let view = CardView()
    view.backgroundColor = .secondarySystemGroupedBackground
    view.layer.cornerRadius = CardLookConstants.cornerRadius
    view.layer.shadowColor = UIColor.black.cgColor
    view.layer.shadowOpacity = 0.1
    view.layer.shadowRadius = 4
    view.layer.shadowOffset = CardLookConstants.shadowOffset
    return view
  }()

  private lazy var thumbnailImageView: GoalImageView = { return GoalImageView(isThumbnail: true) }()

  private lazy var titleLabel: BSLabel = {
    let label = BSLabel()
    label.font = UIFont.beeminder.defaultFontHeavy.withSize(17)
    label.textColor = .label
    return label
  }()

  private lazy var slugLabel: BSLabel = {
    let label = BSLabel()
    label.font = UIFont.beeminder.defaultFont.withSize(15)
    label.textColor = .label
    return label
  }()

  private lazy var countdownLabel: BSLabel = {
    let label = BSLabel()
    label.font = UIFont.beeminder.defaultBoldFont.withSize(13)
    label.numberOfLines = 0
    return label
  }()

  private lazy var todaytaLabel: BSLabel = {
    let label = BSLabel()
    label.textColor = .label
    label.font = UIFont.beeminder.defaultFont.withSize(14)
    label.textAlignment = .right
    label.setContentCompressionResistancePriority(.required, for: .horizontal)
    return label
  }()

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

    self.cardView.snp.makeConstraints { make in make.edges.equalToSuperview().inset(6) }

    [self.thumbnailImageView, self.titleLabel, self.todaytaLabel, self.slugLabel, self.countdownLabel].forEach {
      self.cardView.addSubview($0)
    }

    self.thumbnailImageView.snp.makeConstraints { make in
      make.left.top.bottom.equalToSuperview().inset(CardLookConstants.spacing)
      make.width.equalTo(CGFloat(Constants.thumbnailWidth))
      make.height.equalTo(CGFloat(Constants.thumbnailHeight))
    }

    self.titleLabel.snp.makeConstraints { make in
      make.top.equalToSuperview().offset(CardLookConstants.verticalPadding)
      make.left.equalTo(self.thumbnailImageView.snp.right).offset(CardLookConstants.spacing)
      make.right.equalTo(self.todaytaLabel.snp.left).offset(-8)
    }

    self.todaytaLabel.snp.makeConstraints { make in
      make.centerY.equalTo(self.titleLabel)
      make.right.equalToSuperview().offset(-CardLookConstants.horizontalPadding)
    }

    self.slugLabel.snp.makeConstraints { make in
      make.top.equalTo(self.titleLabel.snp.bottom).offset(2)
      make.left.right.equalTo(self.titleLabel)
    }

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
