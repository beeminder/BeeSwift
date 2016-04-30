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
    var goal : Goal? {
        didSet {

        }
    }
    private var useDefaultsSwitch = UISwitch()
    
    init(goal : Goal) {
        super.init()
        self.goal = goal
        self.leadTimeStepper.value = goal.leadtime.doubleValue
        self.alertstart = goal.alertstart
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
        useDefaultsLabel.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(self.snp_topLayoutGuideBottom).offset(20)
            make.left.equalTo(self.leadTimeLabel)
        }
        
        self.view.addSubview(self.useDefaultsSwitch)
        self.useDefaultsSwitch.snp_makeConstraints { (make) -> Void in
            make.centerY.equalTo(useDefaultsLabel)
            make.right.equalTo(-20)
        }
        self.useDefaultsSwitch.on = (self.goal?.use_defaults.boolValue)!
        self.useDefaultsSwitch.addTarget(self, action: "useDefaultsSwitchValueChanged", forControlEvents: .ValueChanged)
        
        self.leadTimeLabel.snp_remakeConstraints { (make) -> Void in
            make.top.equalTo(self.useDefaultsSwitch.snp_bottom).offset(20)
            make.left.equalTo(20)
        }
    }
    
    override func sendLeadTimeToServer(timer : NSTimer) {
        let leadtime = timer.userInfo!["leadtime"] as! NSNumber
        let params = [ "leadtime" : leadtime, "use_defaults" : false ]
        BSHTTPSessionManager.sharedManager.PUT("api/v1/users/me/goals/\(self.goal!.slug).json", parameters: params,
            success: { (task, responseObject) -> Void in
                self.goal!.leadtime = leadtime
                self.goal!.use_defaults = NSNumber(bool: false)
                self.useDefaultsSwitch.on = false
                NSManagedObjectContext.MR_defaultContext().MR_saveToPersistentStoreWithCompletion { (success, error) -> Void in
                    //completion
                }
            }) { (task, error) -> Void in
                // show alert
        }
    }
    
    func pickerView(pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if self.timePickerEditingMode == .Alertstart {
            self.updateAlertstartLabel(self.midnightOffsetFromTimePickerView())
            let params = ["alertstart" : self.midnightOffsetFromTimePickerView(), "use_defaults" : false]
            BSHTTPSessionManager.sharedManager.PUT("api/v1/users/me/goals/\(self.goal!.slug).json", parameters: params,
                success: { (task, responseObject) -> Void in
                    self.goal!.alertstart = self.midnightOffsetFromTimePickerView()
                    self.goal!.use_defaults = NSNumber(bool: false)
                    self.useDefaultsSwitch.on = false
                    NSManagedObjectContext.MR_defaultContext().MR_saveToPersistentStoreWithCompletion { (success, error) -> Void in
                        //completion
                    }
                }) { (task, error) -> Void in
                    //foo
            }
        }
        if self.timePickerEditingMode == .Deadline {
            self.updateDeadlineLabel(self.midnightOffsetFromTimePickerView())
            let params = ["deadline" : self.midnightOffsetFromTimePickerView(), "use_defaults" : false]
            BSHTTPSessionManager.sharedManager.PUT("api/v1/users/me/goals/\(self.goal!.slug).json", parameters: params,
                success: { (task, responseObject) -> Void in
                    self.goal?.deadline = self.midnightOffsetFromTimePickerView()
                    self.goal!.use_defaults = NSNumber(bool: false)
                    self.useDefaultsSwitch.on = false
                    NSManagedObjectContext.MR_defaultContext().MR_saveToPersistentStoreWithCompletion({ (success, error) -> Void in
                        //foo
                    })
                }) { (task, error) -> Void in
                    //foo
            }
        }
    }
    
    func useDefaultsSwitchValueChanged() {
        if self.useDefaultsSwitch.on {
            let alertController = UIAlertController(title: "Confirm", message: "This will wipe out your current settings for this goal. Are you sure?", preferredStyle: .Alert)
            alertController.addAction(UIAlertAction(title: "Yes", style: .Default, handler: { (action) -> Void in
                let params = ["use_defaults" : true]
                BSHTTPSessionManager.sharedManager.PUT("api/v1/users/me/goals/\(self.goal!.slug).json", parameters: params,
                    success: { (task, responseObject) -> Void in
                        self.goal?.use_defaults = NSNumber(bool: true)
                        NSManagedObjectContext.MR_defaultContext().MR_saveToPersistentStoreWithCompletion({ (success, error) -> Void in
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
                            NSManagedObjectContext.MR_defaultContext().MR_saveToPersistentStoreWithCompletion({ (success, error) -> Void in
                                //foo
                            })
                            }, failure: { () -> Void in
                                // foo
                        })
                    }) { (task, error) -> Void in
                        //foo
                }
            }))
            alertController.addAction(UIAlertAction(title: "No", style: .Cancel, handler: { (action) -> Void in
                self.useDefaultsSwitch.on = false
            }))
            self.presentViewController(alertController, animated: true, completion: nil)
        }
        else {
            let params = ["use_defaults" : false]
            BSHTTPSessionManager.sharedManager.PUT("api/v1/users/me/goals/\(self.goal!.slug).json", parameters: params,
                success: { (task, responseObject) -> Void in
                    self.goal?.use_defaults = NSNumber(bool: false)
                    NSManagedObjectContext.MR_defaultContext().MR_saveToPersistentStoreWithCompletion({ (success, error) -> Void in
                        //foo
                    })
                }) { (task, error) -> Void in
                    //foo
            }
        }
    }
}