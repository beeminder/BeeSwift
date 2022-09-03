//
//  GoalViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/24/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation
import SwiftyJSON
import MBProgressHUD
import AlamofireImage
import SafariServices
import Intents
import BeeKit

class GoalViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UIScrollViewDelegate, UITextFieldDelegate, SFSafariViewControllerDelegate {
    
    var goal : JSONGoal!
    
    fileprivate var cellIdentifier = "datapointCell"
    fileprivate var goalImageView = UIImageView()
    fileprivate var dateTextField = UITextField()
    fileprivate var valueTextField = UITextField()
    fileprivate var commentTextField = UITextField()
    fileprivate var dateStepper = UIStepper()
    fileprivate var valueStepper = UIStepper()
    fileprivate var valueDecimalRemnant : Double = 0.0
    fileprivate var goalImageScrollView = UIScrollView()
    fileprivate var datapointsTableView = DatapointsTableView()
    fileprivate var pollTimer : Timer?
    fileprivate var countdownLabel = BSLabel()
    fileprivate var deltasLabel = BSLabel()
    fileprivate var scrollView = UIScrollView()
    fileprivate var submitButton = BSButton()
    fileprivate let headerWidth = Double(1.0/3.0)
    fileprivate let viewGoalActivityType = "com.beeminder.viewGoal"

    override func viewDidLoad() {
        if #available(iOS 13.0, *) {
            self.view.backgroundColor = UIColor.systemBackground
        } else {
            self.view.backgroundColor = UIColor.white
        }
        self.title = self.goal.slug
        
        // have to set these before the datapoints since setting the most recent datapoint updates the text field,
        // which in turn updates the stepper
        self.valueStepper.minimumValue = -10000000
        self.valueStepper.maximumValue = 1000000
        self.dateStepper.minimumValue = -365
        self.dateStepper.maximumValue = 365
        
        self.view.addSubview(self.scrollView)
        self.scrollView.snp.makeConstraints { (make) -> Void in
            make.top.equalToSuperview()
            make.left.equalTo(0)
            make.right.equalTo(0)
            make.bottom.equalTo(0)
        }
        
        
        self.scrollView.refreshControl = {
            let refreshControl = UIRefreshControl()
            refreshControl.addTarget(self, action: #selector(refreshButtonPressed), for: .valueChanged)
            return refreshControl
        }()
        
        let countdownView = UIView()
        self.scrollView.addSubview(countdownView)
        countdownView.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(0)
            make.left.equalTo(0)
            make.right.equalTo(0)
            make.height.equalTo(35)
            make.width.equalTo(self.scrollView)
        }
        
        countdownView.addSubview(self.countdownLabel)

        self.countdownLabel.font = UIFont.beeminder.defaultFontHeavy.withSize(Constants.defaultFontSize)
        self.countdownLabel.textAlignment = .center
        self.countdownLabel.snp.makeConstraints { (make) -> Void in
            make.centerY.centerX.equalTo(countdownView)
            make.width.equalTo(countdownView)
        }
        self.refreshCountdown()
        
        self.scrollView.addSubview(self.goalImageScrollView)
        self.goalImageScrollView.showsHorizontalScrollIndicator = false
        self.goalImageScrollView.showsVerticalScrollIndicator = false
        self.goalImageScrollView.minimumZoomScale = 1.0
        self.goalImageScrollView.maximumZoomScale = 3.0
        self.goalImageScrollView.delegate = self
        self.goalImageScrollView.snp.makeConstraints { (make) -> Void in
            make.centerX.equalTo(self.view)
            if #available(iOS 11.0, *) {
                make.left.greaterThanOrEqualTo(self.scrollView.safeAreaLayoutGuide.snp.leftMargin)
                make.right.lessThanOrEqualTo(self.scrollView.safeAreaLayoutGuide.snp.rightMargin)
            } else {
                make.left.greaterThanOrEqualTo(0)
                make.right.lessThanOrEqualTo(0)
            }
            
