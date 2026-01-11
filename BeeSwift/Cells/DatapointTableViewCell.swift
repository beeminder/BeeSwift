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
  private static let font = UIFont.beeminder.defaultFontPlain.withSize(Constants.defaultFontSize)

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
    for label in [dayLabel, valueLabel, commentLabel] {
      label.font = Self.font
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

  func configure(datapoint: BeeDataPoint, hhmmformat: Bool, columnWidths: DatapointColumnWidths) {
    dayLabel.text = Self.formatDay(datapoint: datapoint)
    valueLabel.text = Self.formatValue(datapoint: datapoint, hhmmformat: hhmmformat)
    commentLabel.text = datapoint.comment

    dayWidthConstraint?.update(offset: columnWidths.dayWidth)
    valueWidthConstraint?.update(offset: columnWidths.valueWidth)

    // Update intrinsic size constraint for value overflow
    valueMinWidthConstraint?.update(offset: valueLabel.intrinsicContentSize.width)
  }

  public static func formatDay(datapoint: BeeDataPoint) -> String {
    let now = Date()
    let calendar = Calendar.current
    let currentMonth = calendar.component(.month, from: now)
    let currentYear = calendar.component(.year, from: now)

    let stamp = datapoint.daystamp
    if stamp.month != currentMonth || stamp.year != currentYear {
      return "\(stamp.month)/\(stamp.day)"
    } else {
      return String(stamp.day)
    }
  }

  public static func formatValue(datapoint: BeeDataPoint, hhmmformat: Bool) -> String {
    if hhmmformat {
      let value = datapoint.value.doubleValue
      let hours = Int(value)
      let minutes = Int((value.truncatingRemainder(dividingBy: 1) * 60).rounded()) % 60
      return String(hours) + ":" + String(format: "%02d", minutes)
    } else {
      return datapoint.value.stringValue
    }
  }

  public static func calculateColumnWidths(for datapoints: [BeeDataPoint], hhmmformat: Bool) -> DatapointColumnWidths {
    let attributes: [NSAttributedString.Key: Any] = [.font: font]
    let minWidth = ("0" as NSString).size(withAttributes: attributes).width

    // Measure actual day and value strings from data
    var dayWidths: [CGFloat] = []
    var valueWidths: [CGFloat] = []
    for datapoint in datapoints {
      let dayText = formatDay(datapoint: datapoint)
      dayWidths.append((dayText as NSString).size(withAttributes: attributes).width)

      let valueText = formatValue(datapoint: datapoint, hhmmformat: hhmmformat)
      valueWidths.append((valueText as NSString).size(withAttributes: attributes).width)
    }

    // Day column: always use max width (no overflow, dates should align)
    let dayWidth = dayWidths.max() ?? minWidth

    // Value column: use 75th percentile, but expand to max if not much wider
    let valueWidth = calculatePercentileWidth(widths: valueWidths, fallback: minWidth)

    return DatapointColumnWidths(dayWidth: ceil(dayWidth), valueWidth: ceil(valueWidth))
  }

  static func calculatePercentileWidth(widths: [CGFloat], fallback: CGFloat) -> CGFloat {
    guard !widths.isEmpty else { return fallback }

    let sorted = widths.sorted()
    let p75Index = min(sorted.count - 1, Int(ceil(Double(sorted.count) * 0.75)) - 1)
    let p75Width = sorted[max(0, p75Index)]
    let maxWidth = sorted.last!

    if maxWidth <= 60 || maxWidth <= p75Width * DatapointColumnWidths.overflowThreshold {
      return maxWidth
    } else {
      return p75Width
    }
  }
}
