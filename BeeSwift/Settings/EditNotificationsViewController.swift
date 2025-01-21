//
//  EditGoalNotificationsViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 11/2/15.
//  Copyright 2015 APB. All rights reserved.
//

import BeeKit
import Foundation

class EditNotificationsViewController: UIViewController {
  enum TimePickerEditingMode { case alertstart, deadline }
  var timePickerEditingMode: TimePickerEditingMode? {
    didSet {
      if self.timePickerEditingMode == nil {
        self.timePickerView.isHidden = true
      } else if self.timePickerEditingMode == .alertstart {
        self.timePickerView.isHidden = false
        self.setTimePickerComponents(self.alertstart)
        self.alertStartLabel.font = UIFont.beeminder.defaultBoldFont
        self.deadlineLabel.font = UIFont.beeminder.defaultFont
      } else if self.timePickerEditingMode == .deadline {
        self.timePickerView.isHidden = false
        self.setTimePickerComponents(self.deadline)
        self.alertStartLabel.font = UIFont.beeminder.defaultFont
        self.deadlineLabel.font = UIFont.beeminder.defaultBoldFont
      }
    }
  }
  var timePickerView = UIPickerView()
  var leadTimeLabel = BSLabel()
  var leadTimeStepper = UIStepper()
  var alertStartLabel = BSLabel()
  var deadlineLabel = BSLabel()
  var alertstart = Int() { didSet { self.updateAlertstartLabel(self.alertstart) } }
  var deadline = Int() { didSet { self.updateDeadlineLabel(self.deadline) } }
  fileprivate var leadTimeDelayTimer: Timer?
  init() { super.init(nibName: nil, bundle: nil) }
  required init?(coder aDecoder: NSCoder) { super.init(coder: aDecoder) }
  override func viewDidLoad() {
    self.view.backgroundColor = UIColor.systemBackground
    self.view.addSubview(self.leadTimeLabel)
    self.leadTimeLabel.snp.makeConstraints { (make) -> Void in
      make.left.equalTo(10)
      make.top.equalTo(self.view.safeAreaLayoutGuide.snp.topMargin).offset(20)
    }
    self.leadTimeStepper.minimumValue = 0
    self.leadTimeStepper.maximumValue = 30
    self.leadTimeStepper.tintColor = UIColor.Beeminder.gray
    self.leadTimeStepper.addTarget(
      self,
      action: #selector(EditNotificationsViewController.leadTimeStepperValueChanged),
      for: .valueChanged
    )
    self.view.addSubview(self.leadTimeStepper)
    self.leadTimeStepper.snp.makeConstraints { (make) -> Void in
      make.centerY.equalTo(self.leadTimeLabel)
      make.left.equalTo(self.leadTimeLabel.snp.right).offset(10)
    }
    self.updateLeadTimeLabel()
    self.view.addSubview(self.alertStartLabel)
    self.alertStartLabel.snp.makeConstraints { (make) -> Void in
      make.left.equalTo(self.leadTimeLabel)
      make.top.equalTo(self.leadTimeStepper.snp.bottom).offset(20)
    }
    self.alertStartLabel.isUserInteractionEnabled = true
    let tapGR = UITapGestureRecognizer(
      target: self,
      action: #selector(EditNotificationsViewController.alertstartLabelTapped)
    )
    self.alertStartLabel.addGestureRecognizer(tapGR)
    self.updateAlertstartLabel(self.alertstart)
    self.view.addSubview(self.deadlineLabel)
    self.deadlineLabel.snp.makeConstraints { (make) -> Void in
      make.left.equalTo(self.alertStartLabel)
      make.top.equalTo(self.alertStartLabel.snp.bottom).offset(20)
    }
    self.deadlineLabel.isUserInteractionEnabled = true
    let deadlineTapGR = UITapGestureRecognizer(
      target: self,
      action: #selector(EditNotificationsViewController.deadlineLabelTapped)
    )
    self.deadlineLabel.addGestureRecognizer(deadlineTapGR)
    self.updateDeadlineLabel(self.deadline)
    self.timePickerView.isHidden = true
    self.timePickerView.delegate = self
    self.timePickerView.dataSource = self
    self.view.addSubview(self.timePickerView)
    self.timePickerView.snp.makeConstraints { (make) -> Void in
      make.bottom.equalTo(0)
      make.left.equalTo(0)
      make.right.equalTo(0)
    }
  }
  @objc func alertstartLabelTapped() { self.timePickerEditingMode = .alertstart }
  @objc func deadlineLabelTapped() { self.timePickerEditingMode = .deadline }
  func updateAlertstartLabel(_ alertstart: Int) {
    self.alertStartLabel.text = "Start notifications at: \(self.stringFromMidnightOffset(alertstart))"
  }
  func updateDeadlineLabel(_ deadline: Int) {
    self.deadlineLabel.text = "Goal deadline: \(self.stringFromMidnightOffset(deadline))"
  }
  func stringFromMidnightOffset(_ offset: Int) -> NSString {
    let date = Date(timeInterval: Double(offset), since: Calendar.current.startOfDay(for: Date()))
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: self.use24HourTime() ? "en_UK" : "en_US")
    dateFormatter.timeStyle = DateFormatter.Style.short
    dateFormatter.dateStyle = DateFormatter.Style.none
    return dateFormatter.string(from: date) as NSString
  }
  func updateLeadTimeLabel() {
    if self.leadTimeStepper.value == 1 {
      self.leadTimeLabel.text = "Notify 1 day before derail"
    } else {
      self.leadTimeLabel.text = "Notify \(Int(self.leadTimeStepper.value)) days before derail"
    }
  }
  @objc func leadTimeStepperValueChanged() {
    self.updateLeadTimeLabel()
    self.leadTimeDelayTimer?.invalidate()
    self.leadTimeDelayTimer = Timer.scheduledTimer(
      timeInterval: 2,
      target: self,
      selector: #selector(self.sendLeadTimeToServer(_:)),
      userInfo: ["leadtime": NSNumber(value: self.leadTimeStepper.value as Double)],
      repeats: false
    )
  }
  @objc func sendLeadTimeToServer(_ timer: Timer) { assertionFailure("this method must be overridden by a subclass") }
  func use24HourTime() -> Bool {
    let formatString: NSString =
      DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: Locale.current)! as NSString
    return !formatString.contains("a")
  }
  func setTimePickerComponents(_ offsetFromMidnight: Int) {
    var hour = offsetFromMidnight / 3600
    var minute = (offsetFromMidnight % 3600) / 60
    // Normalize the time to ensure positive values
    if hour < 0 || minute < 0 {
      // For times like 23:59 which come in as -1 minutes before midnight
      // we need to convert to the equivalent hour before midnight
      let totalMinutes = hour * 60 + minute
      let normalizedMinutes = (totalMinutes + 24 * 60) % (24 * 60)
      hour = normalizedMinutes / 60
      minute = normalizedMinutes % 60
    }
    if self.use24HourTime() {
      self.timePickerView.selectRow(hour, inComponent: 0, animated: true)
    } else {
      // Convert to 12-hour format
      let isPM = hour >= 12
      let displayHour = hour % 12
      self.timePickerView.selectRow(displayHour == 0 ? 12 : displayHour, inComponent: 0, animated: true)
      self.timePickerView.selectRow(isPM ? 1 : 0, inComponent: 2, animated: true)
    }
    self.timePickerView.selectRow(minute, inComponent: 1, animated: true)
  }
}

