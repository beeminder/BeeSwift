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

  var metric: HealthKitMetric? {
    didSet {
      metricLabel.text = metric?.humanText
      optionsIcon.isHidden = !(metric?.hasAdditionalOptions ?? false)
    }
  }
  fileprivate let metricLabel = BSLabel()
  fileprivate let optionsIcon = UIImageView()

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
    self.optionsIcon.isHidden = true
  }
  func configure() {
    self.backgroundColor = UIColor.clear
    self.selectionStyle = .none

    optionsIcon.image = UIImage(systemName: "slider.horizontal.3")
    optionsIcon.tintColor = .secondaryLabel
    optionsIcon.contentMode = .scaleAspectFit
    optionsIcon.isHidden = true
    contentView.addSubview(optionsIcon)
    optionsIcon.snp.makeConstraints { make in
      make.centerY.equalTo(contentView)
      make.right.equalTo(contentView).offset(-16)
      make.width.height.equalTo(20)
    }

    self.contentView.addSubview(self.metricLabel)
    self.metricLabel.snp.makeConstraints { (make) -> Void in
      make.centerY.equalTo(self.contentView)
      make.left.equalTo(25)
      make.right.equalTo(optionsIcon.snp.left).offset(-8)
    }
  }
}
