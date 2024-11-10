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

import BeeKit

class TodayTableViewCell: UITableViewCell {
    var goal: Goal? {
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
        guard let goal = self.goal else { return }

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
        self.setGraphImage(urlStr: goal.thumbUrl)

        self.addSubview(self.limitLabel)
        self.limitLabel.numberOfLines = 0
        self.limitLabel.text = "\(goal.slug.prefix(20)): \(goal.limSum)"
        self.limitLabel.font = UIFont.systemFont(ofSize: 14)
        
        self.limitLabel.snp.makeConstraints({ (make) -> Void in
            make.left.equalTo(self.graphImageView.snp.right).offset(10)
            make.top.equalTo(self.graphImageView).offset(5)
            make.right.equalTo(-10)
        })
        
        if goal.hideDataEntry {
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
        guard let goal = self.goal else { return }

        let hud = MBProgressHUD.showAdded(to: self, animated: true)
        hud.mode = .indeterminate
        self.addDataButton.isUserInteractionEnabled = false
        
        let urtextDaystamp = Daystamp.makeUrtextDaystamp(submissionDate: Date(), goal: goal)
        let value = Int(self.valueStepper.value)
        let comment = "Added via iOS widget"
        
        let params = ["urtext": "\(urtextDaystamp) \(value) \"\(comment)\"", "requestid": UUID().uuidString]
        let slug = goal.slug

        Task { @MainActor in
            do {
                let _ = try await ServiceLocator.requestManager.post(url: "api/v1/users/me/goals/\(slug)/datapoints.json", parameters: params)
            } catch {
                self.addDataButton.setTitle("oops!", for: .normal)
                return
            }

            self.pollUntilGraphUpdates()
        }
    }
    
    func pollUntilGraphUpdates() {
        if self.pollTimer != nil { return }
        self.pollTimer = Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(self.refreshGoal), userInfo: nil, repeats: true)
    }
    
    @objc func refreshGoal() {
        Task { @MainActor in
            guard let goal = self.goal else { return }
            let slug = goal.slug

            do {
                let responseObject = try await ServiceLocator.requestManager.get(url: "api/v1/users/me/goals/\(slug)", parameters: [:])
                let goalJSON = JSON(responseObject!)
                if (!goalJSON["queued"].bool!) {
                    self.pollTimer?.invalidate()
                    self.pollTimer = nil
                    let hud = MBProgressHUD.forView(self)
                    hud?.mode = .customView
                    hud?.customView = UIImageView(image: UIImage(named: "BasicCheckmark"))
                    hud?.hide(animated: true, afterDelay: 2)
                    self.valueStepper.value = 0
                    self.valueLabel.text = "0"
                    self.addDataButton.isUserInteractionEnabled = true
                    self.limitLabel.text = "\(slug): \(goalJSON["limsum"])"
                    let urlString = "\(goalJSON["thumb_url"])"
                    self.setGraphImage(urlStr: urlString)
                }
            } catch {
                // TODO: Log the error?
            }
        }
    }
    
    /// updates the graph, setting a placeholder
    /// and replacing it with the downloaded, updated image
    /// provided via the urlStr
    func setGraphImage(urlStr: String?) {
        guard !ServiceLocator.currentUserManager.isDeadbeat(),
        let thumbUrlStr = urlStr, let thumbUrl = URL(string: thumbUrlStr) else {
            self.graphImageView.image = self.thumbnailPlaceholder
            return
        }
        
        self.graphImageView.af.setImage(withURL: thumbUrl, placeholderImage: thumbnailPlaceholder, progressQueue: DispatchQueue.global(qos: .background), imageTransition: .crossDissolve(0.4), runImageTransitionIfCached: false)
    }
}
