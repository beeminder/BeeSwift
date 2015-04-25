//
//  GalleryViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/19/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import UIKit
import AFNetworking
import MagicalRecord
import SnapKit

class GalleryViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    let tableView = UITableView()
    let cellReuseIdentifier = "Cell"
    
    var frontburnerGoals : [Goal] = []
    var backburnerGoals  : [Goal] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor.whiteColor()
        self.title = "Goals"
        
        self.loadGoalsFromDatabase()
        
        self.tableView.separatorStyle = UITableViewCellSeparatorStyle.None
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.registerClass(GoalTableViewCell.self, forCellReuseIdentifier: self.cellReuseIdentifier)
        self.view.addSubview(self.tableView)
        
        self.tableView.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(self.view).offset(0)
            make.left.equalTo(self.view).offset(20)
            make.bottom.equalTo(self.view).offset(0)
            make.right.equalTo(self.view).offset(0)
        }
        
        DataSyncManager.sharedManager.fetchData({ () -> Void in
            self.loadGoalsFromDatabase()
            self.tableView.reloadData()
        }, error: { () -> Void in
            //bar
        })
        
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func loadGoalsFromDatabase() {
        self.frontburnerGoals = Goal.MR_findByAttribute("burner", withValue: "frontburner") as! [Goal]
        self.frontburnerGoals = self.frontburnerGoals.sorted { ($0.losedate < $1.losedate) }
        self.backburnerGoals  = Goal.MR_findByAttribute("burner", withValue: "backburner")  as! [Goal]
        self.backburnerGoals = self.backburnerGoals.sorted { ($0.losedate < $1.losedate) }
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? self.frontburnerGoals.count : self.backburnerGoals.count
    }

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        var footerView = UIView()
        footerView.frame.size.height = 40
        footerView.backgroundColor = UIColor.grayColor()
        return footerView
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell:GoalTableViewCell = self.tableView.dequeueReusableCellWithIdentifier(self.cellReuseIdentifier) as! GoalTableViewCell
        
        cell.selectionStyle = UITableViewCellSelectionStyle.None
        
        var goal:Goal = indexPath.section == 0 ? self.frontburnerGoals[indexPath.row] : self.backburnerGoals[indexPath.row]
        
        cell.goal = goal
        
        return cell
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 100
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        var goalViewController = GoalViewController()
        if indexPath.section == 0 {
            goalViewController.goal = self.frontburnerGoals[indexPath.row]
        }
        else {
            goalViewController.goal = self.backburnerGoals[indexPath.row]
        }

        self.navigationController?.pushViewController(goalViewController, animated: true)
    }

}