extension EditNotificationsViewController: UIPickerViewDataSource, UIPickerViewDelegate {
  func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
    if component == 0 { return self.use24HourTime() ? 24 : 12 } else if component == 1 { return 60 }
    return 2
  }
  func midnightOffsetFromTimePickerView() -> Int {
    let minute = NSNumber(value: self.timePickerView.selectedRow(inComponent: 1))
    let hour = self.hourFromTimePicker()
    return 3600 * hour.intValue + 60 * minute.intValue
  }
  // Convert to deadline format:
  // - Times from midnight to 6am (0-6) stay positive
  // - Times from 7am to midnight (7-23) become negative offsets from next midnight
  var deadlineFromTimePickerView: Int {
    let hour24 = hour24FromPicker
    let selectedMinute = self.timePickerView.selectedRow(inComponent: 1)
    let totalSeconds = 3600 * hour24 + 60 * selectedMinute
    if hour24 <= 6 {
      return totalSeconds  // Keep positive for early morning hours
    } else {
      return totalSeconds - (24 * 3600)  // Convert to negative offset from next midnight
    }
  }
  // we're doing this instead of just using a UIDatePicker so that we can use the
  // Beeminder font in the picker instead of the system font
  func hourFromTimePicker() -> NSNumber {
    let selectedHour = self.timePickerView.selectedRow(inComponent: 0)
    if self.use24HourTime() {
      return NSNumber(value: selectedHour)
    } else {
      // Handle 12-hour time conversion
      let isPM = self.timePickerView.selectedRow(inComponent: 2) == 1
      if selectedHour == 0 {  // 12 AM/PM case
        return NSNumber(value: isPM ? 12 : 0)
      } else {
        return NSNumber(value: isPM ? (selectedHour == 12 ? 12 : selectedHour + 12) : selectedHour)
      }
    }
  }
  var hour24FromPicker: Int {
    let selectedHour = self.timePickerView.selectedRow(inComponent: 0)
    // 24h
    guard !self.use24HourTime() else { return selectedHour }
    // 12h am
    guard self.timePickerView.selectedRow(inComponent: 2) == 1 else { return selectedHour }
    // 12h pm
    return selectedHour == 12 ? 12 : selectedHour + 12
  }
  func numberOfComponents(in pickerView: UIPickerView) -> Int { return self.use24HourTime() ? 2 : 3 }
  func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?)
    -> UIView
  {
    let view = UIView()
    let label = BSLabel()
    view.addSubview(label)
    label.snp.makeConstraints { (make) -> Void in
      make.top.equalTo(0)
      make.bottom.equalTo(0)
      make.left.equalTo(10)
      make.right.equalTo(-20)
    }
    label.font = UIFont.beeminder.defaultFontPlain.withSize(17)
    var text = ""
    var alignment = NSTextAlignment.center
    if component == 2 {
      text = row == 0 ? "AM" : "PM"
      alignment = .left
    } else if component == 1 {
      text = row < 10 ? "0\(row)" : "\(row)"
      if self.use24HourTime() { alignment = .left } else { alignment = .center }
    } else {
      if !self.use24HourTime() && row == 0 { text = "12" } else { text = "\(row)" }
      alignment = .right
    }
    label.text = text
    label.textAlignment = alignment
    return view
  }
}
