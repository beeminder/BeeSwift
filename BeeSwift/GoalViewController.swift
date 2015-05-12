//
//  GoalViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/24/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation

class GoalViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var goal :Goal!
    
    private var cellIdentifier = "datapointCell"

    override func viewDidLoad() {
        self.view.backgroundColor = UIColor.whiteColor()
        self.title = self.goal.title
        
        let goalImageView = UIImageView()
        self.view.addSubview(goalImageView)
        goalImageView.setImageWithURL(NSURL(string: goal.graph_url))
        goalImageView.snp_makeConstraints { (make) -> Void in
            make.centerX.equalTo(self.view)
            make.left.greaterThanOrEqualTo(0)
            make.right.lessThanOrEqualTo(0)
            let topLayoutGuide = self.topLayoutGuide as! UIView
            make.top.equalTo(topLayoutGuide.snp_bottom)
        }
        
        let datapointsTableView = UITableView()
        datapointsTableView.dataSource = self
        datapointsTableView.delegate = self
        datapointsTableView.separatorStyle = .None
        datapointsTableView.registerClass(DatapointTableViewCell.self, forCellReuseIdentifier: self.cellIdentifier)
        self.view.addSubview(datapointsTableView)
        datapointsTableView.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(goalImageView.snp_bottom)
            make.left.equalTo(8)
            make.right.equalTo(-8)
            make.bottom.equalTo(0)
        }
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.goal.datapoints.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCellWithIdentifier(self.cellIdentifier) as! DatapointTableViewCell
        cell.datapoint = self.goal.orderedDatapoints()[indexPath.row]
        return cell
    }
}