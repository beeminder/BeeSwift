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
            make.top.equalTo(self.topLayoutGuide.snp.bottom).offset(20)
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
        var userInfo = timer.userInfo! as! Dictionary<String, NSNumber>
        let leadtime = userInfo["leadtime"]
        let params = [ "leadtime" : leadtime, "use_defaults" : false ]
        RequestManager.put(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!)/goals/\(self.goal!.slug).json", parameters: params,
            success: { (responseObject) -> Void in
                self.goal!.leadtime = leadtime!
                self.goal!.use_defaults = NSNumber(value: false as Bool)
                self.useDefaultsSwitch.isOn = false
                NSManagedObjectContext.mr_default().mr_saveToPersistentStore { (success, error) -> Void in
                    //completion
                }
            }) { (error) -> Void in
                // show alert
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if self.timePickerEditingMode == .alertstart {
            self.updateAlertstartLabel(self.midnightOffsetFromTimePickerView())
            let params = ["alertstart" : self.midnightOffsetFromTimePickerView(), "use_defaults" : false]
            RequestManager.put(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!)/goals/\(self.goal!.slug).json", parameters: params,
                success: { (responseObject) -> Void in
                    self.goal!.alertstart = self.midnightOffsetFromTimePickerView()
                    self.goal!.use_defaults = NSNumber(value: false as Bool)
                    self.useDefaultsSwitch.isOn = false
                    NSManagedObjectContext.mr_default().mr_saveToPersistentStore { (success, error) -> Void in
                        //completion
                    }
                }) { (error) -> Void in
                    //foo
            }
        }
        if self.timePickerEditingMode == .deadline {
            self.updateDeadlineLabel(self.midnightOffsetFromTimePickerView())
            let params = ["deadline" : self.midnightOffsetFromTimePickerView(), "use_defaults" : false]
            RequestManager.put(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!)/goals/\(self.goal!.slug).json", parameters: params,
                success: { (responseObject) -> Void in
                    self.goal?.deadline = self.midnightOffsetFromTimePickerView()
                    self.goal!.use_defaults = NSNumber(value: false as Bool)
                    self.useDefaultsSwitch.isOn = false
                    NSManagedObjectContext.mr_default().mr_saveToPersistentStore(completion: { (success, error) -> Void in
                        //foo
                    })
                }) { (error) -> Void in
                    //foo
            }
        }
    }
    
    @objc func useDefaultsSwitchValueChanged() {
        if self.useDefaultsSwitch.isOn {
            let alertController = UIAlertController(title: "Confirm", message: "This will wipe out your current settings for this goal. Are you sure?", preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "Yes", style: .default, handler: { (action) -> Void in
                let params = ["use_defaults" : true]
                RequestManager.put(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!)/goals/\(self.goal!.slug).json", parameters: params,
                    success: { (responseObject) -> Void in
                        self.goal?.use_defaults = NSNumber(value: true as Bool)
                        NSManagedObjectContext.mr_default().mr_saveToPersistentStore(completion: { (success, error) -> Void in
                            //foo
                        })
                        CurrentUserManager.sharedManager.syncNotificationDefaults({ () -> Void in
                            self.leadTimeStepper.value = CurrentUserManager.sharedManager.defaultLeadTime().doubleValue
                            self.updateLeadTimeLabel()
                            self.alertstart = CurrentUserManager.sharedManager.defaultAlertstart()
                            self.deadline   = CurrentUserManager.sharedManager.defaultDeadline()
                            self.goal!.leadtime = CurrentUserManager.sharedManager.defaultLeadTime()
                            self.goal!.alertstart = CurrentUserManager.sharedManager.defaultAlertstart()
                            self.goal!.deadline = CurrentUserManager.sharedManager.defaultDeadline()
                            self.timePickerEditingMode = self.timePickerEditingMode // trigger the setter which updates the timePicker components
                            NSManagedObjectContext.mr_default().mr_saveToPersistentStore(completion: { (success, error) -> Void in
                                //foo
                            })
                            }, failure: { () -> Void in
                                // foo
                        })
                    }) { (error) -> Void in
                        //foo
                }
            }))
            alertController.addAction(UIAlertAction(title: "No", style: .cancel, handler: { (action) -> Void in
                self.useDefaultsSwitch.isOn = false
            }))
            self.present(alertController, animated: true, completion: nil)
        }
        else {
            let params = ["use_defaults" : false]
            RequestManager.put(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!)/goals/\(self.goal!.slug).json", parameters: params,
                success: { (responseObject) -> Void in
                    self.goal?.use_defaults = NSNumber(value: false as Bool)
                    NSManagedObjectContext.mr_default().mr_saveToPersistentStore(completion: { (success, error) -> Void in
                        //foo
                    })
                }) { (error) -> Void in
                    //foo
            }
        }
    }
}
