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
            self.goal.addObserver(self, forKeyPath: "graph_url", options: [], context: nil)
            self.goal.addObserver(self, forKeyPath: "losedate", options: [], context: nil)
            self.goal.addObserver(self, forKeyPath: "delta_text", options: [], context: nil)
            self.goal.addObserver(self, forKeyPath: "safebump", options: [], context: nil)            
        }
    }
    
    fileprivate var cellIdentifier = "datapointCell"
    fileprivate var goalImageView = UIImageView()
    fileprivate var dateTextField = UITextField()
    fileprivate var valueTextField = UITextField()
    fileprivate var commentTextField = UITextField()
    fileprivate var dateStepper = UIStepper()
    fileprivate var valueStepper = UIStepper()
    fileprivate var valueDecimalRemnant : Double = 0.0
    fileprivate var datapoints = NSMutableArray()
    fileprivate var goalImageScrollView = UIScrollView()
    fileprivate var datapointsTableView = DatapointsTableView()
    fileprivate var pollTimer : Timer?
    fileprivate var deltasLabel = BSLabel()
    fileprivate var countdownLabel = BSLabel()
    fileprivate var pledgeLabel = BSLabel()
    fileprivate var scrollView = UIScrollView()
    fileprivate var submitButton = BSButton()
    fileprivate let headerWidth = UIDevice.current.userInterfaceIdiom == .pad ? Double(1.0/3.0) : Double(0.5)

    override func viewDidLoad() {
        self.view.backgroundColor = UIColor.white
        self.title = self.goal.slug
        
        // have to set these before the datapoints since setting the most recent datapoint updates the text field,
        // which in turn updates the stepper
        self.valueStepper.minimumValue = -10000000
        self.valueStepper.maximumValue = 1000000
        self.dateStepper.minimumValue = -365
        self.dateStepper.maximumValue = 365
        
        self.datapoints = NSMutableArray(array: self.goal.lastFiveDatapoints())
        
        self.view.addSubview(self.scrollView)
        self.scrollView.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(self.view.layoutMargins.top)
            make.left.equalTo(0)
            make.right.equalTo(0)
            make.bottom.equalTo(0)
        }
        
        let deltasView = UIView()
        self.scrollView.addSubview(deltasView)
        deltasView.snp.makeConstraints { (make) -> Void in
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
        self.pledgeLabel.textAlignment = .center
        self.pledgeLabel.snp.makeConstraints { (make) -> Void in
            if UIDevice.current.userInterfaceIdiom == .pad {
                make.left.equalTo(0)
                make.centerY.equalTo(0)
                make.width.equalTo(deltasView).multipliedBy(self.headerWidth)
            }
        }
        
        self.deltasLabel.font = UIFont(name: "Avenir-Heavy", size: Constants.defaultFontSize)
        self.deltasLabel.textAlignment = .center
        self.deltasLabel.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(self.countdownLabel.snp.right)
            make.centerY.equalTo(0)
            make.width.equalTo(deltasView).multipliedBy(self.headerWidth)
        }

        self.countdownLabel.font = UIFont(name: "Avenir-Heavy", size: Constants.defaultFontSize)
        self.countdownLabel.textAlignment = .center
        self.countdownLabel.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(self.pledgeLabel.snp.right)
            make.centerY.equalTo(0)
            make.width.equalTo(deltasView).multipliedBy(self.headerWidth)
        }
        
        Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(GoalViewController.refreshCountdown), userInfo: nil, repeats: true)
        
        self.scrollView.addSubview(self.goalImageScrollView)
        self.goalImageScrollView.showsHorizontalScrollIndicator = false
        self.goalImageScrollView.showsVerticalScrollIndicator = false
        self.goalImageScrollView.minimumZoomScale = 1.0
        self.goalImageScrollView.maximumZoomScale = 3.0
        self.goalImageScrollView.delegate = self
        self.goalImageScrollView.snp.makeConstraints { (make) -> Void in
            make.centerX.equalTo(self.view)
            make.left.greaterThanOrEqualTo(0)
            make.right.lessThanOrEqualTo(0)
            make.top.equalTo(deltasView.snp.bottom)
            make.width.equalTo(self.scrollView)
            make.height.equalTo(self.goalImageScrollView.snp.width).multipliedBy(Float(Constants.graphHeight)/Float(Constants.graphWidth))
        }
        
        self.goalImageScrollView.addSubview(self.goalImageView)
        let tapGR = UITapGestureRecognizer(target: self, action: #selector(GoalViewController.goalImageTapped))
        tapGR.numberOfTapsRequired = 2
        self.goalImageScrollView.addGestureRecognizer(tapGR)
        self.goalImageView.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(0)
            make.bottom.equalTo(0)
            make.width.equalTo(self.goalImageScrollView)
            make.height.equalTo(self.goalImageScrollView)
            make.left.equalTo(0)
            make.right.equalTo(0)
        }
        
        self.datapointsTableView.dataSource = self
        self.datapointsTableView.delegate = self
        self.datapointsTableView.separatorStyle = .none
        self.datapointsTableView.isScrollEnabled = false
        self.datapointsTableView.register(DatapointTableViewCell.self, forCellReuseIdentifier: self.cellIdentifier)
        self.scrollView.addSubview(self.datapointsTableView)
        self.datapointsTableView.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(self.goalImageScrollView.snp.bottom)
            make.left.equalTo(self.goalImageScrollView).offset(10)
            make.right.equalTo(self.goalImageScrollView).offset(-10)
        }
        
        let dataEntryView = UIView()
        if (self.goal.hideDataEntry()) {
            dataEntryView.isHidden = true
        }

        self.scrollView.addSubview(dataEntryView)
        dataEntryView.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(self.datapointsTableView.snp.bottom).offset(10)
            make.left.equalTo(self.datapointsTableView)
            make.right.equalTo(self.datapointsTableView)
            make.bottom.equalTo(0)
            make.height.equalTo(120)
        }
        
        dataEntryView.addSubview(self.dateTextField)
        self.dateTextField.font = UIFont(name: "Avenir", size: 16)
        self.dateTextField.tintColor = UIColor.beeGrayColor()
        self.dateTextField.layer.borderColor = UIColor.beeGrayColor().cgColor
        self.dateTextField.layer.borderWidth = 1
        self.dateTextField.isUserInteractionEnabled = false
        self.dateTextField.textAlignment = .center
        self.dateTextField.delegate = self
        self.dateTextField.keyboardType = .numberPad
        self.dateTextField.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(0)
            make.height.equalTo(Constants.defaultTextFieldHeight)
            make.top.equalTo(0)
        }
        
        dataEntryView.addSubview(self.valueTextField)
        self.valueTextField.font = UIFont(name: "Avenir", size: 16)
        self.valueTextField.tintColor = UIColor.beeGrayColor()
        self.valueTextField.layer.borderColor = UIColor.beeGrayColor().cgColor
        self.valueTextField.layer.borderWidth = 1
        self.valueTextField.delegate = self
        self.valueTextField.textAlignment = .center
        self.valueTextField.keyboardType = .decimalPad
        
        let accessory = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 44))
        accessory.backgroundColor = UIColor.white
        self.valueTextField.inputAccessoryView = accessory
        let colonButton = UIButton()
        accessory.addSubview(colonButton)
        accessory.clipsToBounds = true
        colonButton.snp.makeConstraints { (make) -> Void in
            make.width.equalTo(accessory).multipliedBy(1.0/3.0).offset(-1)
            make.height.equalTo(accessory)
            make.left.equalTo(-1)
            make.top.equalTo(0)
        }
        colonButton.setTitle(":", for: UIControlState())
        colonButton.layer.borderWidth = 1
        colonButton.layer.borderColor = UIColor.beeGrayColor().cgColor
        colonButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 26)
        colonButton.setTitleColor(UIColor.black, for: UIControlState())
        colonButton.addTarget(self, action: #selector(GoalViewController.colonButtonPressed), for: .touchUpInside)
        self.valueTextField.addTarget(self, action: #selector(GoalViewController.valueTextFieldValueChanged), for: .editingChanged)
        self.valueTextField.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(self.dateTextField.snp.right).offset(10)
            make.height.equalTo(Constants.defaultTextFieldHeight)
            make.top.equalTo(0)
        }
        if let datapoint = self.goal.orderedDatapoints().last {
            self.valueTextField.text = "\(datapoint.value)"
        }
        self.valueTextFieldValueChanged()
        
        let commentLeftPaddingView = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 1))
        
        dataEntryView.addSubview(self.commentTextField)
        self.commentTextField.font = UIFont(name: "Avenir", size: 16)
        self.commentTextField.leftView = commentLeftPaddingView
        self.commentTextField.leftViewMode = .always
        self.commentTextField.tintColor = UIColor.beeGrayColor()
        self.commentTextField.layer.borderColor = UIColor.beeGrayColor().cgColor
        self.commentTextField.layer.borderWidth = 1
        self.commentTextField.delegate = self
        self.commentTextField.placeholder = "Comment"
        self.commentTextField.returnKeyType = .send
        self.commentTextField.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(self.valueTextField.snp.right).offset(10).priorityHigh()
            make.height.equalTo(Constants.defaultTextFieldHeight)
            make.right.equalTo(0).priorityHigh()
            make.top.equalTo(0)
        }
        
        dataEntryView.addSubview(self.submitButton)
        self.submitButton.setTitle("Submit", for: UIControlState())
        self.submitButton.addTarget(self, action: #selector(GoalViewController.submitDatapoint), for: .touchUpInside)
        self.submitButton.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(self.commentTextField.snp.bottom).offset(10)
            make.left.equalTo(self.commentTextField)
            make.right.equalTo(0)
        }
        
        self.dateStepper.tintColor = UIColor.beeGrayColor()
        dataEntryView.addSubview(self.dateStepper)
        self.dateStepper.addTarget(self, action: #selector(GoalViewController.dateStepperValueChanged), for: .valueChanged)
        self.dateStepper.value = 0
        
        // if the goal's deadline is after midnight, and it's after midnight, 
        // default to entering data for the "previous" day.
        let now = Date()
        let calendar = Calendar.current
        let components = (calendar as NSCalendar).components(NSCalendar.Unit.hour, from: now)
        let hour = components.hour
        if self.goal.deadline.intValue > 0 && hour! < 6 {
            self.dateStepper.value = -1
        }
        
        self.dateStepper.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(self.dateTextField.snp.bottom).offset(10)
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
        dateLabel.textAlignment = .center
        dateLabel.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(self.dateStepper)
            make.right.equalTo(self.dateStepper)
            make.top.equalTo(self.dateStepper.snp.bottom).offset(10)
        }
        
        self.valueStepper.tintColor = UIColor.beeGrayColor()
        dataEntryView.addSubview(self.valueStepper)
        self.valueStepper.addTarget(self, action: #selector(GoalViewController.valueStepperValueChanged), for: .valueChanged)
        self.valueStepper.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(self.dateStepper)
            make.left.equalTo(self.dateStepper.snp.right).offset(10)
            make.width.equalTo(self.valueStepper.frame.size.width)
            make.width.equalTo(self.valueTextField)
            make.centerX.equalTo(self.valueTextField)
        }
        
        let valueLabel = BSLabel()
        dataEntryView.addSubview(valueLabel)
        valueLabel.text = "Value"
        valueLabel.font = UIFont(name: "Avenir", size: Constants.defaultFontSize)
        valueLabel.textAlignment = .center
        valueLabel.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(self.valueStepper)
            make.right.equalTo(self.valueStepper)
            make.top.equalTo(self.valueStepper.snp.bottom).offset(10)
            make.bottom.equalTo(self.submitButton)
        }
        self.navigationItem.rightBarButtonItems = [UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(GoalViewController.refreshButtonPressed)), UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(GoalViewController.safariButtonPressed))]
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if (!CurrentUserManager.sharedManager.signedIn()) { return }
        if keyPath == "graph_url" {
            self.setGraphImage()
        } else if keyPath == "delta_text" || keyPath == "safebump" {
            self.deltasLabel.attributedText = self.goal.attributedDeltaText
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.setGraphImage()
        self.refreshCountdown()
        self.pledgeLabel.text = "$\(self.goal.pledge)"
        self.deltasLabel.attributedText = self.goal.attributedDeltaText
    }
    
    func safariButtonPressed() {
        let url = "\(BSHTTPSessionManager.sharedManager.baseURLString)/api/v1/users/me.json?access_token=\(CurrentUserManager.sharedManager.accessToken!)&redirect_to_url=\(BSHTTPSessionManager.sharedManager.baseURLString)/\(CurrentUserManager.sharedManager.username!)/\(self.goal!.slug)"
        UIApplication.shared.openURL(URL(string: url)!)
    }
    
    func refreshButtonPressed() {
        BSHTTPSessionManager.sharedManager.get("api/v1/users/me/goals/\(self.goal.slug)/refresh_graph.json", parameters: nil, progress: nil, success: { (dataTask, responseObject) in
            self.pollUntilGraphUpdates()
        }) { (dataTask, error) in
            let alert = UIAlertController(title: "Error", message: "Could not refresh graph", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func colonButtonPressed() {
        self.valueTextField.text = "\(self.valueTextField.text!):"
    }
    
    func refreshCountdown() {
        self.countdownLabel.textColor = self.goal.countdownColor
        self.countdownLabel.text = self.goal.countdownText as String
    }
    
    deinit {
        self.goal.removeObserver(self, forKeyPath: "graph_url")
        self.goal.removeObserver(self, forKeyPath: "losedate")
        self.goal.removeObserver(self, forKeyPath: "delta_text")
        self.goal.removeObserver(self, forKeyPath: "safebump")
    }
    
    func setGraphImage() {
        if CurrentUserManager.sharedManager.isDeadbeat() {
            self.goalImageView.image = UIImage(named: "GraphPlaceholder")
        } else {
            self.goalImageView.setImageWith(URL(string: goal.cacheBustingGraphUrl)!, placeholderImage: UIImage(named: "GraphPlaceholder"))
        }
    }
    
    func goalImageTapped() {
        self.goalImageScrollView.setZoomScale(self.goalImageScrollView.zoomScale == 1.0 ? 2.0 : 1.0, animated: true)
    }
    
    func dateStepperValueChanged() {
        let calendar = Calendar(identifier: Calendar.Identifier.gregorian)
        var components = DateComponents()
        components.day = Int(self.dateStepper.value)
        
        let newDate = (calendar as NSCalendar?)?.date(byAdding: components, to: Date(), options: [])
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "d"
        self.dateTextField.text = formatter.string(from: newDate!)
    }
    
    func valueStepperValueChanged() {
        var valueString = ""
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .decimal
        
        if self.valueStepper.value < 0 {
            var value = self.valueStepper.value
            if self.valueDecimalRemnant > 0 { value += (1 - self.valueDecimalRemnant) }
            valueString = formatter.string(from: NSNumber(value: value))!
        } else {
            valueString = formatter.string(from: NSNumber(value: self.valueStepper.value + self.valueDecimalRemnant))!
        }
        valueString = valueString.replacingOccurrences(of: ",", with: ".", options: NSString.CompareOptions(), range: nil)
        self.valueTextField.text = valueString
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField.isEqual(self.commentTextField) {
            self.submitDatapoint()
        }
        return true
    }
    
    func valueTextFieldValueChanged() {
        var intPart : Double = 0;
        let fractPart : Double = modf((self.valueTextField.text! as NSString).doubleValue, &intPart);
        
        self.valueStepper.value = intPart
        self.valueDecimalRemnant = abs(fractPart)
        if intPart < 0 && self.valueDecimalRemnant > 0 { self.valueStepper.value = intPart - 1 }
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if (textField.isEqual(self.valueTextField)) {
            if (string == ",") {
                textField.text = textField.text! + "."
                return false
            }
            if (string as NSString).rangeOfCharacter(from: CharacterSet(charactersIn: "1234567890.").inverted).location != NSNotFound {
                return false
            }
            if textField.text!.components(separatedBy: ".").count > 1 && string == "." {
                return false
            }
        }
        return true
    }
    
    func urtextFromTextFields() -> String {
        return "\(self.dateTextField.text!) \(self.valueTextField.text!) \"\(self.commentTextField.text!)\""
    }
    
    func submitDatapoint() {
        self.view.endEditing(true)
        let hud = MBProgressHUD.showAdded(to: self.datapointsTableView, animated: true)
        hud?.mode = .indeterminate
        self.submitButton.isUserInteractionEnabled = false
        self.scrollView.scrollRectToVisible(CGRect(x: 0, y: 0, width: 0, height: 0), animated: true)
        let params = ["access_token": CurrentUserManager.sharedManager.accessToken!, "urtext": self.urtextFromTextFields(), "requestid": UUID().uuidString]
        
        BSHTTPSessionManager.sharedManager.post("api/v1/users/me/goals/\(self.goal.slug)/datapoints.json", parameters: params, progress: nil, success: { (dataTask, responseObject) in
            self.successfullyAddedDatapointWithResponse(responseObject! as AnyObject)
            self.commentTextField.text = ""
            MBProgressHUD.hideAllHUDs(for: self.datapointsTableView, animated: true)
            self.submitButton.isUserInteractionEnabled = true
        }) { (dataTask, error) in
            self.submitButton.isUserInteractionEnabled = true
            MBProgressHUD.hideAllHUDs(for: self.datapointsTableView, animated: true)
            UIAlertView(title: "Error", message: "Failed to add datapoint", delegate: nil, cancelButtonTitle: "OK").show()
        }
    }
    
    func successfullyAddedDatapointWithResponse(_ responseObject: AnyObject) {
        let datapoint = Datapoint.crupdateWithJSON(JSON(responseObject))
        datapoint.goal = self.goal
        
        NSManagedObjectContext.mr_default().mr_saveToPersistentStore { (success, error) -> Void in
            if (self.datapoints.count >= 5) { // magic number
                self.datapoints.removeObject(at: 0)
            }

            self.datapoints.add(datapoint)
            self.datapointsTableView.reloadSections(IndexSet(integersIn: NSMakeRange(0, 1).toRange()!), with: .automatic)
            self.pollUntilGraphUpdates()
        }
        self.view.endEditing(true)
    }
    
    func pollUntilGraphUpdates() {
        if self.pollTimer != nil { return }
        let hud = MBProgressHUD.showAdded(to: self.goalImageScrollView, animated: true)
        hud?.mode = .indeterminate
        hud?.show(true)
        self.pollTimer = Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(self.refreshGoal), userInfo: nil, repeats: true)
    }
    
    func refreshGoal() {
        BSHTTPSessionManager.sharedManager.get("/api/v1/users/me/goals/\(self.goal.slug)?access_token=\(CurrentUserManager.sharedManager.accessToken!)", parameters: nil, progress: nil, success: { (dataTask, responseObject) in
            var goalJSON = JSON(responseObject!)
            if (!goalJSON["queued"].bool!) {
                MBProgressHUD.hideAllHUDs(for: self.goalImageScrollView, animated: true)
                Goal.crupdateWithJSON(goalJSON)
                self.pollTimer?.invalidate()
                self.pollTimer = nil
                let delegate = UIApplication.shared.delegate as! AppDelegate
                delegate.updateBadgeCount()
                delegate.updateTodayWidget()
            }
        }) { (dataTask, error) in
            // foo
        }
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.goalImageView
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 24
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.datapoints.count
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.view.endEditing(true)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: self.cellIdentifier) as! DatapointTableViewCell
        cell.datapoint = (self.datapoints[(indexPath as NSIndexPath).row] as! Datapoint)
        return cell
    }
}
