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
    let lastUpdatedView = UIView()
    let lastUpdatedLabel = BSLabel()
    let cellReuseIdentifier = "Cell"
    
    var frontburnerGoals : [Goal] = []
    var backburnerGoals  : [Goal] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor.whiteColor()
        self.title = "Goals"
        
        self.loadGoalsFromDatabase()
        
        self.view.addSubview(self.lastUpdatedView)
        self.lastUpdatedView.backgroundColor = UIColor(white: 0.8, alpha: 1.0)
        self.lastUpdatedView.snp_makeConstraints { (make) -> Void in
            var topLayoutGuide = self.topLayoutGuide as! UIView
            make.top.equalTo(topLayoutGuide.snp_bottom)
            make.left.equalTo(0)
            make.right.equalTo(0)
        }
        
        self.lastUpdatedView.addSubview(self.lastUpdatedLabel)
        self.lastUpdatedLabel.text = "Last updated:"
        self.lastUpdatedLabel.font = UIFont(name: "Avenir", size: 14)
        self.lastUpdatedLabel.textAlignment = NSTextAlignment.Center
        self.lastUpdatedLabel.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(3)
            make.bottom.equalTo(-3)
            make.left.equalTo(0)
            make.right.equalTo(0)
        }
        
        self.updateLastUpdatedLabel()
        NSTimer.scheduledTimerWithTimeInterval(60, target: self, selector: "updateLastUpdatedLabel", userInfo: nil, repeats: true)
        
        self.tableView.separatorStyle = UITableViewCellSeparatorStyle.None
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.registerClass(GoalTableViewCell.self, forCellReuseIdentifier: self.cellReuseIdentifier)
        self.view.addSubview(self.tableView)
        
        var refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: "fetchData:", forControlEvents: UIControlEvents.ValueChanged)
        self.tableView.addSubview(refreshControl)
        
        self.tableView.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(self.lastUpdatedView.snp_bottom)
            make.left.equalTo(8)
            make.bottom.equalTo(0)
            make.right.equalTo(0)
        }
        
        self.fetchData(refreshControl)
        
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func viewDidAppear(animated: Bool) {
        if CurrentUserManager.sharedManager.accessToken == nil {
            self.presentViewController(SignInViewController(), animated: true, completion: nil)
        }
    }
    
    func updateLastUpdatedLabel() {
        if let lastSynced = DataSyncManager.sharedManager.lastSynced {
            if lastSynced.timeIntervalSinceNow < -3600 {
                var lastText :NSMutableAttributedString = NSMutableAttributedString(string: "Last updated: more than an hour ago")
                lastText.addAttribute(NSForegroundColorAttributeName, value: UIColor.redColor(), range: NSRange(location: 0, length: count(lastText.string)))
                self.lastUpdatedLabel.attributedText = lastText
            }
            else if lastSynced.timeIntervalSinceNow < -120 {
                self.lastUpdatedLabel.text = "Last updated: \(-1*Int(lastSynced.timeIntervalSinceNow/60)) minutes ago"
            }
            else if lastSynced.timeIntervalSinceNow < -60 {
                self.lastUpdatedLabel.text = "Last updated: 1 minute ago"
            }
            else {
                self.lastUpdatedLabel.text = "Last updated: less than a minute ago"
            }
        }
        else {
            var lastText :NSMutableAttributedString = NSMutableAttributedString(string: "Last updated: a long time ago...")
            lastText.addAttribute(NSForegroundColorAttributeName, value: UIColor.redColor(), range: NSRange(location: 0, length: count(lastText.string)))
            self.lastUpdatedLabel.attributedText = lastText
        }
    }
    
    func fetchData(refreshControl: UIRefreshControl) {
        DataSyncManager.sharedManager.fetchData({ () -> Void in
            self.loadGoalsFromDatabase()
            self.tableView.reloadData()
            self.updateLastUpdatedLabel()
            refreshControl.endRefreshing()
            }, error: { () -> Void in
                refreshControl.endRefreshing()
        })
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
        return 130
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

