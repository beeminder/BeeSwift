//
//  TimerViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 1/1/18.
//  Copyright © 2018 APB. All rights reserved.
//

import UIKit
import SnapKit
import MBProgressHUD

class TimerViewController: UIViewController {
    
    let timerLabel = BSLabel()
    let startStopButton = BSButton()
    var timingSince: Date?
    var timer: Timer?
    var slug: String?
    var units: String?
    var accumulatedSeconds = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .darkGray

        self.view.addSubview(self.timerLabel)
        self.timerLabel.snp.makeConstraints { (make) in
            make.centerX.equalTo(self.view)
            make.bottom.equalTo(self.view.snp.centerY).offset(-10)
        }
        self.timerLabel.text = "00:00:00"
        self.timerLabel.textColor = .white
        self.timerLabel.font = UIFont(name: "Avenir-Black", size: 48)
        
        let exitButton = BSButton()
        self.view.addSubview(exitButton)
        exitButton.snp.makeConstraints { (make) in
            if #available(iOS 11.0, *) {
                make.left.equalTo(self.view.safeAreaLayoutGuide.snp.leftMargin)
                make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottomMargin)
            } else {
                make.left.bottom.equalTo(0)
            }
            make.right.equalTo(self.view.snp.centerX)
        }
        exitButton.backgroundColor = .clear
        exitButton.addTarget(self, action: #selector(self.exitButtonPressed), for: .touchUpInside)
        exitButton.setTitle("Exit", for: .normal)
        
        self.view.addSubview(self.startStopButton)
        self.startStopButton.snp.makeConstraints { (make) in
            make.top.equalTo(self.view.snp.centerY).offset(10)
            make.centerX.equalTo(self.view)
        }
        self.startStopButton.backgroundColor = .clear
        self.startStopButton.addTarget(self, action: #selector(self.startStopButtonPressed), for: .touchUpInside)
        self.startStopButton.setTitle("Start", for: .normal)
        
        let addDatapointButton = BSButton()
        self.view.addSubview(addDatapointButton)
        addDatapointButton.snp.makeConstraints { (make) in
            make.top.equalTo(self.startStopButton.snp.bottom).offset(10)
            make.centerX.equalTo(self.view)
        }
        addDatapointButton.backgroundColor = .clear
        addDatapointButton.addTarget(self, action: #selector(self.addDatapointButtonPressed), for: .touchUpInside)
        addDatapointButton.setTitle("Add Datapoint", for: .normal)
        
        let resetButton = BSButton()
        self.view.addSubview(resetButton)
        resetButton.snp.makeConstraints { (make) in
            make.left.equalTo(self.view.snp.centerX)
            if #available(iOS 11.0, *) {
                make.right.equalTo(self.view.safeAreaLayoutGuide.snp.rightMargin)
                make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottomMargin)
            } else {
                make.right.bottom.equalTo(0)
            }
        }
        resetButton.addTarget(self, action: #selector(self.resetButtonPressed), for: .touchUpInside)
        resetButton.setTitle("Reset", for: .normal)
        resetButton.backgroundColor = .clear
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "d"
        
        var value = self.totalSeconds()/3600.0
        if self.units == "minutes" { value = self.totalSeconds()/60.0 }
        
        let comment = "Automatically entered from iOS timer interface"
        
        return "\(formatter.string(from: Date())) \(value) \"\(comment)\""
    }
    
    @objc func addDatapointButtonPressed() {
        if self.slug == nil { return }
        let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
        hud?.mode = .indeterminate
        let params = ["urtext": self.urtext(), "requestid": UUID().uuidString]
        RequestManager.post(url: "api/v1/users/me/goals/\(self.slug!)/datapoints.json", parameters: params, success: { (responseObject) in
            hud?.mode = .text
            hud?.labelText = "Added!"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
                MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
            })
            self.resetButtonPressed()
            
        }) { (error) in
            MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
            UIAlertView(title: "Error", message: "Failed to add datapoint", delegate: nil, cancelButtonTitle: "OK").show()
        }
        
    }
}
