//
//  EditDefaultNotificationsViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 11/7/15.
//  Copyright 2015 APB. All rights reserved.
//

import Foundation
import OSLog
import CoreData

import BeeKit

class EditDefaultNotificationsViewController: EditNotificationsViewController {
    private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "EditDefaultNotificationsViewController")

    private let user: User
    private let currentUserManager: CurrentUserManager
    private let requestManager: RequestManager
    private let goalManager: GoalManager
    private let viewContext: NSManagedObjectContext

    init(currentUserManager: CurrentUserManager, requestManager: RequestManager, goalManager: GoalManager, viewContext: NSManagedObjectContext) {
        self.currentUserManager = currentUserManager
        self.requestManager = requestManager
        self.goalManager = goalManager
        self.viewContext = viewContext
        self.user = currentUserManager.user(context: viewContext)!
        super.init()
        self.leadTimeStepper.value = Double(user.defaultLeadTime)
        self.alertstart = self.user.defaultAlertStart
        self.deadline = self.user.defaultDeadline
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func sendLeadTimeToServer(_ timer : Timer) {
        // We must not use `timer` in the Task as it may change once this method returns
        let userInfo = timer.userInfo! as! Dictionary<String, NSNumber>
        Task { @MainActor in
            guard let leadtime = userInfo["leadtime"] else { return }
            let params = [ "default_leadtime" : leadtime ]
            do {
                let _ = try await requestManager.put(url: "api/v1/users/{username}.json", parameters: params)
                try await goalManager.refreshGoals()
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
        Task { @MainActor in
            if self.timePickerEditingMode == .alertstart {
                self.updateAlertstartLabel(self.midnightOffsetFromTimePickerView())
                let params = ["default_alertstart" : self.midnightOffsetFromTimePickerView()]
                do {
                    let _ = try await requestManager.put(url: "api/v1/users/{username}.json", parameters: params)
                    try await goalManager.refreshGoals()
                } catch {
                    logger.error("Error setting default alert start: \(error)")
                    //foo
                }
            }
            if self.timePickerEditingMode == .deadline {
                self.updateDeadlineLabel(self.midnightOffsetFromTimePickerView())
                let params = ["default_deadline" : self.midnightOffsetFromTimePickerView()]
                do {
                    let _ = try await requestManager.put(url: "api/v1/users/{username}.json", parameters: params)
                    try await goalManager.refreshGoals()
                } catch {
                    logger.error("Error setting default deadline: \(error)")
                    //foo
                }
            }
        }
    }
}
