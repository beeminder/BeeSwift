//
//  GoalViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/24/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation
import SwiftyJSON
import MagicalRecord
import MBProgressHUD

class GoalViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UIScrollViewDelegate, UITextFieldDelegate {
    
    var goal :Goal! {
        didSet {
            self.goal.addObserver(self, forKeyPath: "graph_url", options: .allZeros, context: nil)
            self.goal.addObserver(self, forKeyPath: "losedate", options: .allZeros, context: nil)
            self.goal.addObserver(self, forKeyPath: "delta_text", options: .allZeros, context: nil)
            self.goal.addObserver(self, forKeyPath: "safebump", options: .allZeros, context: nil)            
        }
    }
    
    private var cellIdentifier = "datapointCell"
    private var goalImageView = UIImageView()
    private var dateTextField = UITextField()
    private var valueTextField = UITextField()
    private var commentTextField = UITextField()
    private var dateStepper = UIStepper()
    private var valueStepper = UIStepper()
    private var valueDecimalRemnant : Double = 0.0
    private var datapoints = NSMutableArray()
    private var goalImageScrollView = UIScrollView()
    private var datapointsTableView = DatapointsTableView()
    private var pollTimer : NSTimer?
    private var deltasLabel = BSLabel()
    private var countdownLabel = BSLabel()
    private var pledgeLabel = BSLabel()
    private var scrollView = UIScrollView()
    private var submitButton = BSButton()
    private let headerWidth = UIDevice.currentDevice().userInterfaceIdiom == .Pad ? Double(1.0/3.0) : Double(0.5)

    override func viewDidLoad() {
        self.view.backgroundColor = UIColor.whiteColor()
        self.title = self.goal.title
        
        // have to set these before the datapoints since setting the most recent datapoint updates the text field,
        // which in turn updates the stepper
        self.valueStepper.minimumValue = -10000000
        self.valueStepper.maximumValue = 1000000
        self.dateStepper.minimumValue = -365
        self.dateStepper.maximumValue = 365
        
        self.datapoints = NSMutableArray(array: self.goal.lastFiveDatapoints())
        
        self.view.addSubview(self.scrollView)
        self.scrollView.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(self.view.layoutMargins.top)
            make.left.equalTo(0)
            make.right.equalTo(0)
            make.bottom.equalTo(0)
        }
        
