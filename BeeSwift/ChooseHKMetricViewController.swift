//
//  ChooseHKMetricViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 3/29/17.
//  Copyright © 2017 APB. All rights reserved.
//

import UIKit
import HealthKit

class ChooseHKMetricViewController: UIViewController {
    fileprivate let cellReuseIdentifier = "hkMetricTableViewCell"
    fileprivate var tableView = UITableView()
    var goal : JSONGoal!

    override func viewDidLoad() {
        super.viewDidLoad()

        if #available(iOS 13.0, *) {
            self.view.backgroundColor = .systemBackground
        } else {
            self.view.backgroundColor = .white
        }
        self.title = "Choose HK Metric"
        
        let instructionsLabel = BSLabel()
        self.view.addSubview(instructionsLabel)
        
        instructionsLabel.attributedText = {
            let attrString = NSMutableAttributedString()
            
            attrString.append(NSMutableAttributedString(string: "Configuring goal ",
                                                        attributes: [NSAttributedStringKey.font: UIFont.beeminder.defaultFont]))
            
            attrString.append(NSMutableAttributedString(string: "\(self.goal.slug)\n",
                attributes: [NSAttributedStringKey.font: UIFont.beeminder.defaultBoldFont]))
            
            attrString.append(NSMutableAttributedString(string: "Apple Health metric as autodata!\nWith this metric as the autodata source for your goal, Apple Health will keep Beeminder up to date with your latest data automatically.\n(Technically it updates the Beeminder iOS app which updates Beeminder so you'll have to open the app occasionally.)\nPick a metric from the list below, then hit save to update your goal.",
                                                        attributes: [NSAttributedStringKey.font: UIFont.beeminder.defaultFontLight.withSize(Constants.defaultFontSize)]))
            return attrString
        }()
        
        instructionsLabel.snp.makeConstraints { (make) in
            make.top.equalTo(self.topLayoutGuide.snp.bottom).offset(20)
            make.centerX.equalTo(self.view)
            make.width.equalTo(self.view).multipliedBy(0.85)
        }
        instructionsLabel.numberOfLines = 0
        instructionsLabel.textAlignment = .center
        
        
        let saveButton = BSButton()
        self.view.addSubview(saveButton)
        saveButton.snp.makeConstraints { (make) in
            make.bottom.equalTo(self.bottomLayoutGuide.snp.top).offset(-20)
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
        guard let healthStore = HealthStoreManager.sharedManager.healthStore else { return }
        let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
        hud?.mode = .indeterminate
        let metric = self.sortedHKMetrics[selectedRow]
        if metric.hkIdentifier != nil {
            let metricType = HKObjectType.quantityType(forIdentifier: metric.hkIdentifier!)!
            healthStore.requestAuthorization(toShare: nil, read: [metricType], completion: { (success, error) in
                self.saveMetric(databaseString: metric.databaseString!)
            })
        } else if metric.hkCategoryTypeIdentifier != nil {
            let categoryType = HKObjectType.categoryType(forIdentifier: metric.hkCategoryTypeIdentifier!)
            healthStore.requestAuthorization(toShare: nil, read: [categoryType!], completion: { (success, error) in
                self.saveMetric(databaseString: metric.databaseString!)
            })
        }
        
    }
    
    func saveMetric(databaseString : String) {
        self.goal.healthKitMetric = databaseString
        self.goal.autodata = "apple"
        self.goal.setupHealthKit()
        
        var params : [String : [String : String]] = [:]
        params = ["ii_params" : ["name" : "apple", "metric" : self.goal.healthKitMetric!]]
        
        RequestManager.put(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!)/goals/\(self.goal.slug).json", parameters: params, success: { (responseObject) -> Void in
                let hud = MBProgressHUD.allHUDs(for: self.view).first as? MBProgressHUD
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
