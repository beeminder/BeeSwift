//
//  EditGoalNotificationsViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 11/2/15.
//  Copyright © 2015 APB. All rights reserved.
//

import Foundation

class EditGoalNotificationsViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {
    private var timePickerView = UIPickerView()
    private var leadTimeLabel = BSLabel()
    private var leadTimeStepper = UIStepper()
    private var alertStartLabel = BSLabel()
    private var deadlineLabel = BSLabel()
    private var goal : Goal? {
        didSet {
            
        }
    }
    
    init(goal: Goal) {
        self.goal = goal
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        guard let g = self.goal else { return }
        
        self.view.backgroundColor = UIColor.whiteColor()
        self.title = "Notifications for \(g.slug)"
        
        self.view.addSubview(self.leadTimeLabel)
        self.leadTimeLabel.snp_makeConstraints { (make) -> Void in
            make.left.equalTo(10)
            make.top.equalTo(self.snp_topLayoutGuideBottom).offset(10)
        }
        self.leadTimeLabel.text = "Notify \(g.leadtime) days before derailing"
        
        self.leadTimeStepper.minimumValue = 0
        self.leadTimeStepper.maximumValue = 30
        self.leadTimeStepper.tintColor = UIColor.beeGrayColor()
        self.leadTimeStepper.addTarget(self, action: "leadTimeStepperValueChanged", forControlEvents: .ValueChanged)
        self.view.addSubview(self.leadTimeStepper)
        self.leadTimeStepper.snp_makeConstraints { (make) -> Void in
            make.centerY.equalTo(self.leadTimeLabel)
            make.left.equalTo(self.leadTimeLabel.snp_right).offset(10)
        }
        
        self.view.addSubview(self.alertStartLabel)
        self.alertStartLabel.snp_makeConstraints { (make) -> Void in
            make.left.equalTo(self.leadTimeLabel)
            make.top.equalTo(self.leadTimeStepper.snp_bottom).offset(10)
        }
        self.alertStartLabel.userInteractionEnabled = true
        let tapGR = UITapGestureRecognizer(target: self, action: "alertstartLabelTapped")
        self.alertStartLabel.addGestureRecognizer(tapGR)
        self.updateAlertstartLabel(g.alertstart)

        
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
        
    }
    
    func updateAlertstartLabel(alertstart : NSNumber) {
        let date = NSDate(timeInterval: alertstart.doubleValue, sinceDate: NSCalendar.currentCalendar().startOfDayForDate(NSDate()))
        let dateFormatter = NSDateFormatter()
        dateFormatter.locale = NSLocale(localeIdentifier: self.use24HourTime() ? "en_UK" : "en_US")
        dateFormatter.timeStyle = NSDateFormatterStyle.ShortStyle
        dateFormatter.dateStyle = NSDateFormatterStyle.NoStyle
        self.alertStartLabel.text = "Start notifications at \(dateFormatter.stringFromDate(date))"
    }
    
    func leadTimeStepperValueChanged() {
        if self.leadTimeStepper.value == 1 {
            self.leadTimeLabel.text = "Notify 1 day before derailing"
        } else {
            self.leadTimeLabel.text = "Notify \(Int(self.leadTimeStepper.value)) days before derailing"
        }

    }
    
    // we're doing this instead of just using a UIDatePicker so that we can use the 
    // Beeminder font in the picker instead of the system font
    func reminderHourFromTimePicker() -> NSNumber {
        if self.use24HourTime() || self.timePickerView.selectedRowInComponent(2) == 0 {
            return self.timePickerView.selectedRowInComponent(0)
        }
        return self.timePickerView.selectedRowInComponent(0) + 12
    }
    
    func reminderMinuteFromTimePicker() -> NSNumber {
        return self.timePickerView.selectedRowInComponent(1)
    }
    
    func use24HourTime() -> Bool {
        let formatString: NSString = NSDateFormatter.dateFormatFromTemplate("j", options: 0, locale: NSLocale.currentLocale())!
        return !formatString.containsString("a")
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
    
    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if component == 0 {
            return Bool(self.use24HourTime()) ? 24 : 12
        }
        else if component == 1 {
            return 60
        }
        return 2
    }
}