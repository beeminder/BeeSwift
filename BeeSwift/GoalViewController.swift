//
//  GoalViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/24/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation
import TPKeyboardAvoiding

class GoalViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UIScrollViewDelegate, UITextFieldDelegate {
    
    var goal :Goal!
    
    private var cellIdentifier = "datapointCell"
    private var goalImageView = UIImageView()
    private var dateTextField = UITextField()
    private var valueTextField = UITextField()
    private var commentTextField = UITextField()
    private var dateStepper = UIStepper()
    private var valueStepper = UIStepper()
    private var valueDecimalRemnant : Double = 0.0
    private var datapoints = NSMutableArray()

    override func viewDidLoad() {
        self.view.backgroundColor = UIColor.whiteColor()
        self.title = self.goal.title
        
        self.datapoints = NSMutableArray(array: self.goal.lastFiveDatapoints())
        
        let scrollView = TPKeyboardAvoidingScrollView()
        self.view.addSubview(scrollView)
        scrollView.snp_makeConstraints { (make) -> Void in
            let topLayoutGuide = self.topLayoutGuide as! UIView
            make.top.equalTo(topLayoutGuide.snp_bottom)
            make.left.equalTo(0)
            make.right.equalTo(0)
            make.bottom.equalTo(0)
        }
        
        let goalImageScrollView = UIScrollView()
        scrollView.addSubview(goalImageScrollView)
        goalImageScrollView.showsHorizontalScrollIndicator = false
        goalImageScrollView.showsVerticalScrollIndicator = false
        goalImageScrollView.minimumZoomScale = 1.0
        goalImageScrollView.maximumZoomScale = 3.0
        goalImageScrollView.delegate = self
        goalImageScrollView.snp_makeConstraints { (make) -> Void in
            make.centerX.equalTo(self.view)
            make.left.greaterThanOrEqualTo(0)
            make.right.lessThanOrEqualTo(0)
            make.top.equalTo(0)
            make.width.equalTo(320)
            make.height.equalTo(goalImageScrollView.snp_width).multipliedBy(Float(Constants.graphHeight)/Float(Constants.graphWidth))
        }
        
        self.goalImageView = UIImageView()
        goalImageScrollView.addSubview(self.goalImageView)
        self.goalImageView.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(0)
            make.bottom.equalTo(0)
            make.width.equalTo(goalImageScrollView)
            make.height.equalTo(goalImageScrollView)
            make.left.equalTo(0)
            make.right.equalTo(0)
        }
        self.goalImageView.setImageWithURL(NSURL(string: goal.cacheBustingGraphUrl))
        
