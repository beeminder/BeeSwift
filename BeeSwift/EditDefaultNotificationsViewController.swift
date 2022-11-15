//
//  EditDefaultNotificationsViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 11/7/15.
//  Copyright © 2015 APB. All rights reserved.
//

import Foundation
import OSLog

class EditDefaultNotificationsViewController: EditNotificationsViewController {
    private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "EditDefaultNotificationsViewController")
    
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
        Task {
            let userInfo = timer.userInfo! as! Dictionary<String, NSNumber>
            guard let leadtime = userInfo["leadtime"] else { return }
            let params = [ "default_leadtime" : leadtime ]
            do {
                let _ = try await RequestManager.put(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!).json", parameters: params)
                CurrentUserManager.sharedManager.setDefaultLeadTime(leadtime)
            } catch {
                logger.error("Error setting default leadtime: \(error)")
                // show alert
            }
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
            Task {
                do {
                    let _ = try await RequestManager.put(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!).json", parameters: params)
                    CurrentUserManager.sharedManager.setDefaultAlertstart(self.midnightOffsetFromTimePickerView())
                } catch {
                    logger.error("Error setting default alert start: \(error)")
                    //foo
                }
            }
        }
        if self.timePickerEditingMode == .deadline {
            self.updateDeadlineLabel(self.midnightOffsetFromTimePickerView())
            let params = ["default_deadline" : self.midnightOffsetFromTimePickerView()]
            Task {
                do {
                    let _ = try await RequestManager.put(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!).json", parameters: params)
                    CurrentUserManager.sharedManager.setDefaultDeadline(self.midnightOffsetFromTimePickerView())
                } catch {
                    logger.error("Error setting default deadline: \(error)")
                    //foo
                }
            }
        }
    }
}
