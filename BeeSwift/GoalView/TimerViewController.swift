//
//  TimerViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 1/1/18.
//  Copyright 2018 APB. All rights reserved.
//

import BeeKit
import MBProgressHUD
import SnapKit
import UIKit

class TimerViewController: UIViewController {
  private enum TimerUnit { case hours, minutes }

  private lazy var timerLabel: BSLabel = {
    let view = BSLabel()
    view.text = "00:00:00"
    view.textColor = .white
    view.font = UIFont.beeminder.defaultBoldFont.withSize(48)
    return view
  }()
  private lazy var startStopButton: BSButton = {
    let view = BSButton(type: .system)
    view.addTarget(self, action: #selector(self.startStopButtonPressed), for: .touchUpInside)
    view.setTitle("Start", for: .normal)
    view.configuration = .filled()
    return view
  }()
  private lazy var commentTextField: UITextField = {
    let view = UITextField()
    view.font = UIFont.beeminder.defaultFontPlain.withSize(16)
    view.leftViewMode = .always
    view.rightViewMode = .always
    view.tintColor = UIColor.Beeminder.gray
    view.layer.borderColor = UIColor.Beeminder.gray.cgColor
    view.layer.borderWidth = 1
    view.layer.cornerRadius = 6
    view.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
    view.textColor = .white
    view.text = TimerViewController.commentDefault
    view.clearsOnBeginEditing = true
    view.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 1))
    view.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 1))
    return view
  }()
  private lazy var addDatapointButton: BSButton = {
    let view = BSButton(type: .system)
    view.configuration = .filled()
    view.addTarget(self, action: #selector(self.addDatapointButtonPressed), for: .touchUpInside)
    view.setTitle("Add Datapoint to \(self.goal.slug)", for: .normal)
    return view
  }()
  private lazy var resetButton: BSButton = {
    let view = BSButton(type: .system)
    view.configuration = .filled()
    view.addTarget(self, action: #selector(self.resetButtonPressed), for: .touchUpInside)
    view.setTitle("Reset", for: .normal)
    return view
  }()

  private lazy var exitButton: BSButton = {
    let view = BSButton(type: .system)
    view.configuration = .filled()
    view.addTarget(self, action: #selector(self.exitButtonPressed), for: .touchUpInside)
    view.setTitle("Exit", for: .normal)
    return view
  }()
  private static let commentDefault = "Automatically entered from iOS timer interface"

  let goal: Goal
  var timingSince: Date?
  var timer: Timer?
  private let units: TimerUnit
  private let requestManager: RequestManager

  var accumulatedSeconds = 0
  init(goal: Goal, requestManager: RequestManager) {
    self.goal = goal
    self.requestManager = requestManager
    self.units = Self.timerUnit(goal: goal) ?? .hours
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.view.backgroundColor = .darkGray

    self.view.addSubview(self.timerLabel)
    self.timerLabel.snp.makeConstraints { (make) in
      make.centerX.equalTo(self.view)
      make.bottom.equalTo(self.view.snp.centerY).offset(-10)
      make.height.equalTo(Constants.defaultTextFieldHeight)
    }
    self.view.addSubview(exitButton)
    exitButton.snp.makeConstraints { (make) in
      make.left.equalTo(self.view.safeAreaLayoutGuide.snp.leftMargin).offset(10)
      make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottomMargin)
      make.right.equalTo(self.view.snp.centerX).offset(-10)
      make.height.equalTo(Constants.defaultTextFieldHeight)
    }
    self.view.addSubview(self.startStopButton)
    self.startStopButton.snp.makeConstraints { (make) in
      make.top.equalTo(self.view.snp.centerY).offset(10)
      make.centerX.equalTo(self.view)
      make.height.equalTo(Constants.defaultTextFieldHeight)
    }
    self.view.addSubview(addDatapointButton)
    addDatapointButton.snp.makeConstraints { (make) in
      make.top.equalTo(self.startStopButton.snp.bottom).offset(Constants.defaultTextFieldHeight)
      make.centerX.equalTo(self.view)
      make.height.equalTo(Constants.defaultTextFieldHeight)
    }
    self.view.addSubview(resetButton)
    resetButton.snp.makeConstraints { (make) in
      make.left.equalTo(self.view.snp.centerX).offset(10)
      make.right.equalTo(self.view.safeAreaLayoutGuide.snp.rightMargin).offset(-10)
      make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottomMargin)
      make.height.equalTo(Constants.defaultTextFieldHeight)
    }

    self.view.addSubview(self.commentTextField)
    self.commentTextField.snp.makeConstraints { (make) in
      make.top.equalTo(addDatapointButton.snp.bottom).offset(20)
      make.left.equalTo(self.view.safeAreaLayoutGuide.snp.leftMargin).offset(20)
      make.right.equalTo(self.view.safeAreaLayoutGuide.snp.rightMargin).offset(-20)
      make.height.equalTo(Constants.defaultTextFieldHeight)
    }
  }
  @objc func exitButtonPressed() { self.presentingViewController?.dismiss(animated: true, completion: nil) }
  func totalSeconds() -> Double {
    var total = Double(self.accumulatedSeconds)
    if self.timingSince != nil { total += Date().timeIntervalSince(self.timingSince!) }
    return total
  }
  @objc func updateTimerLabel() {
    let total = Int(self.totalSeconds())
    let hours = total / 3600
    let minutes = (total / 60) % 60
    let seconds = total % 60
    let strHours = String(format: "%02d", hours)
    let strMinutes = String(format: "%02d", minutes)
    let strSeconds = String(format: "%02d", seconds)
    self.timerLabel.text = "\(strHours):\(strMinutes):\(strSeconds)"
  }
  @objc func startStopButtonPressed() {
    if self.timingSince == nil {
      self.timingSince = Date()
      self.startStopButton.setTitle("Stop", for: .normal)
      self.timer = Timer.scheduledTimer(
        timeInterval: 1,
        target: self,
        selector: #selector(self.updateTimerLabel),
        userInfo: nil,
        repeats: true,
      )
    } else {
      self.accumulatedSeconds += Int(Date().timeIntervalSince(self.timingSince!))
      self.startStopButton.setTitle("Start", for: .normal)
      self.timer?.invalidate()
      self.timer = nil
      self.timingSince = nil
    }
  }
  @objc func resetButtonPressed() {
    self.startStopButton.setTitle("Start", for: .normal)
    self.timer?.invalidate()
    self.timer = nil
    self.timingSince = nil
    self.accumulatedSeconds = 0
    self.updateTimerLabel()
    self.commentTextField.text = TimerViewController.commentDefault
  }
  func urtext() -> String {
    let urtextDaystamp = Daystamp.makeUrtextDaystamp(submissionDate: Date(), deadline: goal.deadline)
    let value: Double

    switch self.units {
    case .minutes: value = self.totalSeconds() / 60.0
    case .hours: value = self.totalSeconds() / 3600.0
    }
    let comment = self.commentTextField.text ?? ""
    return "\(urtextDaystamp) \(value) \"\(comment)\""
  }
  @objc func addDatapointButtonPressed() {
    let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
    hud.mode = .indeterminate

    Task { @MainActor in
      do {
        let _ = try await requestManager.addDatapoint(urtext: self.urtext(), slug: self.goal.slug)
        hud.mode = .text
        hud.label.text = "Added!"
        DispatchQueue.main.asyncAfter(
          deadline: .now() + 2,
          execute: { MBProgressHUD.hide(for: self.view, animated: true) },
        )
        if let goalVC = self.presentingViewController?.children.last as? GoalViewController {
          try await goalVC.updateGoalAndInterface()
        }
        self.resetButtonPressed()
      } catch {
        MBProgressHUD.hide(for: self.view, animated: true)
        let alertController = UIAlertController(
          title: "Error",
          message: "Failed to add datapoint",
          preferredStyle: .alert,
        )
        alertController.addAction(UIAlertAction(title: "OK", style: .cancel))
        self.present(alertController, animated: true)
      }
    }
  }
}

extension TimerViewController {
  static private func timerUnit(goal: Goal) -> TimerUnit? {
    guard let hoursRegex = try? NSRegularExpression(pattern: "(hr|hour)s?") else { return nil }
    if hoursRegex.firstMatch(in: goal.yAxis, options: [], range: NSMakeRange(0, goal.yAxis.count)) != nil {
      return .hours
    }
    guard let minutesRegex = try? NSRegularExpression(pattern: "(min|minute)s?") else { return nil }
    if minutesRegex.firstMatch(in: goal.yAxis, options: [], range: NSMakeRange(0, goal.yAxis.count)) != nil {
      return .minutes
    }
    return nil
  }
}