        let datapointsTableView = DatapointsTableView()
        datapointsTableView.dataSource = self
        datapointsTableView.delegate = self
        datapointsTableView.separatorStyle = .None
        datapointsTableView.scrollEnabled = false
        datapointsTableView.registerClass(DatapointTableViewCell.self, forCellReuseIdentifier: self.cellIdentifier)
        scrollView.addSubview(datapointsTableView)
        datapointsTableView.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(goalImageScrollView.snp_bottom).offset(10)
            make.left.equalTo(goalImageScrollView).offset(10)
            make.right.equalTo(goalImageScrollView).offset(-10)
        }
        
        let dataEntryView = UIView()
        if (count(self.goal.autodata) > 0 || self.goal.won.boolValue) {
            dataEntryView.hidden = true
        }

        scrollView.addSubview(dataEntryView)
        dataEntryView.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(datapointsTableView.snp_bottom).offset(10)
            make.left.equalTo(datapointsTableView)
            make.right.equalTo(datapointsTableView)
            make.bottom.equalTo(0)
            make.height.equalTo(150)
        }
        
        dataEntryView.addSubview(self.dateTextField)
        self.dateTextField.font = UIFont(name: "Avenir", size: 16)
        self.dateTextField.tintColor = UIColor.beeGrayColor()
        self.dateTextField.layer.borderColor = UIColor.beeGrayColor().CGColor
        self.dateTextField.layer.borderWidth = 1
        self.dateTextField.userInteractionEnabled = false
        self.dateTextField.textAlignment = .Center
        self.dateTextField.delegate = self
        self.dateTextField.keyboardType = .NumberPad
        self.dateTextField.addTarget(self, action: "dateTextFieldValueChanged", forControlEvents: .EditingChanged)
        self.dateTextField.snp_makeConstraints { (make) -> Void in
            make.left.equalTo(0)
            make.height.equalTo(44)
            make.top.equalTo(0)
        }
        
        dataEntryView.addSubview(self.valueTextField)
        self.valueTextField.font = UIFont(name: "Avenir", size: 16)
        self.valueTextField.tintColor = UIColor.beeGrayColor()
        self.valueTextField.layer.borderColor = UIColor.beeGrayColor().CGColor
        self.valueTextField.layer.borderWidth = 1
        self.valueTextField.delegate = self
        self.valueTextField.textAlignment = .Center
        self.valueTextField.keyboardType = .DecimalPad
        self.valueTextField.addTarget(self, action: "valueTextFieldValueChanged", forControlEvents: .EditingChanged)
        self.valueTextField.snp_makeConstraints { (make) -> Void in
            make.left.equalTo(self.dateTextField.snp_right).offset(10)
            make.height.equalTo(44)
            make.top.equalTo(0)
        }
        
        let commentLeftPaddingView = UIView(frame: CGRectMake(0, 0, 5, 1))
        
        dataEntryView.addSubview(self.commentTextField)
        self.commentTextField.font = UIFont(name: "Avenir", size: 16)
        self.commentTextField.leftView = commentLeftPaddingView
        self.commentTextField.leftViewMode = .Always
        self.commentTextField.tintColor = UIColor.beeGrayColor()
        self.commentTextField.layer.borderColor = UIColor.beeGrayColor().CGColor
        self.commentTextField.layer.borderWidth = 1
        self.commentTextField.delegate = self
        self.commentTextField.placeholder = "Comment"
        self.commentTextField.returnKeyType = .Send
        self.commentTextField.snp_makeConstraints { (make) -> Void in
            make.left.equalTo(self.valueTextField.snp_right).offset(10)
            make.height.equalTo(44)
            make.right.equalTo(0)
            make.top.equalTo(0)
        }
        
        let submitButton = BSButton()
        dataEntryView.addSubview(submitButton)
        submitButton.setTitle("Submit", forState: .Normal)
        submitButton.addTarget(self, action: "submitDatapoint", forControlEvents: .TouchUpInside)
        submitButton.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(self.commentTextField.snp_bottom).offset(10)
            make.left.equalTo(self.commentTextField)
            make.right.equalTo(0)
        }
        
        self.dateStepper.tintColor = UIColor.beeGrayColor()
        self.dateStepper.minimumValue = -365
        self.dateStepper.maximumValue = 365
        dataEntryView.addSubview(self.dateStepper)
        self.dateStepper.addTarget(self, action: "dateStepperValueChanged", forControlEvents: .ValueChanged)
        self.dateStepper.value = 0
        self.dateStepper.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(self.dateTextField.snp_bottom).offset(10)
            make.left.equalTo(self.dateTextField)
            make.width.equalTo(self.dateTextField)
            make.centerX.equalTo(self.dateTextField)
        }
        self.dateStepperValueChanged()
        
        let dateLabel = BSLabel()
        dataEntryView.addSubview(dateLabel)
        dateLabel.text = "Date"
        dateLabel.font = UIFont(name: "Avenir", size: 14)
        dateLabel.textAlignment = .Center
        dateLabel.snp_makeConstraints { (make) -> Void in
            make.left.equalTo(self.dateStepper)
            make.right.equalTo(self.dateStepper)
            make.top.equalTo(self.dateStepper.snp_bottom).offset(10)
        }
        
        self.valueStepper.tintColor = UIColor.beeGrayColor()
        dataEntryView.addSubview(self.valueStepper)
        self.valueStepper.minimumValue = -10000000
        self.valueStepper.maximumValue = 1000000
        if let datapoint = self.goal.orderedDatapoints().last {
            self.valueStepper.value = datapoint.value.doubleValue
        }
        self.valueStepper.addTarget(self, action: "valueStepperValueChanged", forControlEvents: .ValueChanged)
        self.valueStepper.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(self.dateStepper)
            make.left.equalTo(self.dateStepper.snp_right).offset(10)
            make.width.equalTo(self.valueTextField)
            make.centerX.equalTo(self.valueTextField)
        }
        self.valueStepperValueChanged()
        
        let valueLabel = BSLabel()
        dataEntryView.addSubview(valueLabel)
        valueLabel.text = "Value"
        valueLabel.font = UIFont(name: "Avenir", size: 14)
        valueLabel.textAlignment = .Center
        valueLabel.snp_makeConstraints { (make) -> Void in
            make.left.equalTo(self.valueStepper)
            make.right.equalTo(self.valueStepper)
            make.top.equalTo(self.valueStepper.snp_bottom).offset(10)
            make.bottom.equalTo(submitButton)
        }
    }
    
    func dateStepperValueChanged() {
        let calendar = NSCalendar(identifier: NSCalendarIdentifierGregorian)
        var components = NSDateComponents()
        components.day = Int(self.dateStepper.value)
        
        var newDate = calendar?.dateByAddingComponents(components, toDate: NSDate(), options: .allZeros)
        
        var formatter = NSDateFormatter()
        var dateFormat = "d"
        if calendar?.component(.CalendarUnitMonth, fromDate: newDate!) !=
            calendar?.component(.CalendarUnitMonth, fromDate: NSDate()) {
                dateFormat = "M  d"
        }
        formatter.dateFormat = dateFormat
        self.dateTextField.text = formatter.stringFromDate(newDate!)
    }
    
    func valueStepperValueChanged() {
        if self.valueStepper.value < 0 {
            var value = self.valueStepper.value
            if self.valueDecimalRemnant > 0 { value += (1 - self.valueDecimalRemnant) }
            self.valueTextField.text = "\(value)"
        } else {
            self.valueTextField.text = "\(self.valueStepper.value + self.valueDecimalRemnant)"
        }
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        if textField.isEqual(self.commentTextField) {
            self.submitDatapoint()
        }
        return true
    }
    
    func valueTextFieldValueChanged() {
        var intPart : Double = 0;
        var fractPart : Double = modf((self.valueTextField.text as NSString).doubleValue, &intPart);
        
        self.valueStepper.value = intPart
        self.valueDecimalRemnant = abs(fractPart)
        if intPart < 0 && self.valueDecimalRemnant > 0 { self.valueStepper.value = intPart - 1 }
    }
    
    func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
        if (textField.isEqual(self.valueTextField)) {
            if (string as NSString).rangeOfCharacterFromSet(NSCharacterSet(charactersInString: "1234567890.").invertedSet).location != NSNotFound {
                return false
            }
            if textField.text.componentsSeparatedByString(".").count > 1 && string == "." {
                return false
            }
        }
        return true
    }
    
    func urtextFromTextFields() -> String {
        return "\(self.dateTextField.text) \(self.valueTextField.text) \"\(self.commentTextField.text)\""
    }
    
    func submitDatapoint() {
        self.view.endEditing(true)
        var params = ["access_token": CurrentUserManager.sharedManager.accessToken!, "urtext": self.urtextFromTextFields()]
        BSHTTPSessionManager.sharedManager.POST("api/v1/users/\(CurrentUserManager.sharedManager.username!)/goals/\(self.goal.slug)/datapoints.json", parameters: params, success: { (dataTask, responseObject) -> Void in
            self.successfullyAddedDatapointWithResponse(responseObject)
        }) { (dataTask, error) -> Void in
            var response = dataTask.response as! NSHTTPURLResponse
            if response.statusCode == 422 {
                UIAlertView(title: "Error", message: "Invalid datapoint format", delegate: nil, cancelButtonTitle: "OK").show()
            }
        }
    }
    
    func successfullyAddedDatapointWithResponse(responseObject: AnyObject) {
        self.view.endEditing(true)
    }
    
    func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
        return self.goalImageView
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 24
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.datapoints.count
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        self.view.endEditing(true)
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCellWithIdentifier(self.cellIdentifier) as! DatapointTableViewCell
        cell.datapoint = self.datapoints[indexPath.row] as! Datapoint
        return cell
    }
}