//
//  EditGoalNotificationsViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 11/7/15.
//  Copyright © 2015 APB. All rights reserved.
//

import Foundation
import UIKit

class EditGoalNotificationsViewController : EditNotificationsViewController {
    var goal : JSONGoal? {
        didSet {

        }
    }
    fileprivate var useDefaultsSwitch = UISwitch()
    
    init(goal : JSONGoal) {
        super.init()
        self.goal = goal
        self.leadTimeStepper.value = goal.leadtime!.doubleValue
        self.alertstart = goal.alertstart!
        self.deadline = goal.deadline
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "\(self.goal!.title) Notifications"
        
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
        self.useDefaultsSwitch.isOn = (self.goal?.use_defaults!.boolValue)!
        self.useDefaultsSwitch.addTarget(self, action: #selector(EditGoalNotificationsViewController.useDefaultsSwitchValueChanged), for: .valueChanged)
        
        self.leadTimeLabel.snp.remakeConstraints { (make) -> Void in
            make.top.equalTo(self.useDefaultsSwitch.snp.bottom).offset(20)
            make.left.equalTo(20)
        }
    }
    
    override func sendLeadTimeToServer(_ timer : Timer) {
        Task {
            let userInfo = timer.userInfo! as! Dictionary<String, NSNumber>
            let leadtime = userInfo["leadtime"]
            let params = [ "leadtime" : leadtime, "use_defaults" : false ]
            do {
                let _ = try await RequestManager.put(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!)/goals/\(self.goal!.slug).json", parameters: params as [String : Any])
                DispatchQueue.main.sync {
                    self.goal!.leadtime = leadtime!
                    self.goal!.use_defaults = NSNumber(value: false as Bool)
                    self.useDefaultsSwitch.isOn = false
                }
            } catch {
                // TODO: Log error
                // show alert
            }
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if self.timePickerEditingMode == .alertstart {
            self.updateAlertstartLabel(self.midnightOffsetFromTimePickerView())
            Task {
                do {
                    let params = ["alertstart" : self.midnightOffsetFromTimePickerView(), "use_defaults" : false]
                    let _ = try await RequestManager.put(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!)/goals/\(self.goal!.slug).json", parameters: params)
                    DispatchQueue.main.sync {
                        self.goal!.alertstart = self.midnightOffsetFromTimePickerView()
                        self.goal!.use_defaults = NSNumber(value: false as Bool)
                        self.useDefaultsSwitch.isOn = false
                    }
                } catch {
                    // TODO: Log failure
                    //foo
                }
            }
        }
        if self.timePickerEditingMode == .deadline {
            self.updateDeadlineLabel(self.midnightOffsetFromTimePickerView())
            Task {
                do {
                    let params = ["deadline" : self.midnightOffsetFromTimePickerView(), "use_defaults" : false]
                    let _ = try await RequestManager.put(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!)/goals/\(self.goal!.slug).json", parameters: params)
                    DispatchQueue.main.sync {
                        self.goal?.deadline = self.midnightOffsetFromTimePickerView()
                        self.goal!.use_defaults = NSNumber(value: false as Bool)
                        self.useDefaultsSwitch.isOn = false
                    }
                } catch {
                    let errorString = error.localizedDescription
                    DispatchQueue.main.sync {
                        MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
                        let alert = UIAlertController(title: "Error saving to Beeminder", message: errorString, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                        self.present(alert, animated: true, completion: nil)
                    }
                }
            }
        }
    }
    
    @objc func useDefaultsSwitchValueChanged() {
        if self.useDefaultsSwitch.isOn {
            let alertController = UIAlertController(title: "Confirm", message: "This will wipe out your current settings for this goal. Are you sure?", preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "Yes", style: .default, handler: { (action) -> Void in

                Task {
                    do {
                        let params = ["use_defaults" : true]
                        let _ = try await RequestManager.put(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!)/goals/\(self.goal!.slug).json", parameters: params)
                        self.goal?.use_defaults = NSNumber(value: true as Bool)
                        CurrentUserManager.sharedManager.syncNotificationDefaults({
                            DispatchQueue.main.sync {
                                self.leadTimeStepper.value = CurrentUserManager.sharedManager.defaultLeadTime().doubleValue
                                self.updateLeadTimeLabel()
                                self.alertstart = CurrentUserManager.sharedManager.defaultAlertstart()
                                self.deadline   = CurrentUserManager.sharedManager.defaultDeadline()
                                self.goal!.leadtime = CurrentUserManager.sharedManager.defaultLeadTime()
                                self.goal!.alertstart = CurrentUserManager.sharedManager.defaultAlertstart()
                                self.goal!.deadline = CurrentUserManager.sharedManager.defaultDeadline()
                                self.timePickerEditingMode = self.timePickerEditingMode // trigger the setter which updates the timePicker components
                            }
                        }) {
                            // TODO: Log failure
                            // foo
                        }
                    } catch {
                        // TODO: Log failure
                        // foo
                    }
                }
            }))
            alertController.addAction(UIAlertAction(title: "No", style: .cancel, handler: { (action) -> Void in
                self.useDefaultsSwitch.isOn = false
            }))
            self.present(alertController, animated: true, completion: nil)
        }
        else {
            Task {
                do {
                    let params = ["use_defaults" : false]
                    let _ = try await RequestManager.put(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!)/goals/\(self.goal!.slug).json", parameters: params)
                        self.goal?.use_defaults = NSNumber(value: false as Bool)
                } catch {
                    // TODO: Log error
                    // foo
                }
            }
        }
    }
}
