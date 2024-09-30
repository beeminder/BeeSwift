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
import OSLog

class GoalViewController: UIViewController,  UIScrollViewDelegate, DatapointTableViewControllerDelegate, UITextFieldDelegate, SFSafariViewControllerDelegate {
    let elementSpacing = 10
    let sideMargin = 10
    let buttonHeight = 42

    private let logger = Logger(subsystem: "com.beeminder.com", category: "GoalViewController")

    var goal : Goal!

    fileprivate var goalImageView = GoalImageView(isThumbnail: false)
    fileprivate var datapointTableController = DatapointTableViewController()
    fileprivate var dateTextField = UITextField()
    fileprivate var valueTextField = UITextField()
    fileprivate var commentTextField = UITextField()
    fileprivate var dateStepper = UIStepper()
    fileprivate var valueStepper = UIStepper()
    fileprivate var valueDecimalRemnant : Double = 0.0
    fileprivate var goalImageScrollView = UIScrollView()
    fileprivate var pollTimer : Timer?
    fileprivate var countdownLabel = BSLabel()
    fileprivate var scrollView = UIScrollView()
    fileprivate var submitButton = BSButton()
    fileprivate let headerWidth = Double(1.0/3.0)
    fileprivate let viewGoalActivityType = "com.beeminder.viewGoal"

    override func viewDidLoad() {
        self.view.backgroundColor = UIColor.systemBackground
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

        self.scrollView.addSubview(self.goalImageScrollView)
        self.goalImageScrollView.showsHorizontalScrollIndicator = false
        self.goalImageScrollView.showsVerticalScrollIndicator = false
        self.goalImageScrollView.minimumZoomScale = 1.0
        self.goalImageScrollView.maximumZoomScale = 3.0
        self.goalImageScrollView.delegate = self
        self.goalImageScrollView.snp.makeConstraints { (make) -> Void in
            make.centerX.equalTo(self.view)
            make.left.greaterThanOrEqualTo(self.scrollView.safeAreaLayoutGuide.snp.leftMargin)
            make.right.lessThanOrEqualTo(self.scrollView.safeAreaLayoutGuide.snp.rightMargin)

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
        self.goalImageView.goal = self.goal

        self.addChild(self.datapointTableController)
        self.scrollView.addSubview(self.datapointTableController.view)
        self.datapointTableController.delegate = self
        self.datapointTableController.view.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(self.goalImageScrollView.snp.bottom).offset(elementSpacing)
            make.left.equalTo(self.goalImageScrollView).offset(sideMargin)
            make.right.equalTo(self.goalImageScrollView).offset(-sideMargin)
        }

        let dataEntryView = UIView()
        dataEntryView.isHidden = self.goal.hideDataEntry

        self.scrollView.addSubview(dataEntryView)
        dataEntryView.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(self.datapointTableController.view.snp.bottom).offset(elementSpacing)
            make.left.equalTo(self.datapointTableController.view)
            make.right.equalTo(self.datapointTableController.view)
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

        let accessory = DatapointValueAccessory()
        accessory.valueField = self.valueTextField
        self.valueTextField.inputAccessoryView = accessory
        self.valueTextField.addTarget(self, action: #selector(GoalViewController.valueTextFieldValueChanged), for: .editingChanged)
        self.valueTextField.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(self.dateTextField.snp.right).offset(elementSpacing)
            make.height.equalTo(Constants.defaultTextFieldHeight)
            make.top.equalTo(0)
        }

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
            make.right.equalTo(self.view.safeAreaLayoutGuide.snp.rightMargin).offset(-10).priority(.high)
            make.top.equalTo(0)
        }

        dataEntryView.addSubview(self.submitButton)
        self.submitButton.setTitle("Submit", for: UIControl.State())
        self.submitButton.addTarget(self, action: #selector(GoalViewController.submitDatapoint), for: .touchUpInside)
        self.submitButton.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(self.commentTextField.snp.bottom).offset(elementSpacing)
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
        if self.goal.deadline > 0 && currentHour! < 6 && currentHour! < self.goal.deadline/3600 {
            self.dateStepper.value = -1
        }

        // if the goal's deadline is before midnight and has already passed for this calendar day, default to entering data for the "next" day
        if self.goal.deadline < 0 {
            let deadlineSecondsAfterMidnight = 24*3600 + self.goal.deadline
            let deadlineHour = deadlineSecondsAfterMidnight/3600
            let deadlineMinute = (deadlineSecondsAfterMidnight % 3600)/60
            let currentMinute = components.minute
            if deadlineHour < currentHour! ||
                (deadlineHour == currentHour! && deadlineMinute < currentMinute!) {
                self.dateStepper.value = 1
            }
        }

        self.dateStepper.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(self.dateTextField.snp.bottom).offset(elementSpacing)
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
            make.top.equalTo(self.dateStepper.snp.bottom).offset(elementSpacing)
        }

