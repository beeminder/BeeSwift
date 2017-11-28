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

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = .white
        self.title = "Choose metric"
        
        let warningLabel = BSLabel()
        self.view.addSubview(warningLabel)
        warningLabel.snp.makeConstraints { (make) in
            make.top.equalTo(self.topLayoutGuide.snp.bottom).offset(20)
            make.centerX.equalTo(self.view)
            make.left.equalTo(20)
            make.right.equalTo(-20)
        }
        warningLabel.text = "Choose wisely! Once you add a metric to a goal, they're paired for life, much like albatross. \n\nYou can email support@beeminder.com if you need to undo anything, though."
        warningLabel.numberOfLines = 0
        
        let saveButton = BSButton()
        self.view.addSubview(saveButton)
        saveButton.snp.makeConstraints { (make) in
            make.bottom.equalTo(self.bottomLayoutGuide.snp.top).offset(-20)
            make.centerX.equalTo(0)
            make.width.equalTo(self.view).multipliedBy(0.5)
            make.height.equalTo(Constants.defaultTextFieldHeight)
        }
        saveButton.setTitle("Save", for: .normal)
        saveButton.addTarget(self, action: #selector(self.saveButtonPressed), for: .touchUpInside)
        
        self.view.addSubview(self.tableView)
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.snp.makeConstraints { (make) in
            make.top.equalTo(warningLabel.snp.bottom).offset(20)
            make.centerX.equalTo(warningLabel)
            make.left.equalTo(0)
            make.right.equalTo(0)
            make.bottom.equalTo(saveButton.snp.top).offset(-20)
        }
        self.tableView.tableFooterView = UIView()
        self.tableView.register(HealthKitMetricTableViewCell.self, forCellReuseIdentifier: self.cellReuseIdentifier)
    }
    
    @objc func saveButtonPressed() {
        guard let selectedRow = self.tableView.indexPathForSelectedRow?.row else { return }
        guard let delegate = UIApplication.shared.delegate as? AppDelegate else { return }
        let metric = HealthKitConfig.shared.metrics[selectedRow]
        if metric.hkIdentifier != nil {
            let metricType = HKObjectType.quantityType(forIdentifier: metric.hkIdentifier!)!
            delegate.healthStore?.requestAuthorization(toShare: nil, read: [metricType], completion: { (success, error) in
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: Constants.savedMetricNotificationName), object: self, userInfo: ["metric" : metric.databaseString!])
            })
        } else if metric.hkCategoryTypeIdentifier != nil {
            let categoryType = HKObjectType.categoryType(forIdentifier: metric.hkCategoryTypeIdentifier!)
            delegate.healthStore?.requestAuthorization(toShare: nil, read: [categoryType!], completion: { (success, error) in
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: Constants.savedMetricNotificationName), object: self, userInfo: ["metric" : metric.databaseString!])
            })
        }
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

extension ChooseHKMetricViewController : UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return HealthKitConfig.shared.metrics.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: self.cellReuseIdentifier) as! HealthKitMetricTableViewCell!
        
        cell!.metric = HealthKitConfig.shared.metrics[indexPath.row].humanText
        if tableView.indexPathForSelectedRow == indexPath {
            cell?.accessoryType = .checkmark
        } else {
            cell?.accessoryType = .none
        }
        return cell!
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        tableView.cellForRow(at: indexPath)?.accessoryType = .none
    }
}