            make.top.equalTo(countdownView.snp.bottom)
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
            make.left.equalTo(self.goalImageScrollView)
            make.right.equalTo(self.goalImageScrollView)
        }
        self.goalImageView.image = UIImage(named: "GraphPlaceholder")

        
        self.scrollView.addSubview(self.deltasLabel)
        self.deltasLabel.snp.makeConstraints { (make) in
            make.top.equalTo(self.goalImageScrollView.snp.bottom)
            make.left.right.equalTo(0)
        }
        self.deltasLabel.attributedText = self.goal!.attributedDeltaText
        self.deltasLabel.font = UIFont.beeminder.defaultBoldFont.withSize(Constants.defaultFontSize)
        self.deltasLabel.textAlignment = .center
        
        
        self.datapointsTableView.dataSource = self
        self.datapointsTableView.delegate = self
        self.datapointsTableView.separatorStyle = .none
        self.datapointsTableView.isScrollEnabled = false
        self.datapointsTableView.register(DatapointTableViewCell.self, forCellReuseIdentifier: self.cellIdentifier)
        self.scrollView.addSubview(self.datapointsTableView)
        self.datapointsTableView.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(self.deltasLabel.snp.bottom)
            make.left.equalTo(self.goalImageScrollView).offset(10)
            make.right.equalTo(self.goalImageScrollView).offset(-10)
        }
        
        let dataEntryView = UIView()
        dataEntryView.isHidden = self.goal.hideDataEntry()

        self.scrollView.addSubview(dataEntryView)
        dataEntryView.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(self.datapointsTableView.snp.bottom).offset(10)
            if #available(iOS 11.0, *) {
                make.left.equalTo(self.view.safeAreaLayoutGuide.snp.leftMargin).offset(10)
            } else {
                make.left.equalTo(10)
            }
            make.right.equalTo(self.datapointsTableView)
            make.bottom.equalTo(0)
            make.height.equalTo(120)
        }
        
        dataEntryView.addSubview(self.dateTextField)
        self.dateTextField.font = UIFont.beeminder.defaultFontPlain.withSize(16)
        self.dateTextField.tintColor = UIColor.beeminder.gray
        self.dateTextField.layer.borderColor = UIColor.beeminder.gray.cgColor
        self.dateTextField.layer.borderWidth = 1
        self.dateTextField.isUserInteractionEnabled = false
        self.dateTextField.textAlignment = .center
        self.dateTextField.delegate = self
        self.dateTextField.keyboardType = .numberPad
        self.dateTextField.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(dataEntryView)
            make.height.equalTo(Constants.defaultTextFieldHeight)
            make.top.equalTo(0)
        }
        
        dataEntryView.addSubview(self.valueTextField)
        self.valueTextField.font = UIFont.beeminder.defaultFontPlain.withSize(16)
        self.valueTextField.tintColor = UIColor.beeminder.gray
        self.valueTextField.layer.borderColor = UIColor.beeminder.gray.cgColor
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
        colonButton.setTitle(":", for: UIControl.State())
        colonButton.layer.borderWidth = 1
        colonButton.layer.borderColor = UIColor.beeminder.gray.cgColor
        colonButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 26)
        colonButton.setTitleColor(UIColor.black, for: UIControl.State())
        colonButton.addTarget(self, action: #selector(self.colonButtonPressed), for: .touchUpInside)
        self.valueTextField.addTarget(self, action: #selector(GoalViewController.valueTextFieldValueChanged), for: .editingChanged)
        self.valueTextField.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(self.dateTextField.snp.right).offset(10)
            make.height.equalTo(Constants.defaultTextFieldHeight)
            make.top.equalTo(0)
        }
        
        self.setValueTextField()
        self.valueTextFieldValueChanged()
        
        let commentLeftPaddingView = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 1))
        
        dataEntryView.addSubview(self.commentTextField)
        self.commentTextField.font = UIFont.beeminder.defaultFontPlain.withSize(16)
        self.commentTextField.leftView = commentLeftPaddingView
        self.commentTextField.leftViewMode = .always
        self.commentTextField.tintColor = UIColor.beeminder.gray
        self.commentTextField.layer.borderColor = UIColor.beeminder.gray.cgColor
        self.commentTextField.layer.borderWidth = 1
        self.commentTextField.delegate = self
        self.commentTextField.placeholder = "Comment"
        self.commentTextField.returnKeyType = .send
        self.commentTextField.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(self.valueTextField.snp.right).offset(10).priority(.high)
            make.height.equalTo(Constants.defaultTextFieldHeight)
            if #available(iOS 11.0, *) {
                make.right.equalTo(self.view.safeAreaLayoutGuide.snp.rightMargin).offset(-10).priority(.high)
            } else {
                make.right.equalTo(-10)
            }
            make.top.equalTo(0)
        }
        
        dataEntryView.addSubview(self.submitButton)
        self.submitButton.setTitle("Submit", for: UIControl.State())
        self.submitButton.addTarget(self, action: #selector(GoalViewController.submitDatapoint), for: .touchUpInside)
        self.submitButton.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(self.commentTextField.snp.bottom).offset(10)
            make.left.equalTo(self.commentTextField)
            make.right.equalTo(self.commentTextField)
        }
        
        self.dateStepper.tintColor = UIColor.beeminder.gray
        dataEntryView.addSubview(self.dateStepper)
        self.dateStepper.addTarget(self, action: #selector(GoalViewController.dateStepperValueChanged), for: .valueChanged)
        self.dateStepper.value = 0
        
        // if the goal's deadline is after midnight, and it's after midnight,
        // but before the deadline,
        // default to entering data for the "previous" day.
        let now = Date()
        let calendar = Calendar.current
        let components = (calendar as NSCalendar).components([.hour, .minute], from: now)
        let currentHour = components.hour
        if self.goal.deadline.intValue > 0 && currentHour! < 6 && currentHour! < self.goal.deadline.intValue/3600 {
            self.dateStepper.value = -1
        }
        
        // if the goal's deadline is before midnight and has already passed for this calendar day, default to entering data for the "next" day
        if self.goal.deadline.intValue < 0 {
            let deadlineSecondsAfterMidnight = 24*3600 + self.goal.deadline.intValue
            let deadlineHour = deadlineSecondsAfterMidnight/3600
            let deadlineMinute = (deadlineSecondsAfterMidnight % 3600)/60
            let currentMinute = components.minute
            if deadlineHour < currentHour! ||
                (deadlineHour == currentHour! && deadlineMinute < currentMinute!) {
                self.dateStepper.value = 1
            }
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
        dateLabel.font = UIFont.beeminder.defaultFontPlain.withSize(Constants.defaultFontSize)
        dateLabel.textAlignment = .center
        dateLabel.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(self.dateStepper)
            make.right.equalTo(self.dateStepper)
            make.top.equalTo(self.dateStepper.snp.bottom).offset(10)
        }
        
        self.valueStepper.tintColor = UIColor.beeminder.gray
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
        valueLabel.font = UIFont.beeminder.defaultFontPlain.withSize(Constants.defaultFontSize)
        valueLabel.textAlignment = .center
        valueLabel.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(self.valueStepper)
            make.right.equalTo(self.valueStepper)
            make.top.equalTo(self.valueStepper.snp.bottom).offset(10)
            make.bottom.equalTo(self.submitButton)
        }
        
        if self.goal.autodata == "apple" {
            let appleSyncView = UIView()
            self.scrollView.addSubview(appleSyncView)
            appleSyncView.snp.makeConstraints({ (make) in
                make.top.equalTo(self.datapointsTableView.snp.bottom).offset(10)
                if #available(iOS 11.0, *) {
                    make.left.equalTo(self.view.safeAreaLayoutGuide.snp.leftMargin).offset(10)
                } else {
                    make.left.equalTo(10)
                }
                make.right.equalTo(self.datapointsTableView)
                make.bottom.equalTo(0)
                make.height.equalTo(120)
            })
            
            let syncTodayButton = BSButton()
            appleSyncView.addSubview(syncTodayButton)
            syncTodayButton.snp.makeConstraints({ (make) in
                make.left.top.equalTo(10)
                make.right.equalTo(-10)
                make.height.equalTo(42)
            })
            syncTodayButton.setTitle("Sync with Health app", for: .normal)
            syncTodayButton.addTarget(self, action: #selector(self.syncTodayButtonPressed), for: .touchUpInside)
            
            let syncWeekButton = BSButton()
            appleSyncView.addSubview(syncWeekButton)
            syncWeekButton.snp.makeConstraints({ (make) in
                make.left.right.equalTo(syncTodayButton)
                make.top.equalTo(syncTodayButton.snp.bottom).offset(10)
                make.height.equalTo(42)
            })
            syncWeekButton.setTitle("Sync last 7 days", for: .normal)
            syncWeekButton.addTarget(self, action: #selector(self.syncWeekButtonPressed), for: .touchUpInside)
        }
        
        self.navigationItem.rightBarButtonItems = [UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(self.actionButtonPressed))]
        if (!self.goal.hideDataEntry()) {
            self.navigationItem.rightBarButtonItems?.append(UIBarButtonItem(image: UIImage.init(named: "Timer"), style: .plain, target: self, action: #selector(self.timerButtonPressed)))
        }
        
    }
    
    @objc func syncTodayButtonPressed() {
        self.syncHealthDataButtonPressed(numDays: 1)
    }
    
    @objc func syncWeekButtonPressed() {
        self.syncHealthDataButtonPressed(numDays: 7)
    }

    private func syncHealthDataButtonPressed(numDays: Int) {
        let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
        hud?.mode = .indeterminate
        self.goal.hkQueryForLast(days: numDays, success: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                hud?.mode = .customView
                hud?.customView = UIImageView(image: UIImage(named: "checkmark"))
                hud?.hide(true, afterDelay: 2)
            })
        }) {
            DispatchQueue.main.async {
                MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
            }
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if (!CurrentUserManager.sharedManager.signedIn()) { return }
        if keyPath == "graph_url" {
            self.setGraphImage()
        } else if keyPath == "delta_text" || keyPath == "safebump" || keyPath == "safesum" {
            self.refreshCountdown()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.refreshGoal()
    }
    
    @objc func timerButtonPressed() {
        let controller = TimerViewController()
        controller.slug = self.goal.slug
        controller.goal = self.goal
        controller.modalPresentationStyle = .fullScreen
        do {
            let hoursRegex = try NSRegularExpression(pattern: "(hr|hour)s?")
            let minutesRegex = try NSRegularExpression(pattern: "(min|minute)s?")
            if hoursRegex.firstMatch(in: self.goal.yaxis, options: [], range: NSMakeRange(0, self.goal.yaxis.count)) != nil {
                controller.units = "hours"
            }
            if minutesRegex.firstMatch(in: self.goal.yaxis, options: [], range: NSMakeRange(0, self.goal.yaxis.count)) != nil {
                controller.units = "minutes"
            }
        } catch {
            //
        }
        self.present(controller, animated: true, completion: nil)
    }
    
    @objc func actionButtonPressed() {
        guard let username = CurrentUserManager.sharedManager.username,
            let accessToken = CurrentUserManager.sharedManager.accessToken,
            let viewGoalUrl = URL(string: "\(RequestManager.baseURLString)/api/v1/users/\(username).json?access_token=\(accessToken)&redirect_to_url=\(RequestManager.baseURLString)/\(username)/\(self.goal.slug)") else { return }
        
        let safariVC = SFSafariViewController(url: viewGoalUrl)
        safariVC.delegate = self
        self.showDetailViewController(safariVC, sender: self)
    }
    
    @objc func refreshButtonPressed() {
        self.scrollView.refreshControl?.endRefreshing()
        MBProgressHUD.showAdded(to: self.view, animated: true)?.mode = .indeterminate
        
        RequestManager.get(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!)/goals/\(self.goal.slug)/refresh_graph.json", parameters: nil, success: { (responseObject) in
            self.pollUntilGraphUpdates()
        }) { (error, errorMessage) in
            let alert = UIAlertController(title: "Error", message: "Could not refresh graph", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    @objc func colonButtonPressed() {
        self.valueTextField.text?.append(":")
    }
    
    @objc func refreshCountdown() {
        self.countdownLabel.textColor = self.goal.countdownColor
        self.countdownLabel.text = self.goal.capitalSafesum() + " or pay $\(self.goal.pledge)"
    }
    
    func setGraphImage() {
        if CurrentUserManager.sharedManager.isDeadbeat() {
            self.goalImageView.image = UIImage(named: "GraphPlaceholder")
        } else {
            self.goalImageView.af_setImage(withURL: URL(string: self.goal.cacheBustingGraphUrl)!, placeholderImage: UIImage(named: "GraphPlaceholder"), filter: nil, progress: nil, progressQueue: DispatchQueue.global(), imageTransition: .noTransition, runImageTransitionIfCached: false, completion: nil)
        }
    }
    
    @objc func goalImageTapped() {
        self.goalImageScrollView.setZoomScale(self.goalImageScrollView.zoomScale == 1.0 ? 2.0 : 1.0, animated: true)
    }
    
    @objc func dateStepperValueChanged() {
        let calendar = Calendar(identifier: Calendar.Identifier.gregorian)
        var components = DateComponents()
        components.day = Int(self.dateStepper.value)
        
        let newDate = (calendar as NSCalendar?)?.date(byAdding: components, to: Date(), options: [])
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "d"
        self.dateTextField.text = formatter.string(from: newDate!)
    }
    
    func setValueTextField() {
        if let lastDatapoint = self.goal!.recent_data?.last as? JSON {
            self.valueTextField.text = "\(String(describing: lastDatapoint["value"]))"
        }
    }
    
    @objc func valueStepperValueChanged() {
        var valueString = ""
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.groupingSeparator = ""
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
    
    @objc func valueTextFieldValueChanged() {
        var intPart : Double = 0;
        let fractPart : Double = modf((self.valueTextField.text! as NSString).doubleValue, &intPart);
        
        self.valueStepper.value = intPart
        self.valueDecimalRemnant = abs(fractPart)
        if intPart < 0 && self.valueDecimalRemnant > 0 { self.valueStepper.value = intPart - 1 }
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if (textField.isEqual(self.valueTextField)) {
            if textField.text!.components(separatedBy: ".").count > 1 {
                if string == "." || string == "," { return false }
            }
            if (string == ",") {
                textField.text = textField.text! + "."
                return false
            }
            if (string as NSString).rangeOfCharacter(from: CharacterSet(charactersIn: "1234567890.").inverted).location != NSNotFound {
                return false
            }
        }
        return true
    }
    
    func urtextFromTextFields() -> String {
        return "\(self.dateTextField.text!) \(self.valueTextField.text!) \"\(self.commentTextField.text!)\""
    }
    
    @objc func submitDatapoint() {
        self.view.endEditing(true)
        let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
        hud?.mode = .indeterminate
        self.submitButton.isUserInteractionEnabled = false
        self.scrollView.scrollRectToVisible(CGRect(x: 0, y: 0, width: 0, height: 0), animated: true)

        RequestManager.addDatapoint(urtext: self.urtextFromTextFields(), slug: self.goal.slug) { (responseObject) in
            self.commentTextField.text = ""
            self.refreshGoal()
            self.pollUntilGraphUpdates()
            self.submitButton.isUserInteractionEnabled = true
            CurrentUserManager.sharedManager.fetchGoals(success: nil, error: nil)
        } errorHandler: { (error, errorMessage) in
            self.submitButton.isUserInteractionEnabled = true
            MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
            let alertController = UIAlertController(title: "Error", message: "Failed to add datapoint", preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .cancel))
            self.present(alertController, animated: true)
            //UIAlertView(title: "Error", message: "Failed to add datapoint", delegate: nil, cancelButtonTitle: "OK").show()
        }
    }
    
    func pollUntilGraphUpdates() {
        if self.pollTimer != nil { return }
        let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
        hud?.mode = .indeterminate
        hud?.show(true)
        self.pollTimer = Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(self.refreshGoal), userInfo: nil, repeats: true)
    }
    
    @objc func refreshGoal() {
        RequestManager.get(url: "/api/v1/users/\(CurrentUserManager.sharedManager.username!)/goals/\(self.goal.slug)?access_token=\(CurrentUserManager.sharedManager.accessToken!)&datapoints_count=5", parameters: nil, success: { (responseObject) in
            self.goal = JSONGoal(json: JSON(responseObject!))
            self.datapointsTableView.reloadData()
            self.refreshCountdown()
            self.setValueTextField()
            self.valueTextFieldValueChanged()
            self.deltasLabel.attributedText = self.goal!.attributedDeltaText
            if (!self.goal.queued!) {
                self.setGraphImage()
                MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
                self.pollTimer?.invalidate()
                self.pollTimer = nil
            }
        }) { (error, errorMessage) in
            // foo
        }
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.goalImageView
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 24
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 24
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 5
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.view.endEditing(true)
        
        guard !self.goal.hideDataEntry() else { return }
        
        guard let goal = self.goal, let data = goal.recent_data, indexPath.row < data.count else { return }
        
        guard let datapointJSON = data[indexPath.row] as? JSON else { return }
        
        let editDatapointViewController = EditDatapointViewController()
        editDatapointViewController.datapointJSON = datapointJSON
        editDatapointViewController.goalSlug = goal.slug
        self.navigationController?.pushViewController(editDatapointViewController, animated: true)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: self.cellIdentifier) as! DatapointTableViewCell
        
        guard let goal = self.goal, let data = goal.recent_data, indexPath.row < data.count else {
            return cell
        }

        guard let datapoint = data[indexPath.row] as? JSON else {
            return cell
        }
        
        let text = datapoint["canonical"].string
        cell.datapointText = text
        
        return cell
    }
    
    // MARK: - SFSafariViewControllerDelegate
    
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
}
