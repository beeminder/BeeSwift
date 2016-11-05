//
//  EditDefaultNotificationsViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 11/7/15.
//  Copyright © 2015 APB. All rights reserved.
//

import Foundation

class EditDefaultNotificationsViewController: EditNotificationsViewController {
    
    override init() {
        super.init()
        self.leadTimeStepper.value = CurrentUserManager.sharedManager.defaultLeadTime().doubleValue
        self.alertstart = CurrentUserManager.sharedManager.defaultAlertstart()
        self.deadline = CurrentUserManager.sharedManager.defaultDeadline()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func sendLeadTimeToServer(_ timer : Timer) {
        var userInfo = timer.userInfo! as! Dictionary<String, NSNumber>
        let leadtime = userInfo["leadtime"]
        let params = [ "default_leadtime" : leadtime ]
        BSHTTPSessionManager.sharedManager.put("api/v1/users/me.json", parameters: params,
            success: { (task, responseObject) -> Void in
                CurrentUserManager.sharedManager.setDefaultLeadTime(leadtime!)
            }) { (task, error) -> Void in
                // show alert
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Defaults"
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if self.timePickerEditingMode == .alertstart {
            self.updateAlertstartLabel(self.midnightOffsetFromTimePickerView())
            let params = ["default_alertstart" : self.midnightOffsetFromTimePickerView()]
            BSHTTPSessionManager.sharedManager.put("api/v1/users/me.json", parameters: params as AnyObject?,
                success: { (task, responseObject) -> Void in
                    CurrentUserManager.sharedManager.setDefaultAlertstart(self.midnightOffsetFromTimePickerView())
                }) { (task, error) -> Void in
                    //foo
            }
        }
        if self.timePickerEditingMode == .deadline {
            self.updateDeadlineLabel(self.midnightOffsetFromTimePickerView())
            let params = ["default_deadline" : self.midnightOffsetFromTimePickerView()]
            BSHTTPSessionManager.sharedManager.put("api/v1/users/me.json", parameters: params as AnyObject?,
                success: { (task, responseObject) -> Void in
                    CurrentUserManager.sharedManager.setDefaultDeadline(self.midnightOffsetFromTimePickerView())
                }) { (task, error) -> Void in
                    //foo
            }
        }
    }
}
