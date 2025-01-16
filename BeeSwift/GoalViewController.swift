//
//  GoalViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/24/15.
//  Copyright 2015 APB. All rights reserved.
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

    let goal: Goal
    private let healthStoreManager: HealthStoreManager
    private let goalManager: GoalManager
    private let requestManager: RequestManager
    private let currentUserManager: CurrentUserManager
    
    private let timeElapsedView = FreshnessIndicatorView()
    fileprivate var goalImageView = GoalImageView(isThumbnail: false)
    fileprivate var datapointTableController = DatapointTableViewController()
    fileprivate var dateTextField = UITextField()
    fileprivate var valueTextField = UITextField()
    fileprivate var commentTextField = UITextField()
    fileprivate var dateStepper = UIStepper()
    fileprivate var valueStepper = UIStepper()
    fileprivate var valueDecimalRemnant : Double = 0.0
    fileprivate var goalImageScrollView = UIScrollView()
    fileprivate var lastUpdatedTimer: Timer?
    fileprivate var countdownLabel = BSLabel()
    fileprivate var scrollView = UIScrollView()
    fileprivate var submitButton = BSButton()
    fileprivate let headerWidth = Double(1.0/3.0)

    // date corresponding to the datapoint to be created
    private var date: Date = Date()
    
    init(goal: Goal, 
         healthStoreManager: HealthStoreManager,
         goalManager: GoalManager,
         requestManager: RequestManager,
         currentUserManager: CurrentUserManager) {
        self.goal = goal
        self.healthStoreManager = healthStoreManager
        self.goalManager = goalManager
        self.requestManager = requestManager
        self.currentUserManager = currentUserManager
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        self.view.backgroundColor = UIColor.systemBackground
        self.title = self.goal.slug

        // have to set these before the datapoints since setting the most recent datapoint updates the text field,
        // which in turn updates the stepper
        self.valueStepper.minimumValue = -10000000
        self.valueStepper.maximumValue = 1000000
        self.dateStepper.minimumValue = -365
        self.dateStepper.maximumValue = 365

        self.view.addSubview(self.timeElapsedView)
        self.timeElapsedView.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.topMargin)
            make.left.equalTo(0)
            make.right.equalTo(0)
        }
        
        self.updateLastUpdatedLabel()
        lastUpdatedTimer = Timer.scheduledTimer(timeInterval: 60, target: self, selector: #selector(GoalViewController.updateLastUpdatedLabel), userInfo: nil, repeats: true)
        
        self.view.addSubview(self.scrollView)
        self.scrollView.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(timeElapsedView.snp.bottom)
            make.left.equalTo(self.view.safeAreaLayoutGuide.snp.leftMargin)
            make.right.equalTo(self.view.safeAreaLayoutGuide.snp.rightMargin)
            make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottomMargin)
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
        self.dateTextField.tintColor = UIColor.Beeminder.gray
        self.dateTextField.layer.borderColor = UIColor.Beeminder.gray.cgColor
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
        self.valueTextField.tintColor = UIColor.Beeminder.gray
        self.valueTextField.layer.borderColor = UIColor.Beeminder.gray.cgColor
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
        self.commentTextField.tintColor = UIColor.Beeminder.gray
        self.commentTextField.layer.borderColor = UIColor.Beeminder.gray.cgColor
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

        self.dateStepper.tintColor = UIColor.Beeminder.gray
        dataEntryView.addSubview(self.dateStepper)
        self.dateStepper.addTarget(self, action: #selector(GoalViewController.dateStepperValueChanged), for: .valueChanged)
        self.dateStepper.value = Self.makeInitialDateStepperValue(for: goal)

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

        self.valueStepper.tintColor = UIColor.Beeminder.gray
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
        
        let menuBarItem = UIBarButtonItem(barButtonSystemItem: .action, target: nil, action: nil)
        menuBarItem.menu = createGoalMenu()
        
        self.navigationItem.rightBarButtonItems = [menuBarItem]
        if !self.goal.hideDataEntry {
            self.navigationItem.rightBarButtonItems?.append(UIBarButtonItem(image: UIImage(systemName: "stopwatch"), style: .plain, target: self, action: #selector(self.timerButtonPressed)))
        }

        NotificationCenter.default.addObserver(self, selector: #selector(onGoalsUpdatedNotification), name: GoalManager.NotificationName.goalsUpdated, object: nil)

        setValueTextField()
        updateInterfaceToMatchGoal()
    }
    
    override func viewDidLayoutSubviews() {
        // Ensure the submit button is always visible below the keyboard when interacting with
        // the submit datapoint controls
        let addDataPointAdditionalKeyboardDistance = self.submitButton.frame.height
        self.dateTextField.iq.distanceFromKeyboard = addDataPointAdditionalKeyboardDistance
        self.valueTextField.iq.distanceFromKeyboard = addDataPointAdditionalKeyboardDistance
        self.commentTextField.iq.distanceFromKeyboard = addDataPointAdditionalKeyboardDistance
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        lastUpdatedTimer?.invalidate()
        lastUpdatedTimer = nil
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
        self.present(controller, animated: true, completion: nil)
    }
    
    @objc func refreshButtonPressed() {
        Task { @MainActor in
            do {
                if self.goal.isLinkedToHealthKit {
                    try await self.healthStoreManager.updateWithRecentData(goalID: self.goal.objectID, days: 7)
                } else if goal.isDataProvidedAutomatically {
                    // Don't force a refresh for manual goals. While doing so is harmless, it queues the goal which means we show a
                    // lemniscate for a few seconds, making the refresh slower.
                    try await self.goalManager.forceAutodataRefresh(self.goal)
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

        let now = Date()
        guard let newDate = calendar.date(byAdding: components, to: now) else { return }
        self.date = newDate
        
        let isDifferentYear = calendar.component(.year, from: now) != calendar.component(.year, from: date)
        let isDifferentMonth = calendar.component(.month, from: now) != calendar.component(.month, from: date)

        self.dateTextField.text = DateFormatter.dateTextFieldString(from: self.date, isDifferentYear: isDifferentYear, isDifferentMonth: isDifferentMonth)
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
        if textField.isEqual(self.valueTextField) {
            // Only allow a single decimal separator (, or .)
            if textField.text!.components(separatedBy: ".").count > 1 {
                if string == "." || string == "," { return false }
            }
            if string == "," {
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
    
    private var urtext: String {
        return "\(DateFormatter.urtextDateString(from: self.date)) \(self.valueTextField.text!) \"\(self.commentTextField.text!)\""
    }

    @objc func submitDatapoint() {
        Task { @MainActor in
            self.view.endEditing(true)
            let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
            hud.mode = .indeterminate
            self.submitButton.isUserInteractionEnabled = false
            self.scrollView.scrollRectToVisible(CGRect(x: 0, y: 0, width: 0, height: 0), animated: true)

            do {
                let _ = try await self.requestManager.addDatapoint(urtext: self.urtext, slug: self.goal.slug)
                self.commentTextField.text = ""

                try await self.updateGoalAndInterface()

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
                try await self.goalManager.refreshGoals()
            } catch {
                logger.error("Failed up refresh goals after posting: \(error)")
            }
        }
    }

    func updateGoalAndInterface() async throws {
        try await self.goalManager.refreshGoal(self.goal.objectID)
        updateInterfaceToMatchGoal()
    }

    func updateInterfaceToMatchGoal() {
        self.datapointTableController.hhmmformat = goal.hhmmFormat
        self.datapointTableController.datapoints = goal.recentData.sorted(by: {$0.updatedAt < $1.updatedAt})

        self.refreshCountdown()
        self.updateLastUpdatedLabel()
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.goalImageView
    }
    
    private static func makeInitialDateStepperValue(date: Date = Date(), for goal: Goal) -> Double {
        let daystampAccountingForTheGoalsDeadline = Daystamp(fromDate: date,
                                                             deadline: goal.deadline)
        let daystampAssumingMidnightDeadline = Daystamp(fromDate: date,
                                                        deadline: 0)
        
        return Double(daystampAssumingMidnightDeadline.distance(to: daystampAccountingForTheGoalsDeadline))
    }
    
    @objc func updateLastUpdatedLabel() {
        let lastUpdated = self.goal.lastModifiedLocal
        
        self.timeElapsedView.update(with: lastUpdated)
    }

    // MARK: - SFSafariViewControllerDelegate

    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
}

private extension DateFormatter {
    private static let urtextDateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US")
            formatter.dateFormat = "yyyy MM dd"
            return formatter
        }()
    
    static func urtextDateString(from date: Date) -> String {
        urtextDateFormatter.string(from: date)
    }
}

private extension DateFormatter {
    private static let newDatapointDateDifferentYearDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    private static let newDatapointDateDifferentMonthDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMM d"
        return formatter
    }()
    
    private static let newDatapointDateWithinSameMonthDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "d"
        return formatter
    }()
    
    static func dateTextFieldString(from date: Date, isDifferentYear: Bool, isDifferentMonth: Bool) -> String {
        if isDifferentYear {
            return newDatapointDateDifferentYearDateFormatter.string(from: date)
        } else if isDifferentMonth {
            return newDatapointDateDifferentMonthDateFormatter.string(from: date)
        } else {
            return newDatapointDateWithinSameMonthDateFormatter.string(from: date)
        }
    }
}

private extension GoalViewController {
    enum MenuAction {
        case goalCommitment
        case goalStop
        case goalData
        case goalStatistics
        case goalSettings
        
        func makeLink(username: String, goalName: String) -> URL? {
            guard
                let accessToken = self.currentUserManager.accessToken
            else { return nil }
            
            let destinationUrl: URL
            
            switch self {
            case .goalCommitment:
                destinationUrl = DeeplinkGenerator.generateDeepLinkToGoalCommitment(username: username, goalName: goalName)
            case .goalStop:
                destinationUrl = DeeplinkGenerator.generateDeepLinkToGoalStop(username: username, goalName: goalName)
            case .goalData:
                destinationUrl = DeeplinkGenerator.generateDeepLinkToGoalData(username: username, goalName: goalName)
            case .goalStatistics:
                destinationUrl = DeeplinkGenerator.generateDeepLinkToGoalStatistics(username: username, goalName: goalName)
            case .goalSettings:
                destinationUrl = DeeplinkGenerator.generateDeepLinkToGoalSettings(username: username, goalName: goalName)
            }
            
            return DeeplinkGenerator.generateDeepLinkToUrl(accessToken: accessToken, username: username, url: destinationUrl)
        }
    }
    
    struct MenuOption {
        let title: String
        let action: MenuAction
        let imageSystemName: String
    }
    
    private func getMenuOptions() -> [MenuOption] {
        [
            MenuOption(title: "Commitment", action: .goalCommitment, imageSystemName: "signature"),
            MenuOption(title: "Stop/Pause", action: .goalStop, imageSystemName: "pause.fill"),
            MenuOption(title: "Data", action: .goalData, imageSystemName: "tablecells"),
            MenuOption(title: "Statistics", action: .goalStatistics, imageSystemName: "chart.bar.fill"),
            MenuOption(title: "Settings", action: .goalSettings, imageSystemName: "gearshape.2"),
        ]
    }
    
    private func createGoalMenu() -> UIMenu {
        let options = getMenuOptions()
        let actions = options.map { option in
            UIAction(title: option.title, image: UIImage(systemName: option.imageSystemName), handler: { [weak self] _ in
                guard let self else { return }
                guard let link = option.action.makeLink(username: self.goal.owner.username, goalName: self.goal.slug) else { return }
            
                let safariVC = SFSafariViewController(url: link)
                safariVC.delegate = self
                self.showDetailViewController(safariVC, sender: self)
            })
        }
        
        return UIMenu(title: "bmndr.com/\(goal.owner.username)/\(goal.slug)", children: actions)
    }
}
