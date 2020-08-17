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
        guard
            let userInfo = timer.userInfo as? [String: NSNumber],
            let leadtime = userInfo["leadtime"]
            else { return }
    
        let params = [ "default_leadtime" : leadtime ]
        RequestManager.put(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!).json", parameters: params,
            success: { (responseObject) -> Void in
                CurrentUserManager.sharedManager.setDefaultLeadTime(leadtime)
            }) { (error) -> Void in
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
            RequestManager.put(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!).json", parameters: params,
                success: { (responseObject) -> Void in
                    CurrentUserManager.sharedManager.setDefaultAlertstart(self.midnightOffsetFromTimePickerView())
                }) { (error) -> Void in
                    //foo
            }
        }
        if self.timePickerEditingMode == .deadline {
            self.updateDeadlineLabel(self.midnightOffsetFromTimePickerView())
            let params = ["default_deadline" : self.midnightOffsetFromTimePickerView()]
            RequestManager.put(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!).json", parameters: params,
                success: { (responseObject) -> Void in
                    CurrentUserManager.sharedManager.setDefaultDeadline(self.midnightOffsetFromTimePickerView())
                }) { (error) -> Void in
                    //foo
            }
        }
    }
}
