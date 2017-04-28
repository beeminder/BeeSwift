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
import AFNetworking
import MBProgressHUD
import SwiftyJSON

class TodayTableViewCell: UITableViewCell {
    var goalDictionary:NSDictionary = [:] {
        didSet {
            self.configureCell()
        }
    }
    
    let valueLabel = BSLabel()
    let valueStepper = UIStepper()
    let limitLabel = BSLabel()
    var addDataButton = BSButton()
    var pollTimer : Timer?
    
    fileprivate
    
    func configureCell() {
        self.selectionStyle = .none
        let graph = UIImageView()
        self.addSubview(graph)
        graph.snp.makeConstraints({ (make) -> Void in
            make.width.equalTo(Constants.thumbnailWidth)
            make.height.equalTo(Constants.thumbnailHeight)
            make.left.equalTo(16)
            make.top.equalTo(20)
            make.bottom.equalTo(-20)
        })
        graph.af_setImage(withURL: URL(string: self.goalDictionary["thumbUrl"] as! String)!)
        
        self.addSubview(self.limitLabel)
        self.limitLabel.numberOfLines = 0
        self.limitLabel.text = self.goalDictionary["limSum"] as? String
        self.limitLabel.font = UIFont.systemFont(ofSize: 14)
        
        self.limitLabel.snp.makeConstraints({ (make) -> Void in
            make.left.equalTo(graph.snp.right).offset(10)
            make.top.equalTo(graph).offset(5)
            make.right.equalTo(-10)
        })
        
        self.addSubview(self.addDataButton)
        self.addDataButton.snp.makeConstraints { (make) in
            make.bottom.equalTo(graph)
            make.right.equalTo(-10)
        }
        self.addDataButton.setTitle("Add data", for: .normal)
        self.addDataButton.setTitleColor(UIColor.black, for: .normal)
        self.addDataButton.addTarget(self, action: #selector(self.addDataButtonPressed), for: .touchUpInside)
        
        self.valueStepper.addTarget(self, action: #selector(self.valueStepperChanged), for: .valueChanged)
        self.valueStepper.tintColor = UIColor.darkGray
        self.valueStepper.minimumValue = -1000000
        self.valueStepper.maximumValue = 1000000
        self.addSubview(self.valueStepper)
        self.valueStepper.snp.makeConstraints { (make) in
            make.right.equalTo(self.addDataButton.snp.left).offset(-10)
            make.centerY.equalTo(self.addDataButton)
        }
        
        self.addSubview(self.valueLabel)
        self.valueLabel.snp.makeConstraints { (make) in
            make.centerY.equalTo(self.addDataButton)
            make.left.equalTo(self.limitLabel)
            make.right.equalTo(self.valueStepper.snp.left).offset(-10)
        }
        self.valueLabel.text = "0"
        self.valueLabel.textAlignment = .center
    }
    
    func valueStepperChanged() {
        self.valueLabel.text = "\(Int(self.valueStepper.value))"
    }
    
    func addDataButtonPressed() {
        let hud = MBProgressHUD.showAdded(to: self, animated: true)
        hud?.mode = .indeterminate
        self.addDataButton.isUserInteractionEnabled = false

        let defaults = UserDefaults(suiteName: "group.beeminder.beeminder")
        guard let token = defaults?.object(forKey: "accessToken") as? String else { return }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        let params = ["access_token": token, "urtext": "\(formatter.string(from: Date())) \(Int(self.valueStepper.value)) \"Added via iOS widget\"", "requestid": UUID().uuidString]
        guard let slug = self.goalDictionary["slug"] as? String else { return }
        
        let manager = AFHTTPSessionManager.init(baseURL: URL.init(string: "https://www.beeminder.com"), sessionConfiguration: nil)
            
        manager.post("api/v1/users/me/goals/\(slug)/datapoints.json", parameters: params, progress: nil, success: { (dataTask, responseObject) in
            self.pollUntilGraphUpdates()
        }) { (dataTask, error) in
            self.addDataButton.setTitle("oops!", for: .normal)
        }
    }
    
    func pollUntilGraphUpdates() {
        if self.pollTimer != nil { return }
        self.pollTimer = Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(self.refreshGoal), userInfo: nil, repeats: true)
    }
    
    func refreshGoal() {
        let defaults = UserDefaults(suiteName: "group.beeminder.beeminder")
        guard let token = defaults?.object(forKey: "accessToken") as? String else { return }
        guard let slug = self.goalDictionary["slug"] as? String else { return }
        
        let manager = AFHTTPSessionManager.init(baseURL: URL.init(string: "https://www.beeminder.com"), sessionConfiguration: nil)
        
        
        
        manager.get("/api/v1/users/me/goals/\(slug)?access_token=\(token)", parameters: nil, success: { (dataTask, responseObject) -> Void in
            var goalJSON = JSON(responseObject!)
            if (!goalJSON["queued"].bool!) {
                self.pollTimer?.invalidate()
                self.pollTimer = nil
                let hud = MBProgressHUD.allHUDs(for: self).first as? MBProgressHUD
                hud?.mode = .customView
                hud?.customView = UIImageView(image: UIImage(named: "checkmark"))
                hud?.hide(true, afterDelay: 2)
                self.valueStepper.value = 0
                self.valueLabel.text = "0"
                self.addDataButton.isUserInteractionEnabled = true
                self.limitLabel.text = "\(slug): \(goalJSON["limsum"])"
            }
        }) { (dataTask, responseError) -> Void in
            //foo
        }
    }
}
