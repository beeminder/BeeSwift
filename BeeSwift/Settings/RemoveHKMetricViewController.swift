//
//  RemoveHKMetricViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/9/18.
//  Copyright 2018 APB. All rights reserved.
//

import UIKit
import SwiftyJSON
import OSLog

import BeeKit

class RemoveHKMetricViewController: UIViewController {
    private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "RemoveHKMetricViewController")
    
    let goal: Goal
    private let requestManager: RequestManager
    private let goalManager: GoalManager
    
    init(goal: Goal, requestManager: RequestManager, goalManager: GoalManager) {
        self.goal = goal
        self.requestManager = requestManager
        self.goalManager = goalManager
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

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
            
            attrString.append(NSMutableAttributedString(string: "This goal obtains its data from Apple Health (\(self.goal.humanizedAutodata ?? self.goal.healthKitMetric ?? "unknown metric")). You can disconnect the goal with the button below.",
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
        let params: [String: [String: String?]] = ["ii_params": ["name": nil, "metric": ""]]
        let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
        hud.mode = .indeterminate

        Task { @MainActor in
            do {
                let _ = try await self.requestManager.put(url: "api/v1/users/{username}/goals/\(self.goal.slug).json", parameters: params)

                try await self.goalManager.refreshGoal(self.goal.objectID)

                hud.mode = .customView
                hud.customView = UIImageView(image: UIImage(systemName: "checkmark"))

                NotificationCenter.default.post(name: CurrentUserManager.NotificationName.healthKitMetricRemoved, object: self, userInfo: ["goal": self.goal as Any])
                
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
