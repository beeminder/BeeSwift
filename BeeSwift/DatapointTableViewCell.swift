//
//  DatapointTableViewCell.swift
//  BeeSwift
//
//  Created by Andy Brett on 5/12/15.
//  Copyright 2015 APB. All rights reserved.
//

import BeeKit
import Foundation

class DatapointTableViewCell: UITableViewCell {
  let datapointLabel = BSLabel()
  var datapointText: String? { didSet { self.datapointLabel.text = datapointText } }
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
    self.datapointLabel.text = nil
    self.datapointText = nil
  }
  func setup() {
    self.datapointLabel.font = UIFont.beeminder.defaultFontPlain.withSize(Constants.defaultFontSize)
    self.datapointLabel.lineBreakMode = .byTruncatingTail
    self.contentView.addSubview(self.datapointLabel)
    self.selectionStyle = .none
    self.datapointLabel.snp.makeConstraints({ (make) -> Void in
      make.left.equalTo(0)
      make.right.equalTo(0)
      make.centerY.equalTo(self.contentView)
    })
  }
}
