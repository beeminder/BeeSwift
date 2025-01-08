//
//  TimerViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 1/1/18.
//  Copyright 2018 APB. All rights reserved.
//

import UIKit
import SnapKit
import MBProgressHUD

import BeeKit

class TimerViewController: UIViewController {
    private enum TimerUnit {
        case hours, minutes
    }

    let timerLabel = BSLabel()
    let startStopButton = BSButton(type: .system)
    let goal: Goal
    var timingSince: Date?
    var timer: Timer?
    private let units: TimerUnit

    var accumulatedSeconds = 0
    
    init(goal: Goal) {
        self.goal = goal
        self.units = Self.timerUnit(goal: goal) ?? .hours
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .darkGray

        self.view.addSubview(self.timerLabel)
        self.timerLabel.snp.makeConstraints { (make) in
            make.centerX.equalTo(self.view)
            make.bottom.equalTo(self.view.snp.centerY).offset(-10)
            make.height.equalTo(Constants.defaultTextFieldHeight)
        }
        self.timerLabel.text = "00:00:00"
        self.timerLabel.textColor = .white
        self.timerLabel.font = UIFont.beeminder.defaultBoldFont.withSize(48)
        
        let exitButton = BSButton(type: .system)
        exitButton.configuration = .filled()
        self.view.addSubview(exitButton)
        exitButton.snp.makeConstraints { (make) in
            make.left.equalTo(self.view.safeAreaLayoutGuide.snp.leftMargin).offset(10)
            make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottomMargin)
            make.right.equalTo(self.view.snp.centerX).offset(-10)
            make.height.equalTo(Constants.defaultTextFieldHeight)
        }
        exitButton.addTarget(self, action: #selector(self.exitButtonPressed), for: .touchUpInside)
        exitButton.setTitle("Exit", for: .normal)
        
        self.view.addSubview(self.startStopButton)
        startStopButton.configuration = .filled()
        self.startStopButton.snp.makeConstraints { (make) in
            make.top.equalTo(self.view.snp.centerY).offset(10)
            make.centerX.equalTo(self.view)
            make.height.equalTo(Constants.defaultTextFieldHeight)
        }
        self.startStopButton.addTarget(self, action: #selector(self.startStopButtonPressed), for: .touchUpInside)
        self.startStopButton.setTitle("Start", for: .normal)
        
        let addDatapointButton = BSButton(type: .system)
        addDatapointButton.configuration = .filled()
        self.view.addSubview(addDatapointButton)
        addDatapointButton.snp.makeConstraints { (make) in
            make.top.equalTo(self.startStopButton.snp.bottom).offset(Constants.defaultTextFieldHeight)
            make.centerX.equalTo(self.view)
            make.height.equalTo(Constants.defaultTextFieldHeight)
        }
        addDatapointButton.addTarget(self, action: #selector(self.addDatapointButtonPressed), for: .touchUpInside)
        addDatapointButton.setTitle("Add Datapoint to \(self.goal.slug)", for: .normal)
        
        let resetButton = BSButton(type: .system)
        resetButton.configuration = .filled()
        self.view.addSubview(resetButton)
        resetButton.snp.makeConstraints { (make) in
            make.left.equalTo(self.view.snp.centerX).offset(10)
            make.right.equalTo(self.view.safeAreaLayoutGuide.snp.rightMargin).offset(-10)
            make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottomMargin)
            make.height.equalTo(Constants.defaultTextFieldHeight)
        }
        resetButton.addTarget(self, action: #selector(self.resetButtonPressed), for: .touchUpInside)
        resetButton.setTitle("Reset", for: .normal)
    }
    
    @objc func exitButtonPressed() {
        self.presentingViewController?.dismiss(animated: true, completion: nil)
    }
    
    func totalSeconds() -> Double {
        var total = Double(self.accumulatedSeconds)
        if self.timingSince != nil {
            total += Date().timeIntervalSince(self.timingSince!)
        }
        return total
    }
    
    @objc func updateTimerLabel() {
        let total = Int(self.totalSeconds())
        let hours = total/3600
        let minutes = (total/60) % 60
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
            self.timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.updateTimerLabel), userInfo: nil, repeats: true)
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
    }
    
    func urtext() -> String {
        let urtextDaystamp = Daystamp.makeUrtextDaystamp(submissionDate: Date(), goal: goal)
        
        let value: Double

        switch self.units {
        case .minutes:
            value = self.totalSeconds()/60.0
        case .hours:
            value = self.totalSeconds()/3600.0
        }
        
        let comment = "Automatically entered from iOS timer interface"
        
        return "\(urtextDaystamp) \(value) \"\(comment)\""
    }
    
    @objc func addDatapointButtonPressed() {
        let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
        hud.mode = .indeterminate

        Task { @MainActor in
            do {
                let _ = try await ServiceLocator.requestManager.addDatapoint(urtext: self.urtext(), slug: self.goal.slug)
                hud.mode = .text
                hud.label.text = "Added!"
                DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
                    MBProgressHUD.hide(for: self.view, animated: true)
                })
                if let goalVC = self.presentingViewController?.children.last as? GoalViewController {
                    try await goalVC.updateGoalAndInterface()
                }
                self.resetButtonPressed()
            } catch {
                MBProgressHUD.hide(for: self.view, animated: true)
                let alertController = UIAlertController(title: "Error", message: "Failed to add datapoint", preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "OK", style: .cancel))
                self.present(alertController, animated: true)
            }
        }
    }
}

private extension TimerViewController {
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
