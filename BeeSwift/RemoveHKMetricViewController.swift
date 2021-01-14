//
//  RemoveHKMetricViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/9/18.
//  Copyright © 2018 APB. All rights reserved.
//

import UIKit
import SwiftyJSON

class RemoveHKMetricViewController: UIViewController {
    
    var goal : JSONGoal!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOS 13.0, *) {
            self.view.backgroundColor = .systemBackground
        } else {
            self.view.backgroundColor = .white
        }
        self.title = "Remove HK Metric"
        
        let currentMetricLabel = BSLabel()
        self.view.addSubview(currentMetricLabel)
        
        currentMetricLabel.attributedText = {
            let attrString = NSMutableAttributedString()
            
            attrString.append(NSMutableAttributedString(string: "Configuring goal ",
                                                        attributes: [NSAttributedStringKey.font: UIFont.beeminder.defaultFont]))
            
            attrString.append(NSMutableAttributedString(string: "\(self.goal.slug)\n",
                attributes: [NSAttributedStringKey.font: UIFont.beeminder.defaultBoldFont]))
            
            attrString.append(NSMutableAttributedString(string: "This goal obtains its data from Apple Health (\(self.goal.humanizedAutodata!)). You can disconnect the goal with the button below.",
                attributes: [NSAttributedStringKey.font: UIFont.beeminder.defaultFontLight.withSize(Constants.defaultFontSize)]))
            return attrString
        }()
        
        
        currentMetricLabel.snp.makeConstraints { (make) in
            make.top.equalTo(self.topLayoutGuide.snp.bottom).offset(20)
            make.centerX.equalTo(self.view)
            make.width.equalTo(self.view).multipliedBy(0.85)
        }
        currentMetricLabel.numberOfLines = 0
        currentMetricLabel.textAlignment = .center
        
        let removeButton = BSButton()
        self.view.addSubview(removeButton)
        removeButton.snp.makeConstraints { (make) in
            make.bottom.equalTo(self.bottomLayoutGuide.snp.top).offset(-20)
            make.centerX.equalTo(self.view)
            make.width.equalTo(self.view).multipliedBy(0.5)
            make.height.equalTo(Constants.defaultTextFieldHeight)
        }
        removeButton.setTitle("Disconnect", for: .normal)
        removeButton.addTarget(self, action: #selector(self.removeButtonPressed), for: .touchUpInside)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @objc func removeButtonPressed() {
        self.goal.autodata = ""
        let params: [String: [String: String]] = ["ii_params": ["name": "", "metric": ""]]
        let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
        hud?.mode = .indeterminate
        
        RequestManager.put(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!)/goals/\(self.goal.slug).json", parameters: params, success: { (responseObject) -> Void in
            
            self.goal = JSONGoal(json: JSON(responseObject!))

            hud?.mode = .customView
            hud?.customView = UIImageView(image: UIImage(named: "checkmark"))
            
            NotificationCenter.default.post(name: Notification.Name(rawValue: CurrentUserManager.healthKitMetricRemovedNotificationName), object: self, userInfo: ["goal": self.goal])
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                hud?.hide(true, afterDelay: 2)
                self.navigationController?.popViewController(animated: true)
            })
        }) { (error, errorMessage) -> Void in
            // bar
        }
    }
}