        self.valueStepper.tintColor = UIColor.beeminder.gray
        dataEntryView.addSubview(self.valueStepper)
        self.valueStepper.addTarget(self, action: #selector(GoalViewController.valueStepperValueChanged), for: .valueChanged)
        self.valueStepper.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(self.dateStepper)
            make.left.equalTo(self.dateStepper.snp.right).offset(elementSpacing)
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
            make.top.equalTo(self.valueStepper.snp.bottom).offset(elementSpacing)
            make.bottom.equalTo(self.submitButton)
        }

        if self.goal.isDataProvidedAutomatically {
            let pullToRefreshView = PullToRefreshView()
            scrollView.addSubview(pullToRefreshView)

            if self.goal.isLinkedToHealthKit {
                pullToRefreshView.message = "Pull down to synchronize with Apple Health"
            } else {
                pullToRefreshView.message = "Pull down to update"
            }

            pullToRefreshView.snp.makeConstraints { (make) in
                make.top.equalTo(self.datapointTableController.view.snp.bottom).offset(elementSpacing)
                make.left.equalTo(sideMargin)
                make.right.equalTo(-sideMargin)
            }
        }

        self.navigationItem.rightBarButtonItems = [UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(self.actionButtonPressed))]
        if (!self.goal.hideDataEntry) {
            self.navigationItem.rightBarButtonItems?.append(UIBarButtonItem(image: UIImage.init(named: "Timer"), style: .plain, target: self, action: #selector(self.timerButtonPressed)))
        }

        NotificationCenter.default.addObserver(self, selector: #selector(onGoalsUpdatedNotification), name: NSNotification.Name(rawValue: GoalManager.goalsUpdatedNotificationName), object: nil)

        setValueTextField()
        updateInterfaceToMatchGoal()
    }

    override func viewDidLayoutSubviews() {
        // Ensure the submit button is always visible below the keyboard when interacting with
        // the submit datapoint controls
        let addDataPointAdditionalKeyboardDistance = self.submitButton.frame.height
        self.dateTextField.keyboardDistanceFromTextField = addDataPointAdditionalKeyboardDistance
        self.valueTextField.keyboardDistanceFromTextField = addDataPointAdditionalKeyboardDistance
        self.commentTextField.keyboardDistanceFromTextField = addDataPointAdditionalKeyboardDistance
    }

    @objc func onGoalsUpdatedNotification() {
        updateInterfaceToMatchGoal()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task { @MainActor in
            do {
                try await self.updateGoalAndInterface()
            } catch {
                logger.error("Error refreshing details for goal \(self.goal.slug): \(error)")
            }
        }
    }

    @objc func timerButtonPressed() {
        let controller = TimerViewController(goal: self.goal)
        controller.modalPresentationStyle = .fullScreen
        do {
            let hoursRegex = try NSRegularExpression(pattern: "(hr|hour)s?")
            let minutesRegex = try NSRegularExpression(pattern: "(min|minute)s?")
            if hoursRegex.firstMatch(in: self.goal.yAxis, options: [], range: NSMakeRange(0, self.goal.yAxis.count)) != nil {
                controller.units = "hours"
            }
            if minutesRegex.firstMatch(in: self.goal.yAxis, options: [], range: NSMakeRange(0, self.goal.yAxis.count)) != nil {
                controller.units = "minutes"
            }
        } catch {
            //
        }
        self.present(controller, animated: true, completion: nil)
    }

    @objc func actionButtonPressed() {
        guard let username = ServiceLocator.currentUserManager.username,
            let accessToken = ServiceLocator.currentUserManager.accessToken,
            let viewGoalUrl = URL(string: "\(ServiceLocator.requestManager.baseURLString)/api/v1/users/\(username).json?access_token=\(accessToken)&redirect_to_url=\(ServiceLocator.requestManager.baseURLString)/\(username)/\(self.goal.slug)") else { return }

        let safariVC = SFSafariViewController(url: viewGoalUrl)
        safariVC.delegate = self
        self.showDetailViewController(safariVC, sender: self)
    }

    @objc func refreshButtonPressed() {
        Task { @MainActor in
            do {
                if self.goal.isLinkedToHealthKit {
                    try await ServiceLocator.healthStoreManager.updateWithRecentData(goalID: self.goal.objectID, days: 7)
                } else if goal.isDataProvidedAutomatically {
                    // Don't force a refresh for manual goals. While doing so is harmless, it queues the goal which means we show a
                    // lemniscate for a few seconds, making the refresh slower.
                    try await ServiceLocator.goalManager.forceAutodataRefresh(self.goal)
                }
                try await self.updateGoalAndInterface()
            } catch {
                logger.error("Error refreshing goal: \(error, privacy: .public)")
                let alert = UIAlertController(title: "Error", message: "Could not refresh graph", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }

            self.scrollView.refreshControl?.endRefreshing()
        }
    }

    @objc func refreshCountdown() {
        self.countdownLabel.textColor = self.goal.countdownColor
        self.countdownLabel.text = self.goal.capitalSafesum()
    }

    @objc func goalImageTapped() {
        self.goalImageScrollView.setZoomScale(self.goalImageScrollView.zoomScale == 1.0 ? 2.0 : 1.0, animated: true)
    }

    func datapointTableViewController(_ datapointTableViewController: DatapointTableViewController, didSelectDatapoint datapoint: BeeDataPoint) {
        guard !self.goal.hideDataEntry else { return }
        guard let existingDatapoint = datapoint as? DataPoint else { return }

        let editDatapointViewController = EditDatapointViewController(goal: goal, datapoint: existingDatapoint)
        let navigationController = UINavigationController(rootViewController: editDatapointViewController)
        navigationController.modalPresentationStyle = .formSheet
        self.present(navigationController, animated: true, completion: nil)
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
        let suggestedNextValue = goal.suggestedNextValue ?? 1
        valueTextField.text = "\(String(describing: suggestedNextValue))"
        valueTextFieldValueChanged()
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
            // Only allow a single decimal separator (, or .)
            if textField.text!.components(separatedBy: ".").count > 1 {
                if string == "." || string == "," { return false }
            }
            if (string == ",") {
                textField.text = textField.text! + "."
                return false
            }
            // Only allow a single : time separator
            if textField.text!.components(separatedBy: ":").count > 1 && string == ":" {
                return false
            }
            if (string as NSString).rangeOfCharacter(from: CharacterSet(charactersIn: "1234567890.:").inverted).location != NSNotFound {
                return false
            }
        }
        return true
    }

    func urtextFromTextFields() -> String {
        return "\(self.dateTextField.text!) \(self.valueTextField.text!) \"\(self.commentTextField.text!)\""
    }

    @objc func submitDatapoint() {
        Task { @MainActor in
            self.view.endEditing(true)
            let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
            hud.mode = .indeterminate
            self.submitButton.isUserInteractionEnabled = false
            self.scrollView.scrollRectToVisible(CGRect(x: 0, y: 0, width: 0, height: 0), animated: true)

            do {
                let _ = try await ServiceLocator.requestManager.addDatapoint(urtext: self.urtextFromTextFields(), slug: self.goal.slug)
                self.commentTextField.text = ""

                try await updateGoalAndInterface()

                self.submitButton.isUserInteractionEnabled = true
                MBProgressHUD.hide(for: self.view, animated: true)
            } catch {
                self.submitButton.isUserInteractionEnabled = true
                MBProgressHUD.hide(for: self.view, animated: true)
                let alertController = UIAlertController(title: "Error", message: "Failed to add datapoint", preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "OK", style: .cancel))
                self.present(alertController, animated: true)

                return
            }

            do {
                try await ServiceLocator.goalManager.refreshGoals()
            } catch {
                logger.error("Failed up refresh goals after posting: \(error)")
            }
        }
    }

    func updateGoalAndInterface() async throws {
        try await ServiceLocator.goalManager.refreshGoal(self.goal.objectID)
        updateInterfaceToMatchGoal()
    }

    func updateInterfaceToMatchGoal() {
        self.datapointTableController.hhmmformat = goal.hhmmFormat
        self.datapointTableController.datapoints = goal.recentData.sorted(by: {$0.updatedAt < $1.updatedAt})

        self.refreshCountdown()
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.goalImageView
    }

    // MARK: - SFSafariViewControllerDelegate

    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
}
