//
//  RemoveHKMetricViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/9/18.
//  Copyright © 2018 APB. All rights reserved.
//

import UIKit
import SwiftyJSON
import OSLog

import BeeKit

class RemoveHKMetricViewController: UIViewController {
    private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "RemoveHKMetricViewController")
    
    var goal : Goal!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = .systemBackground
        self.title = "Remove HK Metric"
        
        let currentMetricLabel = BSLabel()
        self.view.addSubview(currentMetricLabel)
        
        currentMetricLabel.attributedText = {
            let attrString = NSMutableAttributedString()
            
            attrString.append(NSMutableAttributedString(string: "Configuring goal ",
                                                        attributes: [NSAttributedString.Key.font: UIFont.beeminder.defaultFont]))
            
            attrString.append(NSMutableAttributedString(string: "\(self.goal.slug)\n",
                attributes: [NSAttributedString.Key.font: UIFont.beeminder.defaultBoldFont]))
            
            attrString.append(NSMutableAttributedString(string: "This goal obtains its data from Apple Health (\(self.goal.humanizedAutodata!)). You can disconnect the goal with the button below.",
                attributes: [NSAttributedString.Key.font: UIFont.beeminder.defaultFontLight.withSize(Constants.defaultFontSize)]))
            return attrString
        }()
        
        
        currentMetricLabel.snp.makeConstraints { (make) in
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.topMargin).offset(20)
            make.centerX.equalTo(self.view)
            make.width.equalTo(self.view).multipliedBy(0.85)
        }
        currentMetricLabel.numberOfLines = 0
        currentMetricLabel.textAlignment = .center
        
        let removeButton = BSButton()
        self.view.addSubview(removeButton)
        removeButton.snp.makeConstraints { (make) in
            make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottomMargin).offset(-20)
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
        guard self.goal != nil else { return }
        self.goal?.autodata = ""
        let params: [String: [String: String]] = ["ii_params": ["name": "", "metric": ""]]
        let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
        hud.mode = .indeterminate

        Task { @MainActor in
            do {
                let responseObject = try await ServiceLocator.requestManager.put(url: "api/v1/users/\(ServiceLocator.currentUserManager.username!)/goals/\(self.goal!.slug).json", parameters: params)

                self.goal = Goal(json: JSON(responseObject!))

                hud.mode = .customView
                hud.customView = UIImageView(image: UIImage(named: "BasicCheckmark"))

                NotificationCenter.default.post(name: Notification.Name(rawValue: CurrentUserManager.healthKitMetricRemovedNotificationName), object: self, userInfo: ["goal": self.goal as Any])
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                    hud.hide(animated: true, afterDelay: 2)
                    self.navigationController?.popViewController(animated: true)
                })
            } catch {
                logger.error("Error disconnecting metric from apple heath: \(error)")
                // bar
            }
        }
    }
}