        let deltasView = UIView()
        self.scrollView.addSubview(deltasView)
        deltasView.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(0)
            make.left.equalTo(0)
            make.right.equalTo(0)
            make.height.equalTo(35)
            make.width.equalTo(self.scrollView)
        }
        
        deltasView.addSubview(self.pledgeLabel)
        deltasView.addSubview(self.deltasLabel)
        deltasView.addSubview(self.countdownLabel)
        
        self.pledgeLabel.font = UIFont(name:"Avenir-Heavy", size:Constants.defaultFontSize)
        self.pledgeLabel.textAlignment = .Center
        self.pledgeLabel.snp_makeConstraints { (make) -> Void in
            if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
                make.left.equalTo(0)
                make.centerY.equalTo(0)
                make.width.equalTo(deltasView).multipliedBy(self.headerWidth)
            }
        }
        
        self.deltasLabel.font = UIFont(name: "Avenir-Heavy", size: Constants.defaultFontSize)
        self.deltasLabel.textAlignment = .Center
        self.deltasLabel.snp_makeConstraints { (make) -> Void in
            make.left.equalTo(self.countdownLabel.snp_right)
            make.centerY.equalTo(0)
            make.width.equalTo(deltasView).multipliedBy(self.headerWidth)
        }

        self.countdownLabel.font = UIFont(name: "Avenir-Heavy", size: Constants.defaultFontSize)
        self.countdownLabel.textAlignment = .Center
        self.countdownLabel.snp_makeConstraints { (make) -> Void in
            make.left.equalTo(self.pledgeLabel.snp_right)
            make.centerY.equalTo(0)
            make.width.equalTo(deltasView).multipliedBy(self.headerWidth)
        }
        
        NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: "refreshCountdown", userInfo: nil, repeats: true)
        
        self.scrollView.addSubview(self.goalImageScrollView)
        self.goalImageScrollView.showsHorizontalScrollIndicator = false
        self.goalImageScrollView.showsVerticalScrollIndicator = false
        self.goalImageScrollView.minimumZoomScale = 1.0
        self.goalImageScrollView.maximumZoomScale = 3.0
        self.goalImageScrollView.delegate = self
        self.goalImageScrollView.snp_makeConstraints { (make) -> Void in
            make.centerX.equalTo(self.view)
            make.left.greaterThanOrEqualTo(0)
            make.right.lessThanOrEqualTo(0)
            make.top.equalTo(deltasView.snp_bottom)
            make.width.equalTo(self.scrollView)
            make.height.equalTo(self.goalImageScrollView.snp_width).multipliedBy(Float(Constants.graphHeight)/Float(Constants.graphWidth))
        }
        
        self.goalImageScrollView.addSubview(self.goalImageView)
        let tapGR = UITapGestureRecognizer(target: self, action: "goalImageTapped")
        tapGR.numberOfTapsRequired = 2
        self.goalImageScrollView.addGestureRecognizer(tapGR)
        self.goalImageView.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(0)
            make.bottom.equalTo(0)
            make.width.equalTo(self.goalImageScrollView)
            make.height.equalTo(self.goalImageScrollView)
            make.left.equalTo(0)
            make.right.equalTo(0)
        }
        
        self.datapointsTableView.dataSource = self
        self.datapointsTableView.delegate = self
        self.datapointsTableView.separatorStyle = .None
        self.datapointsTableView.scrollEnabled = false
        self.datapointsTableView.registerClass(DatapointTableViewCell.self, forCellReuseIdentifier: self.cellIdentifier)
        self.scrollView.addSubview(self.datapointsTableView)
        self.datapointsTableView.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(self.goalImageScrollView.snp_bottom)
            make.left.equalTo(self.goalImageScrollView).offset(10)
            make.right.equalTo(self.goalImageScrollView).offset(-10)
        }
        
        let dataEntryView = UIView()
        if (count(self.goal.autodata) > 0 || self.goal.won.boolValue) {
            dataEntryView.hidden = true
        }

        self.scrollView.addSubview(dataEntryView)
        dataEntryView.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(self.datapointsTableView.snp_bottom).offset(10)
            make.left.equalTo(self.datapointsTableView)
            make.right.equalTo(self.datapointsTableView)
            make.bottom.equalTo(0)
            make.height.equalTo(120)
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
        if let datapoint = self.goal.orderedDatapoints().last {
            self.valueTextField.text = "\(datapoint.value)"
        }
        self.valueTextFieldValueChanged()
        
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
            make.left.equalTo(self.valueTextField.snp_right).offset(10).priorityHigh()
            make.height.equalTo(44)
            make.right.equalTo(0).priorityHigh()
            make.top.equalTo(0)
        }
        
        dataEntryView.addSubview(self.submitButton)
        self.submitButton.setTitle("Submit", forState: .Normal)
        self.submitButton.addTarget(self, action: "submitDatapoint", forControlEvents: .TouchUpInside)
        self.submitButton.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(self.commentTextField.snp_bottom).offset(10)
            make.left.equalTo(self.commentTextField)
            make.right.equalTo(0)
        }
        
        self.dateStepper.tintColor = UIColor.beeGrayColor()
        dataEntryView.addSubview(self.dateStepper)
        self.dateStepper.addTarget(self, action: "dateStepperValueChanged", forControlEvents: .ValueChanged)
        self.dateStepper.value = 0
        self.dateStepper.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(self.dateTextField.snp_bottom).offset(10)
            make.left.equalTo(self.dateTextField)
            make.width.equalTo(self.dateStepper.frame.size.width)
            make.width.equalTo(self.dateTextField)
            make.centerX.equalTo(self.dateTextField)
        }
        self.dateStepperValueChanged()
        
        let dateLabel = BSLabel()
        dataEntryView.addSubview(dateLabel)
        dateLabel.text = "Date"
        dateLabel.font = UIFont(name: "Avenir", size: Constants.defaultFontSize)
        dateLabel.textAlignment = .Center
        dateLabel.snp_makeConstraints { (make) -> Void in
            make.left.equalTo(self.dateStepper)
            make.right.equalTo(self.dateStepper)
            make.top.equalTo(self.dateStepper.snp_bottom).offset(10)
        }
        
        self.valueStepper.tintColor = UIColor.beeGrayColor()
        dataEntryView.addSubview(self.valueStepper)
        self.valueStepper.addTarget(self, action: "valueStepperValueChanged", forControlEvents: .ValueChanged)
        self.valueStepper.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(self.dateStepper)
            make.left.equalTo(self.dateStepper.snp_right).offset(10)
            make.width.equalTo(self.valueStepper.frame.size.width)
            make.width.equalTo(self.valueTextField)
            make.centerX.equalTo(self.valueTextField)
        }
        
        let valueLabel = BSLabel()
        dataEntryView.addSubview(valueLabel)
        valueLabel.text = "Value"
        valueLabel.font = UIFont(name: "Avenir", size: Constants.defaultFontSize)
        valueLabel.textAlignment = .Center
        valueLabel.snp_makeConstraints { (make) -> Void in
            make.left.equalTo(self.valueStepper)
            make.right.equalTo(self.valueStepper)
            make.top.equalTo(self.valueStepper.snp_bottom).offset(10)
            make.bottom.equalTo(self.submitButton)
        }
    }
    
    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        if (!CurrentUserManager.sharedManager.signedIn()) { return }
        if keyPath == "graph_url" {
            self.setGraphImage()
        } else if keyPath == "delta_text" || keyPath == "safebump" {
            self.deltasLabel.attributedText = self.goal.attributedDeltaText
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        self.setGraphImage()
        self.refreshCountdown()
        self.pledgeLabel.text = "$\(self.goal.pledge)"
        self.deltasLabel.attributedText = self.goal.attributedDeltaText
    }
    
    func refreshCountdown() {
        self.countdownLabel.textColor = self.goal.countdownColor
        self.countdownLabel.text = self.goal.countdownText as String
    }
    
    deinit {
        self.goal.removeObserver(self, forKeyPath: "graph_url")
    }
    
    func setGraphImage() {
        if CurrentUserManager.sharedManager.isDeadbeat() {
            self.goalImageView.image = UIImage(named: "GraphPlaceholder")
        } else {
            self.goalImageView.setImageWithURL(NSURL(string: goal.cacheBustingGraphUrl), placeholderImage: UIImage(named: "GraphPlaceholder"))
        }
    }
    
    func goalImageTapped() {
        self.goalImageScrollView.setZoomScale(self.goalImageScrollView.zoomScale == 1.0 ? 2.0 : 1.0, animated: true)
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
        var valueString = ""
        let formatter = NSNumberFormatter()
        formatter.numberStyle = .DecimalStyle
        
        if self.valueStepper.value < 0 {
            var value = self.valueStepper.value
            if self.valueDecimalRemnant > 0 { value += (1 - self.valueDecimalRemnant) }
            valueString = formatter.stringFromNumber(value)!
        } else {
            valueString = formatter.stringFromNumber(self.valueStepper.value + self.valueDecimalRemnant)!
        }
        valueString = valueString.stringByReplacingOccurrencesOfString(",", withString: ".", options: NSStringCompareOptions.allZeros, range: Range<String.Index>(start: valueString.startIndex, end: valueString.endIndex))
        self.valueTextField.text = valueString
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
            if (string == ",") {
                textField.text = textField.text + "."
                return false
            }
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
        var hud = MBProgressHUD.showHUDAddedTo(self.datapointsTableView, animated: true)
        hud.mode = .Indeterminate
        self.submitButton.userInteractionEnabled = false
        self.scrollView.scrollRectToVisible(CGRectMake(0, 0, 0, 0), animated: true)
        var params = ["access_token": CurrentUserManager.sharedManager.accessToken!, "urtext": self.urtextFromTextFields(), "requestid": NSUUID().UUIDString]
        BSHTTPSessionManager.sharedManager.POST("api/v1/users/\(CurrentUserManager.sharedManager.username!)/goals/\(self.goal.slug)/datapoints.json", parameters: params, success: { (dataTask, responseObject) -> Void in
            self.successfullyAddedDatapointWithResponse(responseObject)
            self.commentTextField.text = ""
            MBProgressHUD.hideAllHUDsForView(self.datapointsTableView, animated: true)
            self.submitButton.userInteractionEnabled = true
        }) { (dataTask, error) -> Void in
            self.submitButton.userInteractionEnabled = true
            MBProgressHUD.hideAllHUDsForView(self.datapointsTableView, animated: true)
            var response = dataTask.response as! NSHTTPURLResponse
            if response.statusCode == 422 {
                UIAlertView(title: "Error", message: "Invalid datapoint format", delegate: nil, cancelButtonTitle: "OK").show()
            }
            else {
                UIAlertView(title: "Error", message: "Failed to add datapoint", delegate: nil, cancelButtonTitle: "OK").show()
            }
        }
    }
    
    func successfullyAddedDatapointWithResponse(responseObject: AnyObject) {
        var datapoint = Datapoint.crupdateWithJSON(JSON(responseObject))
        datapoint.goal = self.goal
        
        NSManagedObjectContext.MR_defaultContext().MR_saveToPersistentStoreWithCompletion { (success: Bool, error: NSError!) -> Void in
            if (self.datapoints.count >= 5) { // magic number
                self.datapoints.removeObjectAtIndex(0)
            }

            self.datapoints.addObject(datapoint)
            self.datapointsTableView.reloadSections(NSIndexSet(indexesInRange: NSMakeRange(0, 1)), withRowAnimation: .Automatic)
            self.pollUntilGraphUpdates()
        }
        self.view.endEditing(true)
    }
    
    func pollUntilGraphUpdates() {
        if self.pollTimer != nil { return }
        var hud = MBProgressHUD.showHUDAddedTo(self.goalImageScrollView, animated: true)
        hud.mode = .Indeterminate
        hud.show(true)
        self.pollTimer = NSTimer.scheduledTimerWithTimeInterval(2, target: self, selector: "refreshGoal", userInfo: nil, repeats: true)
    }
    
    func refreshGoal() {
        BSHTTPSessionManager.sharedManager.GET("/api/v1/users/me/goals/\(self.goal.slug)?access_token=\(CurrentUserManager.sharedManager.accessToken!)", parameters: nil, success: { (dataTask, responseObject) -> Void in
            var goalJSON = JSON(responseObject)
            if (!goalJSON["queued"].bool!) {
                MBProgressHUD.hideAllHUDsForView(self.goalImageScrollView, animated: true)
                Goal.crupdateWithJSON(goalJSON)
                self.pollTimer?.invalidate()
                self.pollTimer = nil
                let delegate = UIApplication.sharedApplication().delegate as! AppDelegate
                delegate.updateBadgeCount()
                delegate.updateTodayText()
            }
        }) { (dataTask, responseError) -> Void in
            //foo
        }
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
        cell.datapoint = (self.datapoints[indexPath.row] as! Datapoint)
        return cell
    }
}