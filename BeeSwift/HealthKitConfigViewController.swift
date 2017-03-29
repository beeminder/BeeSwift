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
    
    var tableView = UITableView()
    var goals : [Goal] = []
    let cellReuseIdentifier = "healthKitConfigTableViewCell"

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
        self.title = "Health app integration"
        
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
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func loadGoalsFromDatabase() {
        self.goals = Goal.mr_findAll(with: NSPredicate(format: "serverDeleted = false")) as! [Goal]
    }
    
    func saveMetric(metric : String) {
        let goal = self.goals[(self.tableView.indexPathForSelectedRow?.row)!]
        goal.healthKitMetric = metric //HealthKitConfig.metrics[self.pickerView.selectedRow(inComponent: 0)].databaseString
        
        NSManagedObjectContext.mr_default().mr_saveToPersistentStore { (success, error) in
            var params : [String : [String : String]] = [:]
            if goal.healthKitMetric == nil {
                params = ["ii_params" : ["" : ""]]
            } else {
                params = ["ii_params" : ["name" : "apple", "metric" : goal.healthKitMetric!]]
            }
            
            BSHTTPSessionManager.sharedManager.put("api/v1/users/me/goals/\(goal.slug).json", parameters: params,
               success: { (task, responseObject) -> Void in
                // foo
            }) { (task, error) -> Void in
                // bar
            }
            
            DispatchQueue.main.async {
                self.tableView.deselectRow(at: self.tableView.indexPathForSelectedRow!, animated: true)
                self.tableView.reloadData()
            }
        }
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
        cell!.goal = goal
        
        return cell!
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let goal = self.goals[(indexPath as NSIndexPath).row]
        
        if goal.autodata.characters.count == 0 {
            self.present(ChooseHKMetricViewController(), animated: true, completion: nil)
        }
    }
}
