//
//  TodayViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 10/13/15.
//  Copyright © 2015 APB. All rights reserved.
//

import Foundation
import UIKit
import SnapKit

class TodayViewControler: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    var tableView = UITableView()
    var goalDictionaries : Array<NSDictionary> = []
    
    override func viewDidLoad() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "updateDataSource", name: NSUserDefaultsDidChangeNotification, object: nil)
        
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.tableFooterView = UIView()
        self.tableView.separatorStyle = .None
        self.tableView.registerClass(TodayTableViewCell.self, forCellReuseIdentifier: "todayCell")
        self.view.addSubview(self.tableView)
        self.tableView.snp_makeConstraints { (make) -> Void in
            make.left.equalTo(0)
            make.top.equalTo(0)
            make.width.equalTo(self.view)
            make.bottom.equalTo(0)
        }
        self.updateDataSource()
        self.preferredContentSize = CGSizeMake(0, CGFloat(Double(self.goalDictionaries.count)*(122.0/200.0)*0.4*Double(self.view.frame.size.width)))
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.goalDictionaries.count
    }
    
    func tableView(tableView: UITableView, estimatedHeightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 100
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let slug = self.goalDictionaries[indexPath.row]["slug"] as! String
        
        self.extensionContext?.openURL(NSURL(string: "beeminder://?slug=\(slug)")!, completionHandler: nil)
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("todayCell") as! TodayTableViewCell
        cell.goalDictionary = self.goalDictionaries[indexPath.row]
        return cell
    }
    
    func updateDataSource() {
        let defaults = NSUserDefaults(suiteName: "group.beeminder.beeminder")
        self.goalDictionaries = defaults?.objectForKey("todayGoalDictionaries") as! Array<NSDictionary>
    }
}