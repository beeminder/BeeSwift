//
//  DatapointTableViewCell.swift
//  BeeSwift
//
//  Created by Andy Brett on 5/12/15.
//  Copyright 2015 APB. All rights reserved.
//

import BeeKit
import Foundation
import SnapKit

class DatapointTableViewCell: UITableViewCell {
  private let dayLabel = BSLabel()
  private let valueLabel = BSLabel()
  private let commentLabel = BSLabel()

  private var dayWidthConstraint: Constraint?
  private var valueWidthConstraint: Constraint?
  private var valueMinWidthConstraint: Constraint?

  override required init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    self.setup()
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    self.setup()
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    dayLabel.text = nil
    valueLabel.text = nil
    commentLabel.text = nil
  }

  func setup() {
    let font = UIFont.beeminder.defaultFontPlain.withSize(Constants.defaultFontSize)

    for label in [dayLabel, valueLabel, commentLabel] {
      label.font = font
      contentView.addSubview(label)
    }

    dayLabel.textAlignment = .left
    valueLabel.textAlignment = .right  // Numbers right-align for comparison
    commentLabel.textAlignment = .left
    commentLabel.lineBreakMode = .byTruncatingTail

    selectionStyle = .none

    let spacing = DatapointColumnWidths.columnSpacing

    dayLabel.snp.makeConstraints { make in
      make.left.equalToSuperview()
      make.centerY.equalToSuperview()
      // Day column uses max width, no overflow needed
      dayWidthConstraint = make.width.equalTo(0).constraint
    }

    valueLabel.snp.makeConstraints { make in
      make.left.equalTo(dayLabel.snp.right).offset(spacing)
      make.centerY.equalToSuperview()
      // Target width for column alignment (medium priority, can be overridden)
      valueWidthConstraint = make.width.equalTo(0).priority(.medium).constraint
      // Minimum width to prevent clipping (high priority, ensures content visible)
      valueMinWidthConstraint = make.width.greaterThanOrEqualTo(0).priority(.high).constraint
    }

    commentLabel.snp.makeConstraints { make in
      make.left.equalTo(valueLabel.snp.right).offset(spacing)
      make.right.lessThanOrEqualToSuperview()
      make.centerY.equalToSuperview()
    }
  }

  func configure(day: String, value: String, comment: String, columnWidths: DatapointColumnWidths) {
    dayLabel.text = day
    valueLabel.text = value
    commentLabel.text = comment

    dayWidthConstraint?.update(offset: columnWidths.dayWidth)
    valueWidthConstraint?.update(offset: columnWidths.valueWidth)

    // Update intrinsic size constraint for value overflow
    valueMinWidthConstraint?.update(offset: valueLabel.intrinsicContentSize.width)
  }
}
