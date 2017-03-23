//
//  HealthKitConfigViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 3/14/17.
//  Copyright © 2017 APB. All rights reserved.
//

import UIKit
import HealthKit

class HealthKitConfigViewController: UIViewController {
    
    struct HealthKitConfig {
        let pickerText : String
        let databaseString : String?
        let metric : HKQuantityTypeIdentifier?
    }
    
    var tableView = UITableView()
    var pickerView = UIPickerView()
    var goals : [Goal] = []
    var configOptions : [HealthKitConfig] = []
    let cellReuseIdentifier = "healthKitConfigTableViewCell"

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
        self.title = "Health app integration"
        
        self.configOptions.append(HealthKitConfig(pickerText: "None", databaseString: nil, metric: nil))
        self.configOptions.append(HealthKitConfig(pickerText: "Steps", databaseString: "steps", metric: HKQuantityTypeIdentifier.stepCount))
        
        self.view.addSubview(self.tableView)
        self.tableView.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(0)
            make.right.equalTo(0)
            make.top.equalTo(self.topLayoutGuide.snp.bottom)
            make.bottom.equalTo(self.bottomLayoutGuide.snp.top)
        }
        
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.tableFooterView = UIView()
        self.tableView.backgroundColor = UIColor.clear
        self.tableView.register(HealthKitConfigTableViewCell.self, forCellReuseIdentifier: self.cellReuseIdentifier)
        self.loadGoalsFromDatabase()
        
        self.pickerView.delegate = self
        self.pickerView.dataSource = self
        self.view.addSubview(self.pickerView)
        self.pickerView.snp.makeConstraints { (make) in
            make.bottom.equalTo(self.bottomLayoutGuide.snp.bottom)
            make.left.equalTo(0)
            make.right.equalTo(0)
        }
        self.pickerView.layer.opacity = 0
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func loadGoalsFromDatabase() {
        self.goals = Goal.mr_findAll(with: NSPredicate(format: "serverDeleted = false")) as! [Goal]
    }
    
    func showPicker() {
        UIView.animate(withDuration: 0.25) {
            self.pickerView.layer.opacity = 1.0
        }
    }
    
    func hidePicker() {
        UIView.animate(withDuration: 0.25) {
            self.pickerView.layer.opacity = 0.0
        }
    }
    
    func savePickerChoice() {
        let goal = self.goals[(self.tableView.indexPathForSelectedRow?.row)!]
        goal.healthKitMetric = self.configOptions[self.pickerView.selectedRow(inComponent: 0)].databaseString
        
        NSManagedObjectContext.mr_default().mr_saveToPersistentStore(completion: nil)
        
        DispatchQueue.main.async {
            self.tableView.deselectRow(at: self.tableView.indexPathForSelectedRow!, animated: true)
            self.hidePicker()
            self.tableView.reloadData()
        }
    }
}

extension HealthKitConfigViewController : UIPickerViewDelegate, UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let delegate = UIApplication.shared.delegate as? AppDelegate
        if let metric = self.configOptions[row].metric {
            let metricType = HKObjectType.quantityType(forIdentifier: metric)!
            delegate?.healthStore?.requestAuthorization(toShare: nil, read: [metricType], completion: { (success, error) in
                self.savePickerChoice()
            })
        } else {
            self.savePickerChoice()
        }
    }
//            if delegate!.healthStore!.authorizationStatus(for: stepCountType) == HKAuthorizationStatus. {
//                self.savePickerChoice()
//            } else {
//                let alert = UIAlertController(title: "Not authorized", message: "Beeminder is not authorized to read this data from the Health app. You can change this setting in the Health app.", preferredStyle: .alert)
//                
//                var laterButton = UIAlertAction(title: "Okay", style: .default, handler: { (action) in
//                    // dismiss
//                })
//                
//                if #available(iOS 10.0, *) {
//                    laterButton = UIAlertAction(title: "Later", style: .cancel, handler: { (action) in
//                        // dismiss
//                    })
//                    let healthAppButton = UIAlertAction(title: "Open Health app", style: .default, handler: { (alert) in
//                        UIApplication.shared.open(URL(string: "x-apple-health://")!)
//                    })
//                    alert.addAction(laterButton)
//                    alert.addAction(healthAppButton)
//                } else {
//                    alert.addAction(laterButton)
//                }
//                self.present(alert, animated: true, completion: nil)
//            }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return self.configOptions.count
    }
    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let view = UIView()
        let label = BSLabel()
        view.addSubview(label)
        label.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(0)
            make.bottom.equalTo(0)
            make.left.equalTo(10)
            make.right.equalTo(-20)
        }
        label.font = UIFont(name: "Avenir", size: 17)
        
        if row == 0 {
            label.text = "None"
        } else {
            label.text = self.configOptions[row].pickerText
        }
        label.textAlignment = .center
        
        return view
    }
}

extension HealthKitConfigViewController : UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.goals.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: self.cellReuseIdentifier) as! HealthKitConfigTableViewCell!

        let goal = self.goals[(indexPath as NSIndexPath).row]
        cell!.goalname = goal.slug
        let config = self.configOptions.first(where: { $0.databaseString == goal.healthKitMetric })
        cell!.goalMetric = config?.pickerText
        return cell!
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let goal = self.goals[(indexPath as NSIndexPath).row]
        
        self.showPicker()
        guard let row = self.configOptions.index(where: { $0.databaseString == goal.healthKitMetric }) else { return }
        self.pickerView.selectRow(row, inComponent: 0, animated: false)
    }
}
