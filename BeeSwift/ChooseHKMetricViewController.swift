//
//  ChooseHKMetricViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 3/29/17.
//  Copyright © 2017 APB. All rights reserved.
//

import UIKit
import HealthKit
import OSLog

class ChooseHKMetricViewController: UIViewController {
    fileprivate let logger = Logger(subsystem: "com.beeminder.beeminder", category: "ChooseHKMetricViewController")
    fileprivate let cellReuseIdentifier = "hkMetricTableViewCell"
    fileprivate var tableView = UITableView()
    var goal : JSONGoal!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = .systemBackground
        self.title = "Choose HK Metric"
        
        let instructionsLabel = BSLabel()
        self.view.addSubview(instructionsLabel)
        
        instructionsLabel.attributedText = {
            let attrString = NSMutableAttributedString()
            
            attrString.append(NSMutableAttributedString(string: "Configuring goal ",
                                                        attributes: [NSAttributedString.Key.font: UIFont.beeminder.defaultFont]))
            
            attrString.append(NSMutableAttributedString(string: "\(self.goal.slug)\n",
                attributes: [NSAttributedString.Key.font: UIFont.beeminder.defaultBoldFont]))
            
            attrString.append(NSMutableAttributedString(string: "Apple Health metric as autodata!\nWith this metric as the autodata source for your goal, Apple Health will keep Beeminder up to date with your latest data automatically.\n(Technically it updates the Beeminder iOS app which updates Beeminder so you'll have to open the app occasionally.)\nPick a metric from the list below, then hit save to update your goal.",
                                                        attributes: [NSAttributedString.Key.font: UIFont.beeminder.defaultFontLight.withSize(Constants.defaultFontSize)]))
            return attrString
        }()
        
        instructionsLabel.snp.makeConstraints { (make) in
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.topMargin).offset(20)
            make.centerX.equalTo(self.view)
            make.width.equalTo(self.view).multipliedBy(0.85)
        }
        instructionsLabel.numberOfLines = 0
        instructionsLabel.textAlignment = .center
        
        
        let saveButton = BSButton()
        self.view.addSubview(saveButton)
        saveButton.snp.makeConstraints { (make) in
            make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottomMargin).offset(-20)
            make.centerX.equalTo(self.view)
            make.width.equalTo(self.view).multipliedBy(0.5)
            make.height.equalTo(Constants.defaultTextFieldHeight)
        }
        saveButton.setTitle("Save", for: .normal)
        saveButton.addTarget(self, action: #selector(self.saveButtonPressed), for: .touchUpInside)
        
        self.view.addSubview(self.tableView)
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.snp.makeConstraints { (make) in
            make.top.equalTo(instructionsLabel.snp_bottom).offset(20)
            make.centerX.equalTo(self.view)
            make.left.equalTo(0)
            make.right.equalTo(0)
            make.bottom.equalTo(saveButton.snp.top).offset(-20)
        }
        self.tableView.tableFooterView = UIView()
        self.tableView.register(HealthKitMetricTableViewCell.self, forCellReuseIdentifier: self.cellReuseIdentifier)
    }
    
    @objc func saveButtonPressed() {
        guard let selectedRow = self.tableView.indexPathForSelectedRow?.row else { return }
        let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
        hud?.mode = .indeterminate
        let metric = self.sortedHKMetrics[selectedRow]

        Task(priority: .userInitiated) {
            do {
                try await HealthStoreManager.sharedManager.requestAuthorization(metric: metric)
            } catch {
                logger.error("Error requesting authorization \(error)")
                hud?.hide(true)
                return
            }
            self.saveMetric(databaseString: metric.databaseString)
        }
    }
    
    func saveMetric(databaseString : String) {
        let hud = MBProgressHUD.allHUDs(for: self.view).first as? MBProgressHUD

        self.goal!.healthKitMetric = databaseString
        self.goal!.autodata = "apple"
        Task {
            do {
                try await HealthStoreManager.sharedManager.setupHealthKitGoal(goal: self.goal!)
            } catch {
                logger.error("Error setting up goal \(error)")
                hud?.hide(true)
                return
            }
            
            var params : [String : [String : String]] = [:]
            params = ["ii_params" : ["name" : "apple", "metric" : self.goal!.healthKitMetric!]]
            
            RequestManager.put(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!)/goals/\(self.goal!.slug).json", parameters: params, success: { (responseObject) -> Void in
                hud?.mode = .customView
                hud?.customView = UIImageView(image: UIImage(named: "checkmark"))
                hud?.hide(true, afterDelay: 2)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.navigationController?.popViewController(animated: true)
                }
            }) { (responseError, errorMessage) -> Void in
                self.tableView.reloadData()
                if let errorString = responseError?.localizedDescription {
                    MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
                    let alert = UIAlertController(title: "Error saving metric to Beeminder", message: errorString, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

extension ChooseHKMetricViewController : UITableViewDelegate, UITableViewDataSource {
    
    var sortedHKMetrics: [HealthKitMetric] {
        HealthKitConfig.shared.metrics.sorted { (lhs, rhs) -> Bool in
            lhs.humanText < rhs.humanText
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.sortedHKMetrics.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: self.cellReuseIdentifier) as! HealthKitMetricTableViewCell
        
        cell.metric = self.sortedHKMetrics[indexPath.row].humanText
        if tableView.indexPathForSelectedRow == indexPath {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        tableView.cellForRow(at: indexPath)?.accessoryType = .none
    }
}
