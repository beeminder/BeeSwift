//
//  EditGoalNotificationsViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 11/2/15.
//  Copyright © 2015 APB. All rights reserved.
//

import Foundation
import MagicalRecord

class EditNotificationsViewController: UIViewController {
    enum TimePickerEditingMode {
        case alertstart, deadline
    }
    var timePickerEditingMode : TimePickerEditingMode? {
        didSet {
            if self.timePickerEditingMode == nil {
                self.timePickerView.isHidden = true
            } else if self.timePickerEditingMode == .alertstart {
                self.timePickerView.isHidden = false
                self.setTimePickerComponents(self.alertstart.intValue)
                self.alertStartLabel.font = UIFont.beeminderDefaultBoldFont()
                self.deadlineLabel.font = UIFont.beeminderDefaultFont()
            }
            else if self.timePickerEditingMode == .deadline {
                self.timePickerView.isHidden = false
                self.setTimePickerComponents(self.deadline.intValue)
                self.alertStartLabel.font = UIFont.beeminderDefaultFont()
                self.deadlineLabel.font = UIFont.beeminderDefaultBoldFont()
            }
        }
    }
    var timePickerView = UIPickerView()
    var leadTimeLabel = BSLabel()
    var leadTimeStepper = UIStepper()
    var alertStartLabel = BSLabel()
    var deadlineLabel = BSLabel()
    var alertstart = NSNumber() {
        didSet {
            self.updateAlertstartLabel(self.alertstart)
        }
    }
    var deadline = NSNumber() {
        didSet {
            self.updateDeadlineLabel(self.deadline)
        }
    }
    fileprivate var leadTimeDelayTimer : Timer?
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        if #available(iOS 13.0, *) {
            self.view.backgroundColor = UIColor.systemBackground
        } else {
            self.view.backgroundColor = UIColor.white
        }
        
        self.view.addSubview(self.leadTimeLabel)
        self.leadTimeLabel.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(10)
            make.top.equalTo(self.topLayoutGuide.snp.bottom).offset(20)
        }
        
        self.leadTimeStepper.minimumValue = 0
        self.leadTimeStepper.maximumValue = 30
        self.leadTimeStepper.tintColor = UIColor.beeGrayColor()
        self.leadTimeStepper.addTarget(self, action: #selector(EditNotificationsViewController.leadTimeStepperValueChanged), for: .valueChanged)
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
        let tapGR = UITapGestureRecognizer(target: self, action: #selector(EditNotificationsViewController.alertstartLabelTapped))
        self.alertStartLabel.addGestureRecognizer(tapGR)
        self.updateAlertstartLabel(self.alertstart)
        
        self.view.addSubview(self.deadlineLabel)
        self.deadlineLabel.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(self.alertStartLabel)
            make.top.equalTo(self.alertStartLabel.snp.bottom).offset(20)
        }
        self.deadlineLabel.isUserInteractionEnabled = true
        let deadlineTapGR = UITapGestureRecognizer(target: self, action: #selector(EditNotificationsViewController.deadlineLabelTapped))
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
    
    @objc func alertstartLabelTapped() {
        self.timePickerEditingMode = .alertstart
    }
    
    @objc func deadlineLabelTapped() {
        self.timePickerEditingMode = .deadline
    }
    
    func updateAlertstartLabel(_ alertstart : NSNumber) {
        self.alertStartLabel.text = "Start notifications at: \(self.stringFromMidnightOffset(alertstart))"
    }
    
    func updateDeadlineLabel(_ deadline: NSNumber) {
        self.deadlineLabel.text = "Goal deadline: \(self.stringFromMidnightOffset(deadline))"
    }
    
    func stringFromMidnightOffset(_ offset : NSNumber) -> NSString {
        let date = Date(timeInterval: offset.doubleValue, since: Calendar.current.startOfDay(for: Date()))
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
        self.leadTimeDelayTimer = Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(self.sendLeadTimeToServer(_:)), userInfo: [ "leadtime" : NSNumber(value: self.leadTimeStepper.value as Double)], repeats: false)
    }
    
    @objc func sendLeadTimeToServer(_ timer : Timer) {
        assertionFailure("this method must be overridden by a subclass")
    }
    
    func use24HourTime() -> Bool {
        let formatString: NSString = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: Locale.current)! as NSString
        return !formatString.contains("a")
    }
    
    func setTimePickerComponents(_ offsetFromMidnight : Int) {
        var hour = offsetFromMidnight / 3600
        var minute = (offsetFromMidnight % 3600) / 60
        if self.use24HourTime() {
            if hour < 0 { hour = 25 + hour }
            if minute < 0 { minute = 60 + minute }
            self.timePickerView.selectRow(hour, inComponent: 0, animated: true)
            self.timePickerView.selectRow(minute, inComponent: 1, animated: true)
        }
        else {
            if hour > 12 {
                self.timePickerView.selectRow(1, inComponent: 2, animated: true)
                self.timePickerView.selectRow(hour - 12, inComponent: 0, animated: true)
            }
            else {
                self.timePickerView.selectRow(hour, inComponent: 0, animated: true)
            }
            self.timePickerView.selectRow(minute, inComponent: 1, animated: true)
        }
    }
}

extension EditNotificationsViewController : UIPickerViewDataSource, UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if component == 0 {
            return Bool(self.use24HourTime()) ? 24 : 12
        }
        else if component == 1 {
            return 60
        }
        return 2
    }
    
    func midnightOffsetFromTimePickerView() -> NSNumber {
        let minute = NSNumber.init(value: self.timePickerView.selectedRow(inComponent: 1))
        let hour = self.hourFromTimePicker()
        
        return NSNumber(value: 3600*hour.intValue + 60*minute.intValue)
    }
    
    // we're doing this instead of just using a UIDatePicker so that we can use the
    // Beeminder font in the picker instead of the system font
    func hourFromTimePicker() -> NSNumber {
        if self.use24HourTime() || self.timePickerView.selectedRow(inComponent: 2) == 0 {
            return NSNumber(value: self.timePickerView.selectedRow(inComponent: 0))
        }
        return NSNumber(value: self.timePickerView.selectedRow(inComponent: 0) + 12)
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return self.use24HourTime() ? 2 : 3
    }
    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let view = UIView()
        let label = BSLabel()
        view.addSubview(label)
        label.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(0)
            make.bottom.equalTo(0)
            make.left.equalTo(10)
            make.right.equalTo(-20)
        }
        label.font = UIFont(name: "Avenir", size: 17)
        
        var text = ""
        var alignment = NSTextAlignment.center
        
        if (component == 2) {
            text = row == 0 ? "AM" : "PM"
            alignment = .left
        }
        else if (component == 1) {
            text = row < 10 ? "0\(row)" : "\(row)"
            if self.use24HourTime() {
                alignment = .left
            } else {
                alignment = .center
            }
        }
        else {
            if (!self.use24HourTime() && row == 0) {
                text = "12"
            }
            else {
                text = "\(row)"
            }
            alignment = .right
        }
        
        label.text = text
        label.textAlignment = alignment
        
        return view
    }
}
