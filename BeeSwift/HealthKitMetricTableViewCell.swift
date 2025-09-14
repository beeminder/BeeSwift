//
//  HealthKitMetricTableViewCell.swift
//  BeeSwift
//
//  Created by Andy Brett on 3/29/17.
//  Copyright 2017 APB. All rights reserved.
//

import BeeKit
import UIKit

class HealthKitMetricTableViewCell: UITableViewCell {

  var metric: String? { didSet { self.metricLabel.text = self.metric } }
  fileprivate let metricLabel = BSLabel()
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    self.configure()
  }
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    self.configure()
  }
  override func prepareForReuse() {
    super.prepareForReuse()
    self.metricLabel.text = nil
    self.metric = nil
  }
  func configure() {
    self.backgroundColor = UIColor.clear
    self.selectionStyle = .none
    self.contentView.addSubview(self.metricLabel)
    self.metricLabel.snp.makeConstraints { (make) -> Void in
      make.centerY.equalTo(self.contentView)
      make.left.equalTo(25)
      make.width.equalTo(self.contentView)
    }
  }
}
