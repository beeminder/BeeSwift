//
//  TodayTableViewCell.swift
//  BeeSwift
//
//  Created by Andy Brett on 10/15/15.
//  Copyright © 2015 APB. All rights reserved.
//

import Foundation
import UIKit
import Alamofire
import AlamofireImage

class TodayTableViewCell: UITableViewCell {
    var goalDictionary:NSDictionary = [:] {
        didSet {
            self.configureCell()
        }
    }
    
    fileprivate
    
    func configureCell() {
        self.selectionStyle = .none
        let graph = UIImageView()
        self.contentView.addSubview(graph)
        graph.snp.makeConstraints({ (make) -> Void in
            make.width.equalTo(self.contentView).multipliedBy(0.4)
            make.height.equalTo(graph.snp.width).multipliedBy(122.0/200.0).priorityHigh()
            make.left.equalTo(0)
            make.top.equalTo(5)
            make.bottom.equalTo(-5)
        })
        graph.af_setImage(withURL: URL(string: self.goalDictionary["thumbUrl"] as! String)!)
        
        let textLabel = UILabel()
        self.contentView.addSubview(textLabel)
        textLabel.numberOfLines = 0
        textLabel.text = self.goalDictionary["limSum"] as? String
        textLabel.font = UIFont.systemFont(ofSize: 14)
        textLabel.textColor = UIColor.white
        
        textLabel.snp.makeConstraints({ (make) -> Void in
            make.left.equalTo(graph.snp.right).offset(10)
            make.centerY.equalTo(graph)
            make.right.equalTo(-10)
        })
    }
}
