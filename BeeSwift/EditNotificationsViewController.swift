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
        case Alertstart, Deadline
    }
    var timePickerEditingMode : TimePickerEditingMode? {
        didSet {
            if self.timePickerEditingMode == nil {
                self.timePickerView.hidden = true
            } else if self.timePickerEditingMode == .Alertstart {
                self.timePickerView.hidden = false
                self.setTimePickerComponents(self.alertstart.integerValue)
                self.alertStartLabel.font = UIFont.beeminderDefaultBoldFont()
                self.deadlineLabel.font = UIFont.beeminderDefaultFont()
            }
            else if self.timePickerEditingMode == .Deadline {
                self.timePickerView.hidden = false
                self.setTimePickerComponents(self.deadline.integerValue)
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
    private var leadTimeDelayTimer : NSTimer?
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        self.view.backgroundColor = UIColor.whiteColor()
        
        self.view.addSubview(self.leadTimeLabel)
        self.leadTimeLabel.snp_makeConstraints { (make) -> Void in
            make.left.equalTo(10)
            make.top.equalTo(self.snp_topLayoutGuideBottom).offset(20)
        }
        
        self.leadTimeStepper.minimumValue = 0
        self.leadTimeStepper.maximumValue = 30
        self.leadTimeStepper.tintColor = UIColor.beeGrayColor()
        self.leadTimeStepper.addTarget(self, action: "leadTimeStepperValueChanged", forControlEvents: .ValueChanged)
        self.view.addSubview(self.leadTimeStepper)
        self.leadTimeStepper.snp_makeConstraints { (make) -> Void in
            make.centerY.equalTo(self.leadTimeLabel)
            make.left.equalTo(self.leadTimeLabel.snp_right).offset(10)
        }
        
        self.updateLeadTimeLabel()
        
        self.view.addSubview(self.alertStartLabel)
        self.alertStartLabel.snp_makeConstraints { (make) -> Void in
            make.left.equalTo(self.leadTimeLabel)
            make.top.equalTo(self.leadTimeStepper.snp_bottom).offset(20)
        }
        self.alertStartLabel.userInteractionEnabled = true
        let tapGR = UITapGestureRecognizer(target: self, action: "alertstartLabelTapped")
        self.alertStartLabel.addGestureRecognizer(tapGR)
        self.updateAlertstartLabel(self.alertstart)
        
        self.view.addSubview(self.deadlineLabel)
        self.deadlineLabel.snp_makeConstraints { (make) -> Void in
            make.left.equalTo(self.alertStartLabel)
            make.top.equalTo(self.alertStartLabel.snp_bottom).offset(20)
        }
        self.deadlineLabel.userInteractionEnabled = true
        let deadlineTapGR = UITapGestureRecognizer(target: self, action: "deadlineLabelTapped")
        self.deadlineLabel.addGestureRecognizer(deadlineTapGR)
        self.updateDeadlineLabel(self.deadline)
        
        self.timePickerView.hidden = true
        self.timePickerView.delegate = self
        self.timePickerView.dataSource = self
        self.view.addSubview(self.timePickerView)
        self.timePickerView.snp_makeConstraints { (make) -> Void in
            make.bottom.equalTo(0)
            make.left.equalTo(0)
            make.right.equalTo(0)
        }
    }
    
    func alertstartLabelTapped() {
        self.timePickerEditingMode = .Alertstart
    }
    
    func deadlineLabelTapped() {
        self.timePickerEditingMode = .Deadline
    }
    
    func updateAlertstartLabel(alertstart : NSNumber) {
        self.alertStartLabel.text = "Start notifications at: \(self.stringFromMidnightOffset(alertstart))"
    }
    
    func updateDeadlineLabel(deadline: NSNumber) {
        self.deadlineLabel.text = "Goal deadline: \(self.stringFromMidnightOffset(deadline))"
    }
    
    func stringFromMidnightOffset(offset : NSNumber) -> NSString {
        let date = NSDate(timeInterval: offset.doubleValue, sinceDate: NSCalendar.currentCalendar().startOfDayForDate(NSDate()))
        let dateFormatter = NSDateFormatter()
        dateFormatter.locale = NSLocale(localeIdentifier: self.use24HourTime() ? "en_UK" : "en_US")
        dateFormatter.timeStyle = NSDateFormatterStyle.ShortStyle
        dateFormatter.dateStyle = NSDateFormatterStyle.NoStyle
        return dateFormatter.stringFromDate(date)
    }
    
    func updateLeadTimeLabel() {
        if self.leadTimeStepper.value == 1 {
            self.leadTimeLabel.text = "Notify 1 day before derailing"
        } else {
            self.leadTimeLabel.text = "Notify \(Int(self.leadTimeStepper.value)) days before derailing"
        }
    }
    
    func leadTimeStepperValueChanged() {
        self.updateLeadTimeLabel()
        self.leadTimeDelayTimer?.invalidate()
        self.leadTimeDelayTimer = NSTimer.scheduledTimerWithTimeInterval(2, target: self, selector: "sendLeadTimeToServer:", userInfo: [ "leadtime" : NSNumber(double: self.leadTimeStepper.value)], repeats: false)
    }
    
    func sendLeadTimeToServer(timer : NSTimer) {
        assertionFailure("this method must be overridden by a subclass")
    }
    
    func use24HourTime() -> Bool {
        let formatString: NSString = NSDateFormatter.dateFormatFromTemplate("j", options: 0, locale: NSLocale.currentLocale())!
        return !formatString.containsString("a")
    }
    
    func setTimePickerComponents(offsetFromMidnight : Int) {
        let hour = offsetFromMidnight / 3600
        let minute = (offsetFromMidnight % 3600) / 60
        if self.use24HourTime() {
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
    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if component == 0 {
            return Bool(self.use24HourTime()) ? 24 : 12
        }
        else if component == 1 {
            return 60
        }
        return 2
    }
    
    func midnightOffsetFromTimePickerView() -> NSNumber {
        let minute = self.timePickerView.selectedRowInComponent(1)
        let hour = self.hourFromTimePicker()
        
        return 3600*hour.integerValue + 60*minute
    }
    
    // we're doing this instead of just using a UIDatePicker so that we can use the
    // Beeminder font in the picker instead of the system font
    func hourFromTimePicker() -> NSNumber {
        if self.use24HourTime() || self.timePickerView.selectedRowInComponent(2) == 0 {
            return self.timePickerView.selectedRowInComponent(0)
        }
        return self.timePickerView.selectedRowInComponent(0) + 12
    }
    
    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return self.use24HourTime() ? 2 : 3
    }
    
    func pickerView(pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusingView view: UIView?) -> UIView {
        let view = UIView()
        let label = BSLabel()
        view.addSubview(label)
        label.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(0)
            make.bottom.equalTo(0)
            make.left.equalTo(10)
            make.right.equalTo(-10)
        }
        label.font = UIFont(name: "Avenir", size: 17)
        
        var text = ""
        var alignment = NSTextAlignment.Center
        
        if (component == 2) {
            text = row == 0 ? "AM" : "PM"
            alignment = .Left
        }
        else if (component == 1) {
            text = row < 10 ? "0\(row)" : "\(row)"
            if self.use24HourTime() {
                alignment = .Left
            } else {
                alignment = .Center
            }
        }
        else {
            if (!self.use24HourTime() && row == 0) {
                text = "12"
            }
            else {
                text = "\(row)"
            }
            alignment = .Right
        }
        
        label.text = text
        label.textAlignment = alignment
        
        return view
    }
}