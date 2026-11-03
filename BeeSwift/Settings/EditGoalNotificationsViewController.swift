//
//  EditGoalNotificationsViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 11/7/15.
//  Copyright 2015 APB. All rights reserved.
//

import BeeKit
import CoreData
import Foundation
import OSLog
import UIKit

class EditGoalNotificationsViewController: EditNotificationsViewController {
  private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "EditGoalNotificationsViewController")

  let user: User
  let goal: Goal
  fileprivate var useDefaultsSwitch = UISwitch()
  private let currentUserManager: CurrentUserManager
  private let apiClient: APIClient
  private let goalManager: GoalManager
  private let viewContext: NSManagedObjectContext
  init(
    goal: Goal,
    currentUserManager: CurrentUserManager,
    apiClient: APIClient,
    goalManager: GoalManager,
    viewContext: NSManagedObjectContext,
  ) {
    self.currentUserManager = currentUserManager
    self.apiClient = apiClient
    self.goalManager = goalManager
    self.viewContext = viewContext
    self.goal = goal
    self.user = currentUserManager.user(context: viewContext)!
    super.init()
    self.leadTimeStepper.value = Double(goal.leadTime)
    self.alertstart = goal.alertStart
    self.deadline = goal.deadline
  }

  required init?(coder aDecoder: NSCoder) { return nil }
  override func viewDidLoad() {
    super.viewDidLoad()
    self.userActivity = .viewingGoal(self.goal)
    self.title = self.goal.slug
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
    self.useDefaultsSwitch.addTarget(
      self,
      action: #selector(EditGoalNotificationsViewController.useDefaultsSwitchValueChanged),
      for: .valueChanged,
    )
    self.leadTimeLabel.snp.remakeConstraints { (make) -> Void in
      make.top.equalTo(self.useDefaultsSwitch.snp.bottom).offset(20)
      make.left.equalTo(20)
    }
  }
  override func sendLeadTimeToServer(_ timer: Timer) {
    // We must not use `timer` in the Task as it may change once this method returns
    let userInfo = timer.userInfo! as! [String: NSNumber]
    Task { @MainActor in
      guard let leadtime = userInfo["leadtime"] else { return }
      do {
        let _ = try await self.apiClient.updateGoal(
          slug: self.goal.slug,
          leadtime: leadtime.intValue,
          usesDefaultNotifications: false,
        )

        try await self.goalManager.refreshGoal(self.goal.objectID)

      } catch {
        logger.error("Error sending lead time to server: \(error)")  // show alert
      }
    }
  }
  func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
    Task { @MainActor in
      let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
      hud.mode = .indeterminate
      if self.timePickerEditingMode == .alertstart {
        self.updateAlertstartLabel(self.midnightOffsetFromTimePickerView())
        do {
          let _ = try await self.apiClient.updateGoal(
            slug: self.goal.slug,
            alertstart: self.midnightOffsetFromTimePickerView(),
            usesDefaultNotifications: false,
          )
          try await self.goalManager.refreshGoal(self.goal.objectID)

          self.useDefaultsSwitch.isOn = false
          hud.hide(animated: true, afterDelay: 0.5)
        } catch {
          logger.error("Error setting alert start \(error)")
          //foo
          hud.hide(animated: true)
        }
      }
      if self.timePickerEditingMode == .deadline {
        let deadline = self.deadlineFromTimePickerView
        self.updateDeadlineLabel(deadline)
        do {
          let _ = try await self.apiClient.updateGoal(
            slug: self.goal.slug,
            deadline: deadline,
            usesDefaultNotifications: false,
          )
          try await self.goalManager.refreshGoal(self.goal.objectID)

          self.useDefaultsSwitch.isOn = false
          hud.hide(animated: true, afterDelay: 0.5)
        } catch {
          let errorString = error.localizedDescription
          MBProgressHUD.hide(for: self.view, animated: true)
          let alert = UIAlertController(
            title: "Error saving to Beeminder",
            message: errorString,
            preferredStyle: .alert,
          )
          alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
          self.present(alert, animated: true, completion: nil)
          hud.hide(animated: true)
        }
      }
    }
  }
  @objc func useDefaultsSwitchValueChanged() {
    if self.useDefaultsSwitch.isOn {
      let alertController = UIAlertController(
        title: "Confirm",
        message: "This will set this goal's notification settings to your default ones. Are you sure?",
        preferredStyle: .alert,
      )
      alertController.addAction(
        UIAlertAction(
          title: "Yes",
          style: .default,
          handler: { (action) -> Void in
            Task { @MainActor in
              let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
              hud.mode = .indeterminate
              do {
                let _ = try await self.apiClient.updateGoal(slug: self.goal.slug, usesDefaultNotifications: true)
                try await self.goalManager.refreshGoal(self.goal.objectID)
                hud.hide(animated: true, afterDelay: 0.5)
              } catch {
                self.logger.error("Error setting goal to use defaults: \(error)")
                // TODO: Show UI failure
                hud.hide(animated: true)
                return
              }

              do {
                try await self.goalManager.refreshGoals()
                hud.hide(animated: true, afterDelay: 0.5)
              } catch {
                self.logger.error("Error syncing notification defaults")
                // TODO: Show UI failure
                hud.hide(animated: true)
                return
              }

              self.leadTimeStepper.value = Double(self.user.defaultLeadTime)
              self.updateLeadTimeLabel()
              self.alertstart = self.user.defaultAlertStart
              self.deadline = self.user.defaultDeadline
              // Trigger the setter which updates the time picker components.
              self.timePickerEditingMode = self.timePickerEditingMode
            }
          },
        )
      )
      alertController.addAction(
        UIAlertAction(
          title: "No",
          style: .cancel,
          handler: { (action) -> Void in self.useDefaultsSwitch.isOn = false },
        )
      )
      self.present(alertController, animated: true, completion: nil)
    } else {
      Task { @MainActor in
        let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
        hud.mode = .indeterminate
        do {
          let _ = try await self.apiClient.updateGoal(slug: self.goal.slug, usesDefaultNotifications: false)
          try await self.goalManager.refreshGoal(self.goal.objectID)
          hud.hide(animated: true, afterDelay: 0.5)
        } catch {
          logger.error("Error setting goal to NOT use defaults: \(error)")
          // foo
          hud.hide(animated: true)
        }
      }
    }
  }
}
