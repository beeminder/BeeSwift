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
        self.leadTimeStepper.value = CurrentUserManager.shared.defaultLeadTime().doubleValue
        self.alertstart = CurrentUserManager.shared.defaultAlertstart()
        self.deadline = CurrentUserManager.shared.defaultDeadline()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func sendLeadTimeToServer(_ timer : Timer) {
        var userInfo = timer.userInfo! as! Dictionary<String, NSNumber>
        guard let leadtime = userInfo["leadtime"] as? NSNumber else { return }
        let params = [ "default_leadtime" : leadtime ]
        RequestManager.put(url: "api/v1/users/\(CurrentUserManager.shared.username!).json", parameters: params,
            success: { (responseObject) -> Void in
                CurrentUserManager.shared.setDefaultLeadTime(leadtime)
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
            RequestManager.put(url: "api/v1/users/\(CurrentUserManager.shared.username!).json", parameters: params,
                success: { (responseObject) -> Void in
                    CurrentUserManager.shared.setDefaultAlertstart(self.midnightOffsetFromTimePickerView())
                }) { (error) -> Void in
                    //foo
            }
        }
        if self.timePickerEditingMode == .deadline {
            self.updateDeadlineLabel(self.midnightOffsetFromTimePickerView())
            let params = ["default_deadline" : self.midnightOffsetFromTimePickerView()]
            RequestManager.put(url: "api/v1/users/\(CurrentUserManager.shared.username!).json", parameters: params,
                success: { (responseObject) -> Void in
                    CurrentUserManager.shared.setDefaultDeadline(self.midnightOffsetFromTimePickerView())
                }) { (error) -> Void in
                    //foo
            }
        }
    }
}
