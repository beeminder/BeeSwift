//
//  DatapointTableViewCell.swift
//  BeeSwift
//
//  Created by Andy Brett on 5/12/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation

class DatapointTableViewCell : UITableViewCell {
    
    var datapointLabel = BSLabel()
    
    var datapointText : String?
    {
        didSet {
            self.datapointLabel.text = datapointText
        }
    }
    
    override required init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setup()        
    }
    
    func setup() {
        self.datapointLabel.font = UIFont.beeminder.defaultFontPlain.withSize(Constants.defaultFontSize)
        self.datapointLabel.lineBreakMode = .byTruncatingTail
        self.contentView.addSubview(self.datapointLabel)
        self.selectionStyle = .none
        self.datapointLabel.snp.makeConstraints({ (make) -> Void in
            make.left.equalTo(5)
            make.right.equalTo(-5)
            make.centerY.equalTo(self.contentView)
        })
    }
}
