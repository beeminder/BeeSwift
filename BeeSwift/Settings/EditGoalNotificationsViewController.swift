//
//  EditGoalNotificationsViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 11/7/15.
//  Copyright 2015 APB. All rights reserved.
//

import Foundation
import UIKit
import OSLog
import CoreData

import BeeKit

class EditGoalNotificationsViewController : EditNotificationsViewController {
    private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "EditGoalNotificationsViewController")

    let user: User
    let goal: Goal
    fileprivate var useDefaultsSwitch = UISwitch()
    private let currentUserManager: CurrentUserManager
    private let requestManager: RequestManager
    private let goalManager: GoalManager
    private let viewContext: NSManagedObjectContext
    
    init(goal: Goal,
         currentUserManager: CurrentUserManager,
         requestManager: RequestManager,
         goalManager: GoalManager,
         viewContext: NSManagedObjectContext) {
        self.currentUserManager = currentUserManager
        self.requestManager = requestManager
        self.goalManager = goalManager
        self.viewContext = viewContext
        self.goal = goal
        self.user = currentUserManager.user(context: viewContext)!
        
        super.init()
        self.leadTimeStepper.value = Double(goal.leadTime)
        self.alertstart = goal.alertStart
        self.deadline = goal.deadline
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "\(self.goal.title) Notifications"
        
        let useDefaultsLabel = BSLabel()
        useDefaultsLabel.text = "Use defaults"
        self.view.addSubview(useDefaultsLabel)
        useDefaultsLabel.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.topMargin).offset(20)
            make.left.equalTo(self.leadTimeLabel)
        }
        
        self.view.addSubview(self.useDefaultsSwitch)
        self.useDefaultsSwitch.snp.makeConstraints { (make) -> Void in
            make.centerY.equalTo(useDefaultsLabel)
            make.right.equalTo(-20)
        }
        self.useDefaultsSwitch.isOn = self.goal.useDefaults
        self.useDefaultsSwitch.addTarget(self, action: #selector(EditGoalNotificationsViewController.useDefaultsSwitchValueChanged), for: .valueChanged)
        
        self.leadTimeLabel.snp.remakeConstraints { (make) -> Void in
            make.top.equalTo(self.useDefaultsSwitch.snp.bottom).offset(20)
            make.left.equalTo(20)
        }
    }
    
    override func sendLeadTimeToServer(_ timer : Timer) {
        // We must not use `timer` in the Task as it may change once this method returns
        let userInfo = timer.userInfo! as! Dictionary<String, NSNumber>
        Task { @MainActor in
            let leadtime = userInfo["leadtime"]
            let params = [ "leadtime" : leadtime, "use_defaults" : false ]
            do {
                let _ = try await self.requestManager.put(url: "api/v1/users/{username}/goals/\(self.goal.slug).json", parameters: params as [String : Any])

                try await self.goalManager.refreshGoal(self.goal.objectID)

            } catch {
                logger.error("Error sending lead time to server: \(error)")
                // show alert
            }
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        Task { @MainActor in
            if self.timePickerEditingMode == .alertstart {
                self.updateAlertstartLabel(self.midnightOffsetFromTimePickerView())
                do {
                    let params = ["alertstart" : self.midnightOffsetFromTimePickerView(), "use_defaults" : false]
                    let _ = try await self.requestManager.put(url: "api/v1/users/{username}/goals/\(self.goal.slug).json", parameters: params)
                    try await self.goalManager.refreshGoal(self.goal.objectID)

                    self.useDefaultsSwitch.isOn = false
                } catch {
                    logger.error("Error setting alert start \(error)")
                    //foo
                }
            }
            if self.timePickerEditingMode == .deadline {
                self.updateDeadlineLabel(self.midnightOffsetFromTimePickerView())
                do {
                    let params = ["deadline" : self.midnightOffsetFromTimePickerView(), "use_defaults" : false]
                    let _ = try await self.requestManager.put(url: "api/v1/users/{username}/goals/\(self.goal.slug).json", parameters: params)
                    try await self.goalManager.refreshGoal(self.goal.objectID)

                    self.useDefaultsSwitch.isOn = false
                } catch {
                    let errorString = error.localizedDescription
                    MBProgressHUD.hide(for: self.view, animated: true)
                    let alert = UIAlertController(title: "Error saving to Beeminder", message: errorString, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
    }
    
    @objc func useDefaultsSwitchValueChanged() {
        if self.useDefaultsSwitch.isOn {
            let alertController = UIAlertController(title: "Confirm", message: "This will wipe out your current settings for this goal. Are you sure?", preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "Yes", style: .default, handler: { (action) -> Void in
                Task { @MainActor in
                    do {
                        let params = ["use_defaults" : true]
                        let _ = try await self.requestManager.put(url: "api/v1/users/{username}/goals/\(self.goal.slug).json", parameters: params)
                        try await self.goalManager.refreshGoal(self.goal.objectID)
                    } catch {
                        self.logger.error("Error setting goal to use defaults: \(error)")
                        // TODO: Show UI failure
                        return
                    }

                    do {
                        try await self.currentUserManager.refreshUser()
                    } catch {
                        self.logger.error("Error syncing notification defaults")
                        // TODO: Show UI failure
                        return
                    }

                    self.leadTimeStepper.value = Double(self.user.defaultLeadTime)
                    self.updateLeadTimeLabel()
                    self.alertstart = self.user.defaultAlertStart
                    self.deadline   = self.user.defaultDeadline
                    self.timePickerEditingMode = self.timePickerEditingMode // trigger the setter which updates the timePicker components
                }
            }))
            alertController.addAction(UIAlertAction(title: "No", style: .cancel, handler: { (action) -> Void in
                self.useDefaultsSwitch.isOn = false
            }))
            self.present(alertController, animated: true, completion: nil)
        }
        else {
            Task { @MainActor in
                do {
                    let params = ["use_defaults" : false]
                    let _ = try await self.requestManager.put(url: "api/v1/users/{username}/goals/\(self.goal.slug).json", parameters: params)
                    try await self.goalManager.refreshGoal(self.goal.objectID)
                } catch {
                    logger.error("Error setting goal to NOT use defaults: \(error)")
                    // foo
                }
            }
        }
    }
}
