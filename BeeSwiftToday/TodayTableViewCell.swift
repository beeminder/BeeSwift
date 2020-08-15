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
    let addDataButton = BSButton()
    var pollTimer : Timer?
    let graphImageView = UIImageView()
    
    var thumbnailPlaceholder: UIImage? {
        UIImage(named: "ThumbnailPlaceholder")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        self.valueLabel.text = nil
        self.limitLabel.text = nil
        self.addDataButton.titleLabel?.text = nil
        self.graphImageView.image = self.thumbnailPlaceholder
    }
    
    fileprivate func configureCell() {
        self.selectionStyle = .none
        
        self.addSubview(self.graphImageView)
        self.graphImageView.snp.makeConstraints({ (make) -> Void in
            make.width.equalTo(Constants.thumbnailWidth)
            make.height.equalTo(Constants.thumbnailHeight)
            make.left.equalTo(16)
            make.top.equalTo(20)
            make.bottom.equalTo(-20)
        })
        self.graphImageView.image = self.thumbnailPlaceholder
        self.setGraphImage(urlStr: self.goalDictionary["thumbUrl"] as? String)
        
        self.addSubview(self.limitLabel)
        self.limitLabel.numberOfLines = 0
        self.limitLabel.text = self.goalDictionary["limSum"] as? String
        self.limitLabel.font = UIFont.systemFont(ofSize: 14)
        
        self.limitLabel.snp.makeConstraints({ (make) -> Void in
            make.left.equalTo(self.graphImageView.snp.right).offset(10)
            make.top.equalTo(self.graphImageView).offset(5)
            make.right.equalTo(-10)
        })
        
        if self.goalDictionary["hideDataEntry"] as! Bool {
            self.limitLabel.snp.remakeConstraints({ (make) in
                make.left.equalTo(self.graphImageView.snp.right).offset(10)
                make.centerY.equalTo(self.graphImageView)
                make.right.equalTo(-10)
            })
            return
        }
        
        self.addSubview(self.addDataButton)
        self.addDataButton.snp.makeConstraints { (make) in
            make.bottom.equalTo(self.graphImageView)
            make.right.equalTo(-10)
        }
        
        var addTitle = "Add"
        // small screen hack
        if (UIDevice.current.orientation == .landscapeRight || UIDevice.current.orientation == .landscapeLeft && UIScreen.main.bounds.height >= 375) ||
           (UIScreen.main.bounds.width >= 375) {
            addTitle = "Add data"
        }
        self.addDataButton.setTitle(addTitle, for: .normal)
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
    
    @objc func valueStepperChanged() {
        self.valueLabel.text = "\(Int(self.valueStepper.value))"
    }
    
    @objc func addDataButtonPressed() {
        guard let slug = self.goalDictionary["slug"] as? String else { return }

        let hud = MBProgressHUD.showAdded(to: self, animated: true)
        hud?.mode = .indeterminate
        self.addDataButton.isUserInteractionEnabled = false

        guard let token = self.defaults?.object(forKey: "accessToken") as? String else { return }
        guard let username = self.defaults?.object(forKey: "username") as? String else { return }

        
        // if the goal's deadline is after midnight, and it's after midnight,
        // but before the deadline,
        // default to entering data for the "previous" day.
        let now = Date()
        var offset: Double = 0
        let calendar = Calendar.current
        let components = (calendar as NSCalendar).components([.hour, .minute], from: now)
        let currentHour = components.hour
        guard let goalDeadline = self.goalDictionary["deadline"] as? Int else { return }
        if goalDeadline > 0 && currentHour! < 6 && goalDeadline/3600 < currentHour! {
            offset = -1
        }
        
        // if the goal's deadline is before midnight and has already passed for this calendar day, default to entering data for the "next" day
        if goalDeadline < 0 {
            let deadlineSecondsAfterMidnight = 24*3600 + goalDeadline
            let deadlineHour = deadlineSecondsAfterMidnight/3600
            let deadlineMinute = (deadlineSecondsAfterMidnight % 3600)/60
            let currentMinute = components.minute
            if deadlineHour < currentHour! ||
                (deadlineHour == currentHour! && deadlineMinute < currentMinute!) {
                offset = 1
            }
        }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "d"
        
        let params = ["access_token": token, "urtext": "\(formatter.string(from: Date(timeIntervalSinceNow: offset*24*3600))) \(Int(self.valueStepper.value)) \"Added via iOS widget\"", "requestid": UUID().uuidString]
        
        RequestManager.post(url: "api/v1/users/\(username)/goals/\(slug)/datapoints.json", parameters: params, success: { (responseJSON) in
            self.pollUntilGraphUpdates()
        }) { (responseError, errorMessage) in
            self.addDataButton.setTitle("oops!", for: .normal)
        }
    }
    
    func pollUntilGraphUpdates() {
        guard self.pollTimer == nil else { return }
        self.pollTimer = Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(self.refreshGoal), userInfo: nil, repeats: true)
    }
    
    @objc func refreshGoal() {
        guard let slug = self.goalDictionary["slug"] as? String else { return }
        guard let token = self.defaults?.object(forKey: "accessToken") as? String else { return }
        guard let username = self.defaults?.object(forKey: "username") as? String else { return }
        
        let parameters = ["access_token": token]
        RequestManager.get(url: "api/v1/users/\(username)/goals/\(slug)", parameters: parameters, success: { (responseObject) in
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
                let urlString = "\(goalJSON["thumb_url"])"
                self.setGraphImage(urlStr: urlString)
            }
        }) { (responseError, errorMessage) in
            //
        }
    }
    
    /// updates the graph, setting a placeholder
    /// and replacing it with the downloaded, updated image
    /// provided via the urlStr
    func setGraphImage(urlStr: String?) {
        guard !CurrentUserManager.sharedManager.isDeadbeat(),
        let thumbUrlStr = urlStr, let thumbUrl = URL(string: thumbUrlStr) else {
            self.graphImageView.image = self.thumbnailPlaceholder
            return
        }
        
        self.graphImageView.af_setImage(withURL: thumbUrl, placeholderImage: thumbnailPlaceholder, progressQueue: DispatchQueue.global(qos: .background), imageTransition: .crossDissolve(0.4), runImageTransitionIfCached: false)
    }
    
    /// UserDefaults shared between app and extension
    var defaults: UserDefaults? {
        return UserDefaults(suiteName: "group.beeminder.beeminder")
    }
}
