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
    
    private
    
    func configureCell() {
        self.selectionStyle = .None
        let graph = UIImageView()
        self.contentView.addSubview(graph)
        graph.snp_makeConstraints(closure: { (make) -> Void in
            make.width.equalTo(self.contentView).multipliedBy(0.4)
            make.height.equalTo(graph.snp_width).multipliedBy(122.0/200.0).priorityHigh()
            make.left.equalTo(0)
            make.top.equalTo(5)
            make.bottom.equalTo(-5)
        })
        graph.af_setImageWithURL(NSURL(string: self.goalDictionary["thumbUrl"] as! String)!)
        
        let textLabel = UILabel()
        self.contentView.addSubview(textLabel)
        textLabel.numberOfLines = 0
        textLabel.text = self.goalDictionary["limSum"] as? String
        textLabel.font = UIFont(name: "Avenir", size: 14)
        textLabel.textColor = UIColor.whiteColor()
        
        textLabel.snp_makeConstraints(closure: { (make) -> Void in
            make.left.equalTo(graph.snp_right).offset(10)
            make.centerY.equalTo(graph)
            make.right.equalTo(-10)
        })
    }
}